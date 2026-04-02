import requests
import json

# ==========================================
# 1. 构造逼真的 8760 小时物理时序数据
# ==========================================
irradiance = []
load_profile = []
grid_status = []

for hour in range(8760):
    # 模拟日夜交替：每天早上 8 点到下午 16 点有太阳 (假设平局光照 600 W/m²)
    hour_of_day = hour % 24
    if 8 <= hour_of_day <= 16:
        irradiance.append(600.0)
    else:
        irradiance.append(0.0)
        
    # 模拟工厂用电负载：每小时稳定用电 3 度 (3 kWh)
    load_profile.append(3.0)
    
    # 模拟拉美电网：大概有 2% 的概率发生随机停电
    # 为了测试效果，我们强制设定每个月的第一天晚上停电 4 小时
    if hour % (24 * 30) in [18, 19, 20, 21]: 
        grid_status.append(0) # 0 代表停电
    else:
        grid_status.append(1) # 1 代表正常

# ==========================================
# 2. 组装发给 API 的完整 JSON 结构包
# ==========================================
payload = {
    "physics_params": {
        "env": {
            "irradiance_8760": irradiance,
            "load_profile_8760": load_profile,
            "grid_status_8760": grid_status
        },
        "pv": {
            "pv_dc_capacity_kwp": 10.0,      # 10kW 光伏板
            "inverter_ac_capacity_kw": 8.0,  # 8kW 逆变器
            "system_loss_factor": 0.15       # 15% 综合损耗
        },
        "ess": {
            "batt_nominal_capacity_kwh": 15.0, # 15度大电池 (为了应对停电)
            "dod_limit": 0.1,                  # 保护底层 10% 电量不放
            "max_charge_discharge_kw": 7.5,    # 最大充放电功率 7.5kW
            "rte_efficiency": 0.90,            # 90% 充放电往返效率
            "initial_soc": 1.0                 # 假设第一天是满电开始
        },
        "grid": {
            "export_limit_kw": 0.0             # 0代表防逆流 (不允许卖电给电网)
        }
    },
    "financial_params": {
        "total_capex": 18000.0,              # 系统总造价 $18,000
        "annual_opex": 150.0,                # 每年基础维护费 $150
        "battery_replacement_cost": 3000.0,  # 第10年换电池需 $3,000
        "battery_replacement_year": 10,
        
        "current_electricity_price": 0.25,   # 当前电价 $0.25/度 (拉美典型高电价)
        "electricity_inflation_rate": 0.08,  # 每年电费涨价 8% (刺激客户投资的核心)
        "voll_price": 2.0,                   # 断电惩罚费率 $2.0/度 (工厂停工损失)
        "system_degradation_rate": 0.015,    # 每年系统整体衰减 1.5%
        
        "down_payment_pct": 0.20,            # 客户只付 20% 首付 ($3,600)
        "loan_term_years": 5,                # 贷款 5 年
        "loan_interest_rate": 0.12,          # 贷款年利率高达 12%
        "discount_rate": 0.10,               # 资金贴现率(WACC) 10%
        "project_lifespan": 20               # 测算 20 年寿命
    }
}

# ==========================================
# 3. 发送网络请求并打印精美研报
# ==========================================
print("🚀 正在向光储引擎发送 8760 小时测算请求...")
response = requests.post(
    "http://127.0.0.1:8000/api/v1/simulate", 
    json=payload,
    proxies={"http": None, "https": None}
)

if response.status_code == 200:
    data = response.json()
    kpis = data["physics_result"]["kpis"]
    fin = data["finance_result"]
    
    print("\n" + "="*40)
    print("📊 [光储大师] 20年综合报价研报生成")
    print("="*40)
    print(f"🌞 自发自用率:   {kpis['self_consumption_rate']*100:.1f}%")
    print(f"🔋 能源独立性:   {kpis['autarky_rate']*100:.1f}%")
    print("-" * 40)
    print(f"💰 投资净现值(NPV): ${fin['npv']:,.2f}")
    print(f"📈 内部收益率(IRR): {fin['irr']:.2f}% (含杠杆)")
    print(f"⏱️ 投资回本周期:   {fin['payback_period_years']} 年")
    print(f"⚡ 平准化度电成本:  ${fin['lcoe']:.4f} / kWh")
    print("="*40)
    
    print("\n📅 20年现金流明细表 (Cash Flow Statement):")
    print("-" * 110)
    print(f"{'年份':<4} | {'节省电费':<12} | {'挽回停电损失':<12} | {'运维/换电池':<12} | {'还本付息(贷款)':<12} | {'当年净现金流':<14} | {'累计现金流':<14}")
    print("-" * 110)
    
    # 使用 [1:] 代表从第 1 年一直遍历到最后一年（第 20 年）
    for year_data in fin['cash_flow_statement'][1:]: 
        print(f"第{year_data['year']:2.0f}年 | "
              f"${year_data['energy_savings_revenue']:>10,.2f} | "
              f"${year_data['backup_power_value']:>10,.2f} | "
              f"-${year_data['opex_and_replacement']:>11,.2f} | "
              f"-${year_data['debt_service']:>12,.2f} | "
              f"${year_data['net_cash_flow']:>13,.2f} | "
              f"${year_data['cumulative_cash_flow']:>13,.2f}")
    print("-" * 110)
else:
    print(f"❌ 请求失败，状态码: {response.status_code}")
    print(response.text)