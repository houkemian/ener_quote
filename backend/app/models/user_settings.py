# 文件路径: app/models/user_settings.py
from sqlalchemy import Column, String, Float, ForeignKey
from app.db.database import Base

class UserSettings(Base):
    __tablename__ = "user_settings"

    # 🌟 核心：一对一绑定！将主键直接设为 iam_users 表的 ID
    user_id = Column(String, ForeignKey("iam_users.id"), primary_key=True, index=True)
    
    # 🎨 企业品牌字段
    company_name = Column(String, default="My Solar Company")
    logo_url = Column(String, nullable=True)
    
    # 💰 采购成本与利润率字段
    pv_cost_per_kw = Column(Float, default=800.0)
    ess_cost_per_kwh = Column(Float, default=350.0)
    margin_pct = Column(Float, default=20.0)