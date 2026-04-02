from pydantic import BaseModel, Field
from typing import List

class EnvironmentAndLoad(BaseModel):
    # 🟢 新增经纬度字段 (带默认值，兼容旧测试请求)
    lat: float = Field(0.0, description="纬度")
    lon: float = Field(0.0, description="经度")
    
    irradiance_8760: List[float]
    load_profile_8760: List[float]
    grid_status_8760: List[int]

class PVSystemConfig(BaseModel):
    pv_dc_capacity_kwp: float
    inverter_ac_capacity_kw: float
    system_loss_factor: float

class ESSSystemConfig(BaseModel):
    batt_nominal_capacity_kwh: float
    dod_limit: float
    max_charge_discharge_kw: float
    rte_efficiency: float
    initial_soc: float

class GridPolicyConfig(BaseModel):
    export_limit_kw: float

# 🟢 新增：阶梯电价与需量电费模型
class TariffConfig(BaseModel):
    peak_price: float = Field(0.35, description="高峰电价 ($/kWh)")
    mid_price: float = Field(0.15, description="平段电价 ($/kWh)")
    valley_price: float = Field(0.05, description="谷段电价 ($/kWh) - 夜间套利成本")
    
    peak_hours: List[int] = Field([18, 19, 20, 21], description="高峰时段定义 (0-23)")
    valley_hours: List[int] = Field([1, 2, 3, 4, 5], description="低谷时段定义 (0-23)")
    
    demand_charge_per_kw: float = Field(15.0, description="每月最大需量电费 ($/kW)")
    enable_grid_charging: bool = Field(True, description="是否允许夜间从电网充电")

class SimulationInput(BaseModel):
    env: EnvironmentAndLoad
    pv: PVSystemConfig
    ess: ESSSystemConfig
    grid: GridPolicyConfig
    tariff: TariffConfig = TariffConfig() # 🟢 注入电价模型 (带有默认值)

class KPIResults(BaseModel):
    total_generation_kwh: float
    self_consumption_rate: float
    autarky_rate: float
    annual_cycles: float

class HourlyResults(BaseModel):
    pv_generation: List[float]
    pv_to_load: List[float]
    pv_to_batt: List[float]
    batt_to_load: List[float]
    grid_to_load: List[float]
    grid_to_batt: List[float] # 🟢 新增：记录半夜强行从电网充进电池的电
    pv_to_grid: List[float]
    curtailment: List[float]
    lost_load: List[float]
    batt_soc: List[float]

class SimulationOutput(BaseModel):
    kpis: KPIResults
    hourly_data: HourlyResults