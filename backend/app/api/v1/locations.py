import json
import os
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/locations", tags=["地理位置 - Locations"])

# 🌟 动态计算配置文件的绝对路径：找到当前文件往上推 3 层的根目录
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
CITIES_FILE_PATH = os.path.join(BASE_DIR, "cities.json")

@router.get("/cities")
def get_supported_cities():
    """
    动态下发支持测算的城市列表。
    直接从根目录的 cities.json 中读取，实现配置解耦。
    """
    if not os.path.exists(CITIES_FILE_PATH):
        print(f"⚠️ 警告: 未找到城市配置文件 {CITIES_FILE_PATH}，返回默认兜底数据。")
        return [
            {
                "id": "sao_paulo", 
                "lat": -23.5505, 
                "lon": -46.6333, 
                "is_pro_only": False, 
                "name": {"zh": "🇧🇷 圣保罗 (巴西)", "en": "🇧🇷 São Paulo (Brazil)"}
            }
        ]
        
    try:
        # 每次请求实时读取文件（如果追求极致性能，未来可以加一层 Redis 或内存缓存）
        with open(CITIES_FILE_PATH, "r", encoding="utf-8") as f:
            cities_data = json.load(f)
        return cities_data
    except Exception as e:
        print(f"❌ 读取城市配置文件失败: {e}")
        raise HTTPException(status_code=500, detail="服务器内部错误：无法加载城市配置列表")