from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import jwt
from pydantic import BaseModel

from app.core.security import SECRET_KEY, ALGORITHM

from typing import Generator
from app.db.database import SessionLocal # 引入刚才写好的 Session 工厂



# 告诉 FastAPI，前端应该向哪个地址发送账号密码来换取 Token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class TokenPayload(BaseModel):
    user_id: str
    company_id: str
    role: str
    tier: str  # 🌟 新增：拦截器能识别当前用户的付费等级了！

async def get_current_user_payload(token: str = Depends(oauth2_scheme)) -> TokenPayload:
    """
    终极安检门：拦截所有请求，撕开 Token，提取公司 ID
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="认证失败，门禁卡无效或已过期",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # 1. 验证签名是否被篡改，并解码内容
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # 2. 提取核心 SaaS 隔离数据
        user_id: str = payload.get("sub")
        company_id: str = payload.get("company_id")
        role: str = payload.get("role")
        tier: str = payload.get("tier", "FREE") # 🌟 提取权限，默认 FREE
        
        if user_id is None or company_id is None:
            raise credentials_exception
            
        return TokenPayload(
            user_id=user_id, 
            company_id=company_id, 
            role=role,
            tier=tier # 🌟 返回给业务方
        )
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录")
    except jwt.PyJWTError:
        raise credentials_exception
    

# 🌟 数据库依赖注入：FastAPI 会在每次接口被调用时，自动开门、关门
def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()