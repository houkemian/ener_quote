import jwt
from datetime import datetime, timedelta
from passlib.context import CryptContext

# 🌟 从中央配置库安全引入门禁密钥
from app.core.config import SECRET_KEY


ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 门禁卡有效期：7天 (方便销售出差不用天天登录)

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
        
    # 将过期时间写入 Token 载荷
    to_encode.update({"exp": expire})
    
    # 使用私钥进行数字签名，防止前端伪造
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt