import math
from typing import List, Dict, Optional
from pydantic import BaseModel, Field

class FinancialInput(BaseModel):
    # 🟢 接收 API 层结算好的具体美元节省金额
    first_year_tou_savings: float       
    first_year_demand_savings: float    
    first_year_backup_revenue: float    
    
    total_capex: float 
    annual_opex: float 
    battery_replacement_cost: float 
    battery_replacement_year: int 
    
    current_electricity_price: float # 兼容老接口保留
    electricity_inflation_rate: float 
    voll_price: float 
    system_degradation_rate: float 
    
    down_payment_pct: float 
    loan_term_years: int 
    loan_interest_rate: float 
    discount_rate: float 
    project_lifespan: int 

class FinancialOutput(BaseModel):
    # New dual-metric output
    project_npv: float
    project_irr: float
    project_payback_years: float
    equity_npv: float
    equity_irr: float
    equity_payback_years: float
    # Backward-compatible aliases (mapped to project metrics)
    npv: float
    irr: float
    payback_period_years: float
    lcoe: float
    cash_flow_statement: List[Dict[str, float]]
    project_cash_flow_statement: List[Dict[str, float]]
    equity_cash_flow_statement: List[Dict[str, float]]

def calculate_pmt(principal: float, annual_rate: float, years: int) -> float:
    if annual_rate == 0:
        return principal / years if years > 0 else 0
    return principal * (annual_rate * (1 + annual_rate)**years) / ((1 + annual_rate)**years - 1)

def calculate_irr(cash_flows: List[float], max_iterations=1000, tolerance=1e-6) -> float:
    if all(cf >= 0 for cf in cash_flows) or all(cf <= 0 for cf in cash_flows):
        return 0.0
    def npv_func(rate):
        return sum(cf / ((1 + rate) ** i) for i, cf in enumerate(cash_flows))

    r0, r1 = 0.0, 0.1
    for _ in range(max_iterations):
        npv0 = npv_func(r0)
        npv1 = npv_func(r1)
        if abs(npv1) < tolerance: return r1
        if npv1 == npv0: break
        r_new = r1 - npv1 * (r1 - r0) / (npv1 - npv0)
        r0, r1 = r1, r_new
    return r1

def calculate_payback(cash_flows: List[float], default_years: float = 20.0) -> float:
    cumulative = cash_flows[0] if cash_flows else 0.0
    if cumulative >= 0:
        return 0.0
    for year in range(1, len(cash_flows)):
        prev_cumulative = cumulative
        cumulative += cash_flows[year]
        if cumulative >= 0:
            current_cf = cash_flows[year]
            if current_cf == 0:
                return float(year)
            return (year - 1) + abs(prev_cumulative) / current_cf
    return default_years

def run_financial_simulation(params: FinancialInput) -> FinancialOutput:
    n_years = params.project_lifespan
    
    down_payment = params.total_capex * params.down_payment_pct
    loan_principal = params.total_capex - down_payment
    annual_loan_payment = calculate_pmt(loan_principal, params.loan_interest_rate, params.loan_term_years)

    equity_cash_flow_rows = []
    equity_cumulative = -down_payment
    equity_cash_flow_rows.append({
        "year": 0,
        "energy_savings_revenue": 0.0,
        "backup_power_value": 0.0,
        "opex_and_replacement": 0.0,
        "debt_service": 0.0,
        "net_cash_flow": -down_payment,
        "cumulative_cash_flow": equity_cumulative
    })
    equity_cash_flow_array = [-down_payment]

    project_cash_flow_rows = []
    project_cumulative = -params.total_capex
    project_cash_flow_rows.append({
        "year": 0,
        "energy_savings_revenue": 0.0,
        "backup_power_value": 0.0,
        "opex_and_replacement": 0.0,
        "debt_service": 0.0,
        "net_cash_flow": -params.total_capex,
        "cumulative_cash_flow": project_cumulative
    })
    project_cash_flow_array = [-params.total_capex]

    for year in range(1, n_years + 1):
        degradation_factor = (1 - params.system_degradation_rate) ** (year - 1)
        inflation_factor = (1 + params.electricity_inflation_rate) ** (year - 1)
        
        # 🟢 计算衰减与通胀后的综合能源节省 (TOU + 削峰)
        yearly_tou = params.first_year_tou_savings * degradation_factor
        yearly_demand = params.first_year_demand_savings * degradation_factor
        
        # 前端 UI 图表仍然读取 energy_savings_revenue 字段，我们把两块收益合并给它
        energy_revenue = (yearly_tou + yearly_demand) * inflation_factor
        backup_value = params.first_year_backup_revenue * degradation_factor
        total_revenue = energy_revenue + backup_value
        
        opex = params.annual_opex * inflation_factor 
        if year == params.battery_replacement_year:
            opex += params.battery_replacement_cost
            
        debt_service = annual_loan_payment if year <= params.loan_term_years else 0.0
        
        equity_net_cf = total_revenue - opex - debt_service
        project_net_cf = total_revenue - opex
        equity_cumulative += equity_net_cf
        project_cumulative += project_net_cf

        equity_cash_flow_array.append(equity_net_cf)
        project_cash_flow_array.append(project_net_cf)
        equity_cash_flow_rows.append({
            "year": year,
            "energy_savings_revenue": round(energy_revenue, 2),
            "backup_power_value": round(backup_value, 2),
            "opex_and_replacement": round(opex, 2),
            "debt_service": round(debt_service, 2),
            "net_cash_flow": round(equity_net_cf, 2),
            "cumulative_cash_flow": round(equity_cumulative, 2)
        })
        project_cash_flow_rows.append({
            "year": year,
            "energy_savings_revenue": round(energy_revenue, 2),
            "backup_power_value": round(backup_value, 2),
            "opex_and_replacement": round(opex, 2),
            "debt_service": 0.0,
            "net_cash_flow": round(project_net_cf, 2),
            "cumulative_cash_flow": round(project_cumulative, 2)
        })

    project_npv = sum(cf / ((1 + params.discount_rate) ** i) for i, cf in enumerate(project_cash_flow_array))
    project_irr = calculate_irr(project_cash_flow_array)
    project_payback = calculate_payback(project_cash_flow_array, default_years=float(n_years))

    equity_npv = sum(cf / ((1 + params.discount_rate) ** i) for i, cf in enumerate(equity_cash_flow_array))
    equity_irr = calculate_irr(equity_cash_flow_array)
    equity_payback = calculate_payback(equity_cash_flow_array, default_years=float(n_years))

    return FinancialOutput(
        project_npv=round(project_npv, 2),
        project_irr=round(project_irr * 100, 2),
        project_payback_years=round(project_payback, 2),
        equity_npv=round(equity_npv, 2),
        equity_irr=round(equity_irr * 100, 2),
        equity_payback_years=round(equity_payback, 2),
        npv=round(project_npv, 2),
        irr=round(project_irr * 100, 2),
        payback_period_years=round(project_payback, 2),
        lcoe=0.0, # TOU 场景下 LCOE 意义不大，设为 0
        cash_flow_statement=equity_cash_flow_rows,
        project_cash_flow_statement=project_cash_flow_rows,
        equity_cash_flow_statement=equity_cash_flow_rows,
    )