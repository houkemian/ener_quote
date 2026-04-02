# 文件路径: app/db/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm import declarative_base

# 🌟 使用 SQLite 本地数据库，文件会直接生成在项目根目录的 pv_ess.db
SQLALCHEMY_DATABASE_URL = "sqlite:///./pv_ess.db"

# SQLite 专属配置：允许跨线程使用 (check_same_thread)
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# 创建一个工厂，用来给每个请求生成独立的数据库会话 (Session)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 🌟 这就是你的 models.py 苦苦寻找的那个 Base 基类！
Base = declarative_base()