from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel

from app.modules.iam.models import User
from app.services.firebase_auth import verify_firebase_id_token

from typing import Generator
from app.db.database import SessionLocal # 引入刚才写好的 Session 工厂
from sqlalchemy.orm import Session



# 告诉 FastAPI，前端使用 Firebase token 与 /auth/firebase 完成登录态同步。
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/firebase")


# 🌟 数据库依赖注入：FastAPI 会在每次接口被调用时，自动开门、关门
def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class TokenPayload(BaseModel):
    user_id: str
    firebase_uid: str
    email: str
    company_id: str
    role: str
    tier: str  # 🌟 新增：拦截器能识别当前用户的付费等级了！

async def get_current_user_payload(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> TokenPayload:
    """
    终极安检门：拦截所有请求，撕开 Token，提取公司 ID
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="认证失败，门禁卡无效或已过期",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = verify_firebase_id_token(token)
    except ValueError:
        raise credentials_exception
    firebase_uid = str(payload.get("user_id") or payload.get("sub") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    if not firebase_uid or not email:
        raise credentials_exception

    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if not user:
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.firebase_uid = firebase_uid
            provider = payload.get("firebase", {}).get("sign_in_provider")
            if provider:
                user.auth_provider = str(provider)
            db.commit()
            db.refresh(user)
    if not user:
        raise credentials_exception

    return TokenPayload(
        user_id=user.id,
        firebase_uid=firebase_uid,
        email=email,
        company_id="solo-tenant",
        role="SALES",
        tier=user.tier or "FREE",
    )