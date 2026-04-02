import pytest
from app.engine.schemas import SimulationInput, EnvironmentAndLoad, PVSystemConfig, ESSSystemConfig, GridPolicyConfig
from app.engine.physics import run_physics_simulation

def test_energy_conservation_under_extreme_blackout():
    """
    测试极端停电场景下的全局能量守恒
    """
    # 1. 构造一整年 (8760小时) 的全零基座数据
    irradiance = [0.0] * 8760
    load = [0.0] * 8760
    grid_status = [1] * 8760  # 1代表电网正常，0代表停电
    
    # 💥 刁钻场景 A：中午 12 点，烈日当空 (1000W/m²)，负载很低 (2度电)，但电网突然停电 (0)
    irradiance[12] = 1000.0
    load[12] = 2.0
    grid_status[12] = 0
    
    # 💥 刁钻场景 B：晚上 20 点，太阳下山 (0W/m²)，用电高峰 (5度电)，电网依然停电 (0)
    irradiance[20] = 0.0
    load[20] = 5.0
    grid_status[20] = 0

    # 2. 组装输入参数 (模拟一套常规的 10kW 光储系统)
    mock_input = SimulationInput(
        env=EnvironmentAndLoad(
            irradiance_8760=irradiance,
            load_profile_8760=load,
            grid_status_8760=grid_status
        ),
        pv=PVSystemConfig(
            pv_dc_capacity_kwp=10.0, 
            inverter_ac_capacity_kw=8.0, 
            system_loss_factor=0.1
        ),
        ess=ESSSystemConfig(
            batt_nominal_capacity_kwh=10.0, 
            dod_limit=0.1, 
            max_charge_discharge_kw=5.0, 
            rte_efficiency=0.9, 
            initial_soc=0.5  # 假设期初电池有一半的电
        ),
        grid=GridPolicyConfig(
            export_limit_kw=0.0  # 设置为 0，代表不允许向电网卖电 (防逆流)
        )
    )

    # 3. 运行物理引擎，拿到 8760 小时的账本
    result = run_physics_simulation(mock_input)
    hourly = result.hourly_data

    # 4. 终极断言 (Assertions)：逐小时查账
    for t in range(8760):
        # 供给侧：光伏实际发电 + 电池实际放电 + 向电网买电
        actual_supply = hourly.pv_generation[t] + hourly.batt_to_load[t] + hourly.grid_to_load[t]
        
        # 消耗侧：实际满足的用电 + 充入电池的电 + 卖给电网的电 + 被迫丢弃的电
        # 注意：实际满足的用电 = 客户理论用电需求 - 停电导致的损失
        actual_consumption = (load[t] - hourly.lost_load[t]) + hourly.pv_to_batt[t] + hourly.pv_to_grid[t] + hourly.curtailment[t]
        
        # 检查左右两边是否完全相等 (保留4位小数以消除计算机浮点数误差)
        assert round(actual_supply, 4) == round(actual_consumption, 4), \
            f"系统出现财务漏洞！第 {t} 小时：总供给 {actual_supply} ≠ 总消耗 {actual_consumption}"

    # 如果运行到这里没有报错，说明测试完美通过！
    print("✅ 物理引擎测试通过：8760 小时能量绝对守恒！")