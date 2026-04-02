import httpx
from typing import List
from fastapi import HTTPException
from datetime import datetime


async def fetch_pvgis_hourly_irradiance(lat: float, lon: float, tilt: float = 30.0, azimuth: float = 0.0) -> List[float]:
    
    start = datetime.now()
    
    print("跨国连接欧盟 PVGIS 气象卫星获取真实光照：开始时间", start.strftime("%Y-%m-%d %H:%M:%S"))
    
    """
    调用欧盟 PVGIS API，获取指定经纬度的 8760 小时真实光照辐射数据。
    """
    url = "https://re.jrc.ec.europa.eu/api/v5_2/seriescalc"
    
    # 我们固定使用 2019 年的数据（非闰年，刚好是 8760 个小时）
    params = {
        "lat": lat,
        "lon": lon,
        "startyear": 2019,
        "endyear": 2019,
        "angle": tilt,      # 光伏板倾角
        "aspect": azimuth,  # 光伏板朝向 (0=正南)
        "outputformat": "json"
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, params=params, timeout=20.0)
            
            if response.status_code != 200:
                print(f"PVGIS 报错: {response.text}")
                raise HTTPException(status_code=400, detail="获取气象数据失败，请检查经纬度。")
                
            data = response.json()
            hourly_data = data["outputs"]["hourly"]
            
            # 提取 G(i): 倾斜面上的全局辐照度 (Global irradiance on an inclined plane)
            irradiance_8760 = [float(hour["G(i)"]) for hour in hourly_data]
            
            end = datetime.now()
            interval = end - start

            print("跨国连接欧盟 PVGIS 气象卫星获取真实光照：结束时间", end.strftime("%Y-%m-%d %H:%M:%S"))
            print("跨国连接欧盟 PVGIS 气象卫星获取真实光照：耗时时间(S)", interval.total_seconds())


            # 严谨起见，确保数组长度绝对等于 8760，防止物理状态机越界崩溃
            return irradiance_8760[:8760]
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"气象 API 连接异常: {str(e)}")