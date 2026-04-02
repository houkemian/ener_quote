import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime
# 这里假设你的全局 Base 在 app.db.base，如果是别的路径请替换
from app.db.database import Base 

class User(Base):
    __tablename__ = "iam_users" # 加上前缀，防止未来和其他模块表名冲突

    # 基础身份
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    
    # 🌟 SSO 兼容设计：允许密码为空！(因为第三方登录没有密码)
    hashed_password = Column(String, nullable=True) 
    
    # 🌟 SSO 提供商标识：'local' (默认账号密码), 'google', 'apple', 'microsoft'
    auth_provider = Column(String, default="local", nullable=False)
    provider_id = Column(String, unique=True, nullable=True, index=True)

    # 💰 SaaS 订阅权益模型
    tier = Column(String, default="FREE", nullable=False) # 比如: FREE, PRO, ENTERPRISE
    pro_expire_date = Column(DateTime, nullable=True)     # 订阅到期时间

    # 🌟 新增：忘记密码的验证码及过期时间
    reset_code = Column(String(6), nullable=True)
    reset_code_expire = Column(DateTime, nullable=True)

    # 系统字段
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)