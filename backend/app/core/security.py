import jwt
from datetime import datetime, timedelta
from passlib.context import CryptContext
import os
from uuid import uuid4
import redis

# 🌟 从中央配置库安全引入门禁密钥
from app.core.config import SECRET_KEY


ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 门禁卡有效期：7天 (方便销售出差不用天天登录)
REDIS_DB = int(os.getenv("REDIS_DB", "2"))
REDIS_PREFIX = "jwt:access:"

redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    db=REDIS_DB,
    password=os.getenv("REDIS_PASSWORD"),
    decode_responses=True,
)

# 密码加密机 (使用工业级 bcrypt 算法)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证明文密码与数据库里的密文是否匹配"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """将明文密码转化为不可逆的密文存入数据库"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta = None) -> str:
    """签发包含多租户信息的 JWT 门禁卡"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
        
    jti = str(uuid4())
    # 将过期时间写入 Token 载荷
    to_encode.update({"exp": expire, "jti": jti})
    
    # 使用私钥进行数字签名，防止前端伪造
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    # 使用 Redis 保存 token 会话，便于服务端撤销与过期控制（DB 2）
    ttl_seconds = max(1, int((expire - datetime.utcnow()).total_seconds()))
    redis_client.setex(f"{REDIS_PREFIX}{jti}", ttl_seconds, "1")
    return encoded_jwt


def decode_and_validate_access_token(token: str) -> dict:
    """
    解码并校验 JWT，同时要求 Redis 会话存在（状态化 token）。
    """
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    jti = payload.get("jti")
    if not jti:
        raise jwt.PyJWTError("Token 缺少 jti")

    token_exists = redis_client.exists(f"{REDIS_PREFIX}{jti}")
    if not token_exists:
        raise jwt.PyJWTError("Token 已失效或已被撤销")

    return payload