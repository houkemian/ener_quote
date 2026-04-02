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
    npv: float
    irr: float
    payback_period_years: float
    lcoe: float
    cash_flow_statement: List[Dict[str, float]]

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

def run_financial_simulation(params: FinancialInput) -> FinancialOutput:
    n_years = params.project_lifespan
    
    down_payment = params.total_capex * params.down_payment_pct
    loan_principal = params.total_capex - down_payment
    annual_loan_payment = calculate_pmt(loan_principal, params.loan_interest_rate, params.loan_term_years)

    cash_flows = []
    cumulative_cash_flow = -down_payment
    payback_period = -1.0
    
    cash_flows.append({
        "year": 0,
        "energy_savings_revenue": 0.0,
        "backup_power_value": 0.0,
        "opex_and_replacement": 0.0,
        "debt_service": 0.0,
        "net_cash_flow": -down_payment,
        "cumulative_cash_flow": cumulative_cash_flow
    })
    pure_cash_flow_array = [-down_payment]

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
        
        net_cf = total_revenue - opex - debt_service
        cumulative_cash_flow += net_cf
        
        if payback_period < 0 and cumulative_cash_flow >= 0:
            previous_cum = cash_flows[-1]["cumulative_cash_flow"]
            payback_period = (year - 1) + abs(previous_cum) / net_cf

        pure_cash_flow_array.append(net_cf)
        cash_flows.append({
            "year": year,
            "energy_savings_revenue": round(energy_revenue, 2),
            "backup_power_value": round(backup_value, 2),
            "opex_and_replacement": round(opex, 2),
            "debt_service": round(debt_service, 2),
            "net_cash_flow": round(net_cf, 2),
            "cumulative_cash_flow": round(cumulative_cash_flow, 2)
        })

    npv = sum(cf / ((1 + params.discount_rate) ** i) for i, cf in enumerate(pure_cash_flow_array))
    irr = calculate_irr(pure_cash_flow_array)

    return FinancialOutput(
        npv=round(npv, 2),
        irr=round(irr * 100, 2), 
        payback_period_years=round(payback_period, 2) if payback_period > 0 else 20.0, 
        lcoe=0.0, # TOU 场景下 LCOE 意义不大，设为 0
        cash_flow_statement=cash_flows
    )