from fastapi import APIRouter, Depends, HTTPException, requests # 引入 Depends
from pydantic import BaseModel
import time
import traceback

from app.engine.schemas import SimulationInput, SimulationOutput
from app.engine.finance import FinancialInput, FinancialOutput, run_financial_simulation
from app.engine.physics import run_physics_simulation
from app.api.deps import get_current_user_payload, TokenPayload # 引入安检门


# 确保你的 app/services/pvgis.py 文件存在并被引入！
from app.services.pvgis import fetch_pvgis_hourly_irradiance

router = APIRouter()

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

class FullQuoteResponse(BaseModel):
    physics_result: SimulationOutput
    finance_result: FinancialOutput

@router.post("/simulate", response_model=FullQuoteResponse)
async def simulate_pv_ess_project(
    request: FullQuoteRequest, 
    current_user: TokenPayload = Depends(get_current_user_payload) # 👈 保安就位！
):
    try:

        print(f"🔒 安全拦截通过：操作人角色 {current_user.role}, 所属公司ID {current_user.company_id}")
        
        env = request.physics_params.env
        
        # 🌟 监控雷达 1：确认是否收到了坐标
        print(f"\n👉 收到前端请求 | 目标城市: 纬度 {env.lat}, 经度 {env.lon}")

        # 🟢 核心拦截：如果有真实坐标，狸猫换太子
        if env.lat != 0.0 and env.lon != 0.0:
            print("📡 正在跨国连接欧盟 PVGIS 气象卫星...")
            start_t = time.time()
            # 呼叫欧盟服务器拉取真实数据
            real_irradiance = await fetch_pvgis_hourly_irradiance(lat=env.lat, lon=env.lon)
            # 覆盖前端传来的假数据
            request.physics_params.env.irradiance_8760 = real_irradiance
            print(f"✅ 成功获取 8760 小时真实光照！耗时: {time.time() - start_t:.2f}s")
        else:
            print("⚠️ 未收到有效坐标，继续使用本地完美假太阳进行测算。")

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

        # print(f"金融数据:{fin_out}")
        # print(f"物理数据:{phys_out}")
        
        return FullQuoteResponse(physics_result=phys_out, finance_result=fin_out)
    # 🌟 进阶捕获 1：专门捕获第三方 API 的 HTTP 错误 (如果你用的是 requests)
    except requests.exceptions.HTTPError as e:
        # 这样可以直接提取气象局服务器返回的真实错误 JSON
        error_detail = f"气象 API 拒绝请求, 状态码: {e.response.status_code}, 详情: {e.response.text}"
        print(f"🔴 [外部 API 错误] {error_detail}") # 打印到后端控制台
        raise HTTPException(status_code=502, detail=error_detail) # 502 Bad Gateway 更符合语意    
    except Exception as e:
        # 获取包含具体报错代码行数的完整追踪信息
        error_trace = traceback.format_exc()
        
        # ⚠️ 核心原则：详细堆栈留在后端自己看，精简信息返回给前端
        print(f"🔥 [致命异常崩溃] 完整堆栈如下:\n{error_trace}")
        
        # repr(e) 会比 str(e) 打印出异常的类型，比如 KeyError('temp') 而不只是 'temp'
        raise HTTPException(status_code=500, detail=f"内部系统崩溃: {repr(e)}")