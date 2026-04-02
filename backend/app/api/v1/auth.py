from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from app.api.deps import get_current_user_payload, TokenPayload # 🌟 引入安检门

from app.core.security import create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
from app.api.deps import get_db
# 🌟 引入真实的 IAM 用户表和密码校验工具
from app.modules.iam.models import User as IAMUser
from app.modules.iam.security import verify_password

router = APIRouter()

@router.post("/login")
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """真实查库登录，发放携带 tier (权限) 的 JWT"""
    # 1. 去数据库查这个邮箱
    user = db.query(IAMUser).filter(IAMUser.email == form_data.username).first()
    
    # 2. 验证密码
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="账号或密码错误",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 3. 制作 Token 载荷 (Payload)，把真实的主键和权限塞进去！
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user.id,              # 真实的 UUID
            "company_id": "solo-tenant", # MVP 阶段单人单企
            "role": "SALES",
            "tier": user.tier            # 🌟 核心：把 FREE 或 PRO 写进通行证！
        },
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/refresh")
async def refresh_token(
    current_user: TokenPayload = Depends(get_current_user_payload),
    db: Session = Depends(get_db)
):
    """Token 以旧换新：用于支付完成后无感刷新前端权限"""
    # 1. 拿着旧 Token 里的 user_id 去查数据库的最新状态
    user = db.query(IAMUser).filter(IAMUser.id == current_user.user_id).first()
    
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="用户不存在或已被禁用")

    # 2. 重新签发一张全新的 Token，把最新的 tier 写进去
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_token = create_access_token(
        data={
            "sub": user.id,
            "company_id": current_user.company_id,
            "role": current_user.role,
            "tier": user.tier  # 🌟 这里会读取刚刚被 Stripe Webhook 改成 PRO 的最新状态！
        },
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": new_token, 
        "token_type": "bearer",
        "tier": user.tier # 顺便把状态明文返回给前端更新 UI
    }