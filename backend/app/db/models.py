import uuid
from sqlalchemy import Column, String, Boolean, Float, ForeignKey, JSON
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.types import Uuid

# 创建 SQLAlchemy 的基类
Base = declarative_base()

# ==========================================
# 1. 租户表 (Companies) - 隔离的源头
# ==========================================
class Company(Base):
    __tablename__ = "companies"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, index=True) # 企业名称，如 "隆基拉美分公司"
    subscription_tier = Column(String(20), default="PRO")  # 订阅等级：FREE, PRO, ENTERPRISE
    is_active = Column(Boolean, default=True)              # 账号状态：欠费一键停用

    # 反向关联：一个公司下有多个用户、多个私有硬件价格、多个项目
    users = relationship("User", back_populates="company", cascade="all, delete-orphan")
    hardware_prices = relationship("HardwarePricing", back_populates="company", cascade="all, delete-orphan")
    projects = relationship("Project", back_populates="company", cascade="all, delete-orphan")


# ==========================================
# 2. 用户表 (Users) - 老板与销售的账号池
# ==========================================
class User(Base):
    __tablename__ = "users"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(Uuid(as_uuid=True), ForeignKey("companies.id"), nullable=False, index=True)
    
    email = Column(String(150), unique=True, nullable=False, index=True) # 登录账号
    password_hash = Column(String(255), nullable=False)                  # 加密密码，绝不存明文
    role = Column(String(20), nullable=False, default="SALES")           # 角色：ADMIN 或 SALES
    is_active = Column(Boolean, default=True)

    # 关联
    company = relationship("Company", back_populates="users")
    projects = relationship("Project", back_populates="owner")


# ==========================================
# 3. 企业私有硬件库 (HardwarePricing) - 利润控制台
# ==========================================
class HardwarePricing(Base):
    __tablename__ = "hardware_pricing"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(Uuid(as_uuid=True), ForeignKey("companies.id"), nullable=False, index=True)
    
    component_type = Column(String(50), nullable=False) # 硬件类型：如 "BATTERY", "PV_PANEL", "INVERTER"
    base_cost = Column(Float, nullable=False)           # 真实拿货底价 (仅 Admin 可见/修改)
    sales_markup = Column(Float, default=0.30)          # 溢价比例，默认加价 30% 卖给客户

    # 关联
    company = relationship("Company", back_populates="hardware_prices")


# ==========================================
# 4. 项目报价单表 (Projects) - 业务员的摇钱树
# ==========================================
class Project(Base):
    __tablename__ = "projects"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(Uuid(as_uuid=True), ForeignKey("companies.id"), nullable=False, index=True)
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False) # 记录是谁谈的单子
    
    client_name = Column(String(150), nullable=False) # 客户名称，如 "圣保罗某冷链物流园"
    
    # 核心业务资产：将 Flutter 传来的几百个配置参数（光伏容量、真实坐标、日照数据等）直接压缩存入 JSON
    simulation_data = Column(JSON, nullable=False) 

    # 关联
    company = relationship("Company", back_populates="projects")
    owner = relationship("User", back_populates="projects")