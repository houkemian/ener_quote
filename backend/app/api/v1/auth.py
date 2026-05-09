from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import TokenPayload, get_current_user_payload, get_db
from app.models.user_settings import UserSettings
from app.modules.iam.models import PaymentOrder, User as IAMUser
from app.modules.iam.schemas import DevLoginRequest, FirebaseIdTokenRequest
from app.core.config import APP_ENV, ENABLE_DEV_LOGIN
from app.core.security import create_access_token
from app.services.firebase_auth import verify_firebase_id_token

router = APIRouter()
_DEV_LOGIN_ALLOWED_EMAILS = {
    "gavinhkm@gmail.com",
    "houkemian@outlook.com",
    "cs5213344@163.com",
}


def _resolve_effective_tier(user: IAMUser) -> str:
    """权益判断：PRO 必须未过期，否则按 FREE。"""
    if user.tier == "PRO":
        if user.pro_expire_date and user.pro_expire_date > datetime.utcnow():
            return "PRO"
        return "FREE"
    return user.tier


def _upsert_firebase_user(
    db: Session,
    *,
    email: str,
    firebase_uid: str,
    auth_provider: str | None,
) -> IAMUser:
    """Find or create a user by Firebase UID with same-email auto-merge."""
    email_norm = email.strip().lower()
    provider = auth_provider or "firebase"
    by_uid = db.query(IAMUser).filter(IAMUser.firebase_uid == firebase_uid).first()
    if by_uid:
        if by_uid.email != email_norm:
            by_uid.email = email_norm
        if by_uid.auth_provider != provider:
            by_uid.auth_provider = provider
        db.commit()
        db.refresh(by_uid)
        return by_uid

    by_email = db.query(IAMUser).filter(IAMUser.email == email_norm).first()
    if not by_email:
        new_user = IAMUser(
            email=email_norm,
            hashed_password=None,
            auth_provider=provider,
            provider_id=firebase_uid,
            firebase_uid=firebase_uid,
            tier="FREE",
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user

    # 同邮箱自动合并：将旧账号绑定到 Firebase UID。
    uid_conflict = db.query(IAMUser).filter(IAMUser.firebase_uid == firebase_uid).first()
    if uid_conflict and uid_conflict.id != by_email.id:
        raise HTTPException(status_code=409, detail="Firebase UID already bound to another account")

    if by_email.firebase_uid is None:
        by_email.firebase_uid = firebase_uid
    if by_email.provider_id is None:
        by_email.provider_id = firebase_uid
    by_email.auth_provider = provider
    db.commit()
    db.refresh(by_email)
    return by_email


@router.post("/firebase")
async def authenticate_with_firebase(
    body: FirebaseIdTokenRequest,
    db: Session = Depends(get_db),
):
    """Verify Firebase ID token and upsert IAM user."""
    try:
        claims = verify_firebase_id_token(body.firebase_id_token)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    firebase_uid = str(claims.get("user_id") or claims.get("sub") or "").strip()
    email = str(claims.get("email") or "").strip().lower()
    if not firebase_uid or not email:
        raise HTTPException(status_code=400, detail="Firebase token missing uid or email")
    if claims.get("email_verified") is not True:
        raise HTTPException(status_code=403, detail="Firebase email is not verified")

    provider = claims.get("firebase", {}).get("sign_in_provider")
    user = _upsert_firebase_user(
        db,
        email=email,
        firebase_uid=firebase_uid,
        auth_provider=str(provider) if provider else None,
    )
    effective_tier = _resolve_effective_tier(user)
    if user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()
    return {
        "token_type": "bearer",
        "tier": effective_tier,
        "user_id": user.id,
        "firebase_uid": user.firebase_uid,
        "auth_provider": user.auth_provider,
    }


@router.post("/dev-login")
async def dev_login(
    body: DevLoginRequest,
    db: Session = Depends(get_db),
):
    """Development-only local login: upsert user and issue server JWT."""
    if not ENABLE_DEV_LOGIN or APP_ENV not in {"dev", "development", "local", "test"}:
        raise HTTPException(status_code=404, detail="Not Found")

    email = body.email.strip().lower()
    firebase_uid = body.firebase_uid.strip()
    if not email or not firebase_uid:
        raise HTTPException(status_code=400, detail="email/firebase_uid is required")
    if email not in _DEV_LOGIN_ALLOWED_EMAILS:
        raise HTTPException(status_code=403, detail="dev-login email is not allowed")

    user = _upsert_firebase_user(
        db,
        email=email,
        firebase_uid=firebase_uid,
        auth_provider="dev",
    )
    user.tier = (body.tier or "FREE").strip().upper()
    user.is_active = bool(body.is_active)
    if body.pro_expire_date.strip():
        try:
            user.pro_expire_date = datetime.strptime(body.pro_expire_date.strip(), "%Y-%m-%d")
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="pro_expire_date must be YYYY-MM-DD") from exc
    db.commit()
    db.refresh(user)

    access_token = create_access_token(
        {
            "sub": user.id,
            "user_id": user.id,
            "firebase_uid": user.firebase_uid or firebase_uid,
            "email": user.email,
            "company_id": "solo-tenant",
            "role": "SALES",
            "tier": _resolve_effective_tier(user),
            "auth_provider": "dev",
        }
    )
    return {
        "token_type": "bearer",
        "access_token": access_token,
        "tier": user.tier,
        "user_id": user.id,
        "firebase_uid": user.firebase_uid,
        "auth_provider": "dev",
    }


@router.api_route("/logout", methods=["DELETE", "POST"], status_code=status.HTTP_200_OK)
async def logout_and_delete_current_user(
    current_user: TokenPayload = Depends(get_current_user_payload),
    db: Session = Depends(get_db),
):
    """
    用户注销（账号删除）：
    1) 先通过依赖校验当前 Bearer Token；
    2) 在同一事务中删除用户相关数据并删除用户；
    3) 返回 200 确认信息。
    """
    with db.begin():
        user = db.query(IAMUser).filter(IAMUser.id == current_user.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")

        # 避免外键约束冲突：解绑支付记录与用户配置，再删除用户
        db.query(PaymentOrder).filter(PaymentOrder.user_id == current_user.user_id).update(
            {PaymentOrder.user_id: None},
            synchronize_session=False,
        )
        db.query(UserSettings).filter(UserSettings.user_id == current_user.user_id).delete(
            synchronize_session=False
        )
        db.delete(user)

    return {"message": "用户已注销并删除成功"}