from fastapi import APIRouter, Depends, HTTPException, requests # 引入 Depends
from pydantic import BaseModel
from typing import List, Dict
import logging
import time
import traceback
from pprint import pformat

from app.engine.schemas import SimulationInput, SimulationOutput
from app.engine.finance import FinancialInput, run_financial_simulation
from app.engine.physics import run_physics_simulation
from app.api.deps import get_current_user_payload, TokenPayload # 引入安检门


# 确保你的 app/services/pvgis.py 文件存在并被引入！
from app.services.pvgis import fetch_pvgis_hourly_irradiance

router = APIRouter()
logger = logging.getLogger("app.simulation")

class FinancialBaseConfig(BaseModel):
    total_capex: float 
    annual_opex: float 
    battery_replacement_cost: float 
    battery_replacement_year: int 
    current_electricity_price: float 
    electricity_inflation_rate: float 
    voll_price: float 
    system_degradation_rate: float 
    down_payment_pct: float 
    loan_term_years: int 
    loan_interest_rate: float 
    discount_rate: float 
    project_lifespan: int 

class FullQuoteRequest(BaseModel):
    physics_params: SimulationInput
    financial_params: FinancialBaseConfig

class ProjectFinanceOutput(BaseModel):
    project_npv: float
    project_irr: float
    project_payback_years: float
    cash_flow_statement: List[Dict[str, float]]

class FullQuoteResponse(BaseModel):
    physics_result: SimulationOutput
    finance_result: ProjectFinanceOutput

@router.post("/simulate", response_model=FullQuoteResponse)
async def simulate_pv_ess_project(
    request: FullQuoteRequest, 
    current_user: TokenPayload = Depends(get_current_user_payload) # 👈 保安就位！
):
    try:
        logger.info(
            "[SIM] auth_pass role=%s company_id=%s user_id=%s",
            current_user.role,
            current_user.company_id,
            current_user.user_id,
        )
        logger.info(
            "[SIM] full_request payload=\n%s",
            pformat(request.model_dump(), width=120, sort_dicts=True),
        )
        
        env = request.physics_params.env
        
        # 🌟 监控雷达 1：确认是否收到了坐标
        logger.info("[SIM] request_location lat=%s lon=%s", env.lat, env.lon)

        # 🟢 核心拦截：如果有真实坐标，狸猫换太子
        if env.lat != 0.0 and env.lon != 0.0:
            logger.info("[SIM] fetching_pvgis_irradiance start")
            start_t = time.time()
            # 呼叫欧盟服务器拉取真实数据
            real_irradiance = await fetch_pvgis_hourly_irradiance(lat=env.lat, lon=env.lon)
            # 覆盖前端传来的假数据
            request.physics_params.env.irradiance_8760 = real_irradiance
            logger.info(
                "[SIM] fetching_pvgis_irradiance done hours=%s duration_s=%.2f",
                len(real_irradiance),
                time.time() - start_t,
            )
        else:
            logger.info("[SIM] missing_coordinates fallback_to_request_irradiance=true")

        # 1. 运行物理引擎
        phys_out = run_physics_simulation(request.physics_params)
        
        tariff = request.physics_params.tariff
        hourly = phys_out.hourly_data
        
        # 2. 算账：峰谷套利与削峰填谷
        cost_without_sys = 0.0
        cost_with_sys = 0.0
        max_kw_without = [0.0] * 12
        max_kw_with = [0.0] * 12
        
        for t in range(8760):
            hour = t % 24
            month = (t // 730) % 12 
            
            if hour in tariff.peak_hours: rate = tariff.peak_price
            elif hour in tariff.valley_hours: rate = tariff.valley_price
            else: rate = tariff.mid_price
            
            cost_without_sys += env.load_profile_8760[t] * rate
            if env.load_profile_8760[t] > max_kw_without[month]:
                max_kw_without[month] = env.load_profile_8760[t]
                
            total_grid_import = hourly.grid_to_load[t] + hourly.grid_to_batt[t]
            cost_with_sys += total_grid_import * rate
            if total_grid_import > max_kw_with[month]:
                max_kw_with[month] = total_grid_import
                
        tou_savings = cost_without_sys - cost_with_sys
        demand_savings = (sum(max_kw_without) - sum(max_kw_with)) * tariff.demand_charge_per_kw

        # 3. 停电损失挽回
        total_potential_loss = sum(env.load_profile_8760[t] for t in range(8760) if env.grid_status_8760[t] == 0)
        actual_loss = sum(hourly.lost_load)
        avoided_loss_kwh = total_potential_loss - actual_loss
        backup_revenue = avoided_loss_kwh * request.financial_params.voll_price

        # 4. 运行金融引擎
        fin_input = FinancialInput(
            first_year_tou_savings=tou_savings,
            first_year_demand_savings=demand_savings,
            first_year_backup_revenue=backup_revenue,
            **request.financial_params.model_dump() 
        )
        fin_out = run_financial_simulation(fin_input)

        logger.info(
            "[SIM] intermediate_metrics tou_savings=%.4f demand_savings=%.4f "
            "avoided_loss_kwh=%.4f backup_revenue=%.4f annual_load_kwh=%.4f",
            tou_savings,
            demand_savings,
            avoided_loss_kwh,
            backup_revenue,
            sum(env.load_profile_8760),
        )
        logger.info(
            "[SIM] financial_input payload=\n%s",
            pformat(fin_input.model_dump(), width=120, sort_dicts=True),
        )
        logger.info(
            "[SIM] financial_output payload=\n%s",
            pformat(fin_out.model_dump(), width=120, sort_dicts=True),
        )
        if fin_out.project_irr >= 40 or fin_out.project_payback_years <= 3:
            logger.warning(
                "[SIM] suspicious_result project_irr=%.2f project_npv=%.2f project_payback=%.2f "
                "(check tariff/voll/load profile/capex units)",
                fin_out.project_irr,
                fin_out.project_npv,
                fin_out.project_payback_years,
            )
        
        finance_payload = fin_out.model_dump(
            exclude={
                "equity_npv",
                "equity_irr",
                "equity_payback_years",
                "project_cash_flow_statement",
                "equity_cash_flow_statement",
            }
        )
        return FullQuoteResponse(
            physics_result=phys_out,
            finance_result=ProjectFinanceOutput(**finance_payload),
        )
    # 🌟 进阶捕获 1：专门捕获第三方 API 的 HTTP 错误 (如果你用的是 requests)
    except requests.exceptions.HTTPError as e:
        # 这样可以直接提取气象局服务器返回的真实错误 JSON
        error_detail = f"气象 API 拒绝请求, 状态码: {e.response.status_code}, 详情: {e.response.text}"
        logger.exception("[SIM] external_api_error %s", error_detail)
        raise HTTPException(status_code=502, detail=error_detail) # 502 Bad Gateway 更符合语意    
    except Exception as e:
        # 获取包含具体报错代码行数的完整追踪信息
        error_trace = traceback.format_exc()
        
        # ⚠️ 核心原则：详细堆栈留在后端自己看，精简信息返回给前端
        logger.error("[SIM] fatal_exception trace=\n%s", error_trace)
        
        # repr(e) 会比 str(e) 打印出异常的类型，比如 KeyError('temp') 而不只是 'temp'
        raise HTTPException(status_code=500, detail=f"内部系统崩溃: {repr(e)}")