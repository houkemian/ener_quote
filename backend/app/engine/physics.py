import math
from app.engine.schemas import SimulationInput, SimulationOutput, HourlyResults, KPIResults

def run_physics_simulation(params: SimulationInput) -> SimulationOutput:
    env = params.env
    pv = params.pv
    ess = params.ess
    grid = params.grid
    tariff = params.tariff # 🟢 获取电价策略
    
    eff_charge = math.sqrt(ess.rte_efficiency)
    eff_discharge = math.sqrt(ess.rte_efficiency)

    out_pv_gen = [0.0] * 8760
    out_pv_to_load = [0.0] * 8760
    out_pv_to_batt = [0.0] * 8760
    out_batt_to_load = [0.0] * 8760
    out_grid_to_load = [0.0] * 8760
    out_grid_to_batt = [0.0] * 8760 # 🟢 新增输出流向
    out_pv_to_grid = [0.0] * 8760
    out_curtailment = [0.0] * 8760
    out_lost_load = [0.0] * 8760
    out_batt_soc = [0.0] * 8760

    current_soc = ess.initial_soc
    total_batt_discharge_kwh = 0.0 

    for t in range(8760):
        # 获取当前时间所属的电价区间
        hour_of_day = t % 24
        is_valley = hour_of_day in tariff.valley_hours

        pv_raw = pv.pv_dc_capacity_kwp * (env.irradiance_8760[t] / 1000.0) * (1 - pv.system_loss_factor)
        pv_actual = min(pv_raw, pv.inverter_ac_capacity_kw)
        out_pv_gen[t] = pv_actual

        current_load = env.load_profile_8760[t]
        is_grid_up = (env.grid_status_8760[t] == 1)

        # B. 优先级 1：光伏直接满足负载
        pv_to_load = min(pv_actual, current_load)
        out_pv_to_load[t] = pv_to_load
        
        net_load = current_load - pv_to_load 
        surplus_pv = pv_actual - pv_to_load 
        max_energy_per_hour = ess.max_charge_discharge_kw * 1.0 

        batt_charge, batt_discharge = 0.0, 0.0
        grid_import_load, grid_import_batt, grid_export = 0.0, 0.0, 0.0
        curtail, lost = 0.0, 0.0

        # C. 优先级 2：光伏富余充电
        if surplus_pv > 0:
            space_kwh = (1.0 - current_soc) * ess.batt_nominal_capacity_kwh / eff_charge
            batt_charge = min(surplus_pv, max_energy_per_hour, space_kwh)
            current_soc += (batt_charge * eff_charge) / ess.batt_nominal_capacity_kwh
            remaining_surplus = surplus_pv - batt_charge
            if is_grid_up:
                grid_export = min(remaining_surplus, grid.export_limit_kw)
                curtail = remaining_surplus - grid_export
            else:
                curtail = remaining_surplus
                
        # D. 优先级 3：光伏不足，电池放电
        elif net_load > 0:
            available_kwh = (current_soc - ess.dod_limit) * ess.batt_nominal_capacity_kwh * eff_discharge
            available_kwh = max(0.0, available_kwh)
            batt_discharge = min(net_load, max_energy_per_hour, available_kwh)
            current_soc -= (batt_discharge / eff_discharge) / ess.batt_nominal_capacity_kwh
            total_batt_discharge_kwh += batt_discharge
            
            shortfall = net_load - batt_discharge
            if is_grid_up:
                grid_import_load = shortfall
            else:
                lost = shortfall 

        # E. 🟢 优先级 4 (新 EMS 策略)：夜间谷电强制充电套利
        # 条件：当前是谷电时段 + 政策允许充电 + 电网正常 + 电池没满
        if is_valley and tariff.enable_grid_charging and is_grid_up and current_soc < 1.0:
            space_kwh = (1.0 - current_soc) * ess.batt_nominal_capacity_kwh / eff_charge
            # 减去这个小时已经用光伏充进去的功率，算出逆变器还能从电网拉多少功率
            available_grid_charge_power = max_energy_per_hour - batt_charge 
            
            if space_kwh > 0 and available_grid_charge_power > 0:
                grid_import_batt = min(space_kwh, available_grid_charge_power)
                current_soc += (grid_import_batt * eff_charge) / ess.batt_nominal_capacity_kwh

        # 写入寄存器
        out_pv_to_batt[t] = batt_charge
        out_batt_to_load[t] = batt_discharge
        out_grid_to_load[t] = grid_import_load
        out_grid_to_batt[t] = grid_import_batt # 🟢 记录套利买电
        out_pv_to_grid[t] = grid_export
        out_curtailment[t] = curtail
        out_lost_load[t] = lost
        out_batt_soc[t] = current_soc * 100.0

    total_gen = sum(out_pv_gen)
    total_load = sum(env.load_profile_8760)
    
    pv_used_by_sys = sum(out_pv_to_load) + sum(out_pv_to_batt)
    self_consumption = (pv_used_by_sys / total_gen) if total_gen > 0 else 0.0
    
    sys_to_load = sum(out_pv_to_load) + sum(out_batt_to_load)
    autarky = (sys_to_load / total_load) if total_load > 0 else 0.0

    cycles = total_batt_discharge_kwh / ess.batt_nominal_capacity_kwh if ess.batt_nominal_capacity_kwh > 0 else 0.0

    return SimulationOutput(
        kpis=KPIResults(
            total_generation_kwh=total_gen,
            self_consumption_rate=self_consumption,
            autarky_rate=autarky,
            annual_cycles=cycles
        ),
        hourly_data=HourlyResults(
            pv_generation=out_pv_gen,
            pv_to_load=out_pv_to_load,
            pv_to_batt=out_pv_to_batt,
            batt_to_load=out_batt_to_load,
            grid_to_load=out_grid_to_load,
            grid_to_batt=out_grid_to_batt,
            pv_to_grid=out_pv_to_grid,
            curtailment=out_curtailment,
            lost_load=out_lost_load,
            batt_soc=out_batt_soc
        )
    )