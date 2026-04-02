# 文件路径: app/schemas/user_settings.py
from pydantic import BaseModel
from typing import Optional

# 前端更新配置时传过来的数据（全部设为可选，支持只改某一项）
class UserSettingsUpdate(BaseModel):
    company_name: Optional[str] = None
    logo_url: Optional[str] = None
    pv_cost_per_kw: Optional[float] = None
    ess_cost_per_kwh: Optional[float] = None
    margin_pct: Optional[float] = None

# 返回给前端的完整配置数据
class UserSettingsResponse(BaseModel):
    user_id: str
    company_name: str
    logo_url: Optional[str]
    pv_cost_per_kw: float
    ess_cost_per_kwh: float
    margin_pct: float

    class Config:
        from_attributes = True # 兼容 SQLAlchemy 的 ORM 模式