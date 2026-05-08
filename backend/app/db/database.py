import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import NullPool

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

# Neon (serverless Postgres) auto-suspends compute only when there are zero
# active connections. SQLAlchemy's default QueuePool keeps idle TCP/SSL
# connections alive forever, which prevents auto-suspend and pins CU usage
# at 0.25. For Neon we therefore use NullPool: each request opens a fresh
# connection and closes it on session.close(), so Neon can suspend.
_is_neon = "neon.tech" in (DATABASE_URL or "")

_engine_kwargs: dict = {
    "pool_pre_ping": True,
    "future": True,
}

if _is_neon:
    _engine_kwargs["poolclass"] = NullPool
    # TCP keepalives prevent half-open connections during a single request;
    # they are TCP-layer packets and do NOT generate SQL traffic / CU usage.
    _engine_kwargs["connect_args"] = {
        "connect_timeout": 10,
        "keepalives": 1,
        "keepalives_idle": 30,
        "keepalives_interval": 10,
        "keepalives_count": 5,
        "sslmode": "require",
    }
else:
    # Local / self-hosted Postgres: use the standard pool but recycle
    # connections before NAT/firewall idle timeouts can kill them.
    _engine_kwargs["pool_size"] = 5
    _engine_kwargs["max_overflow"] = 10
    _engine_kwargs["pool_recycle"] = 280

engine = create_engine(DATABASE_URL, **_engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
