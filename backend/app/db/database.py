from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm import declarative_base
import os

# PostgreSQL connection config (can be overridden by DATABASE_URL).
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    db_user = os.getenv("DB_USER", "ener_quote")
    db_password = os.getenv("DB_PASSWORD", "ener_quote_password")
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "ener_quote")
    DATABASE_URL = (
        f"postgresql+psycopg2://{db_user}:{db_password}"
        f"@{db_host}:{db_port}/{db_name}"
    )

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

# 创建一个工厂，用来给每个请求生成独立的数据库会话 (Session)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 🌟 这就是你的 models.py 苦苦寻找的那个 Base 基类！
Base = declarative_base()