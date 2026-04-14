from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from pydantic import EmailStr, TypeAdapter, ValidationError
from app.api.deps import get_current_user_payload, TokenPayload # 🌟 引入安检门

from app.core.security import create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
from app.api.deps import get_db
# 🌟 引入真实的 IAM 用户表和密码校验工具
from app.modules.iam.models import User as IAMUser
from app.modules.iam.security import verify_password
from app.modules.iam.schemas import OAuthIdTokenRequest
from app.services.oauth_id_tokens import verify_google_id_token, verify_microsoft_id_token

router = APIRouter()
email_adapter = TypeAdapter(EmailStr)


def _resolve_effective_tier(user: IAMUser) -> str:
    """权益判断：PRO 必须未过期，否则按 FREE。"""
    if user.tier == "PRO":
        if user.pro_expire_date and user.pro_expire_date > datetime.utcnow():
            return "PRO"
        return "FREE"
    return user.tier


def _issue_jwt_for_user(user: IAMUser, effective_tier: str) -> str:
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return create_access_token(
        data={
            "sub": user.id,
            "company_id": "solo-tenant",
            "role": "SALES",
            "tier": effective_tier,
        },
        expires_delta=access_token_expires,
    )


def _upsert_oauth_user(
    db: Session,
    *,
    email: str,
    provider_id: str,
    auth_provider: str,
) -> IAMUser:
    """Find or create user for Google / Microsoft. Conflicts with local password accounts return 409."""
    email_norm = email.strip().lower()

    by_sub = (
        db.query(IAMUser)
        .filter(
            IAMUser.auth_provider == auth_provider,
            IAMUser.provider_id == provider_id,
        )
        .first()
    )
    if by_sub:
        return by_sub

    by_email = db.query(IAMUser).filter(IAMUser.email == email_norm).first()
    if not by_email:
        new_user = IAMUser(
            email=email_norm,
            hashed_password=None,
            auth_provider=auth_provider,
            provider_id=provider_id,
            tier="FREE",
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user

    if by_email.auth_provider == "local" and by_email.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="该邮箱已使用密码注册，请使用密码登录",
        )
    if by_email.auth_provider != auth_provider:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"该邮箱已绑定其他登录方式（{by_email.auth_provider}）",
        )
    if by_email.provider_id is None:
        by_email.provider_id = provider_id
        db.commit()
        db.refresh(by_email)
        return by_email
    if by_email.provider_id == provider_id:
        return by_email
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="该邮箱已绑定其他第三方账号",
    )


@router.post("/login")
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """真实查库登录，发放携带 tier (权限) 的 JWT"""
    try:
        email_adapter.validate_python(form_data.username)
    except ValidationError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="邮箱格式不正确",
        )

    # 1. 去数据库查这个邮箱
    user = db.query(IAMUser).filter(IAMUser.email == form_data.username).first()
    
    # 2. 验证密码（纯 OAuth 账号无密码）
    if (
        not user
        or not user.hashed_password
        or not verify_password(form_data.password, user.hashed_password)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="账号或密码错误",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 3. 制作 Token 载荷 (Payload)，把真实的主键和权限塞进去！
    effective_tier = _resolve_effective_tier(user)
    if user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user.id,              # 真实的 UUID
            "company_id": "solo-tenant", # MVP 阶段单人单企
            "role": "SALES",
            "tier": effective_tier       # 🌟 核心：把 FREE 或 PRO 写进通行证！
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
    effective_tier = _resolve_effective_tier(user)
    if user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_token = create_access_token(
        data={
            "sub": user.id,
            "company_id": current_user.company_id,
            "role": current_user.role,
            "tier": effective_tier  # 🌟 tier + pro_expire_date 综合判断后的结果
        },
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": new_token, 
        "token_type": "bearer",
        "tier": effective_tier # 顺便把状态明文返回给前端更新 UI
    }


@router.post("/oauth/google")
async def oauth_google(body: OAuthIdTokenRequest, db: Session = Depends(get_db)):
    """使用 Google ID Token 登录或注册，签发 EnerQuote JWT。"""
    try:
        claims = verify_google_id_token(body.id_token)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    email = claims.get("email")
    sub = claims.get("sub")
    if not email or not sub:
        raise HTTPException(status_code=400, detail="Google token missing email or sub")

    user = _upsert_oauth_user(
        db,
        email=str(email),
        provider_id=str(sub),
        auth_provider="google",
    )
    effective_tier = _resolve_effective_tier(user)
    if user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()

    token = _issue_jwt_for_user(user, effective_tier)
    return {
        "access_token": token,
        "token_type": "bearer",
        "tier": effective_tier,
        "auth_provider": "google",
    }


@router.post("/oauth/microsoft")
async def oauth_microsoft(body: OAuthIdTokenRequest, db: Session = Depends(get_db)):
    """使用 Microsoft (Outlook / Azure AD) ID Token 登录或注册。"""
    try:
        claims = verify_microsoft_id_token(body.id_token)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    email = claims.get("email")
    sub = claims.get("sub")
    if not email or not sub:
        raise HTTPException(status_code=400, detail="Microsoft token missing email or sub")

    user = _upsert_oauth_user(
        db,
        email=str(email),
        provider_id=str(sub),
        auth_provider="microsoft",
    )
    effective_tier = _resolve_effective_tier(user)
    if user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()

    token = _issue_jwt_for_user(user, effective_tier)
    return {
        "access_token": token,
        "token_type": "bearer",
        "tier": effective_tier,
        "auth_provider": "microsoft",
    }