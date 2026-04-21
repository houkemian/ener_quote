# 文件路径: app/api/v1/settings.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api.deps import get_db
from app.api.deps import get_current_user_payload, TokenPayload
from datetime import datetime, timedelta
import re

# 假设你之前在 deps.py 里写过 JWT 验证，名叫 get_current_user_payload
# 这个函数应该返回解析后的 Token Payload，里面包含了当前请求的 user_id (通常是 sub 字段)
from app.api.deps import get_current_user_payload 

from app.models.user_settings import UserSettings
from app.schemas.user_settings import UserSettingsUpdate, UserSettingsResponse
from app.modules.iam.models import User
from app.modules.iam.models import PaymentOrder

router = APIRouter(prefix="/settings", tags=["业务配置 - Settings"])
_EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

def get_or_create_settings(db: Session, user_id: str) -> UserSettings:
    """内部辅助函数：获取用户配置，如果没有则懒加载创建"""
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


def _resolve_account_email(db: Session, user_id: str) -> str | None:
    """
    优先按 IAM 主键查询邮箱；兼容历史 token/sub 为邮箱字符串的情况。
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user and user.email:
        return user.email

    # 兼容旧 token：sub 可能直接是邮箱
    user_by_email = db.query(User).filter(User.email == user_id).first()
    if user_by_email and user_by_email.email:
        return user_by_email.email

    # 最后兜底：如果 user_id 本身像邮箱，直接展示
    if _EMAIL_REGEX.match(user_id):
        return user_id

    return None


def _resolve_effective_tier(user: User | None) -> str:
    if not user:
        return "FREE"
    if user.tier == "PRO":
        if user.pro_expire_date and user.pro_expire_date > datetime.utcnow():
            return "PRO"
        return "FREE"
    return user.tier


def _resolve_billing_issue_notice(
    db: Session,
    user_id: str,
    effective_tier: str,
) -> tuple[str | None, datetime | None]:
    if effective_tier != "PRO":
        return None, None

    latest_issue = (
        db.query(PaymentOrder)
        .filter(
            PaymentOrder.user_id == user_id,
            PaymentOrder.event_type == "BILLING_ISSUE",
        )
        .order_by(PaymentOrder.occurred_at.desc(), PaymentOrder.created_at.desc())
        .first()
    )
    if not latest_issue:
        return None, None

    issue_time = latest_issue.occurred_at or latest_issue.created_at
    if not issue_time:
        return None, None

    grace_until = issue_time + timedelta(days=3)
    if grace_until <= datetime.utcnow():
        return None, None

    return None, grace_until

@router.get("/me", response_model=UserSettingsResponse)
def get_my_settings(
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload)
):
    """获取当前登录用户的专属配置"""
    user_id = current_user.user_id # 根据你 JWT 里的实际主键字段名来定
    settings = get_or_create_settings(db, user_id)
    user = db.query(User).filter(User.id == user_id).first()
    account_email = _resolve_account_email(db, user_id)
    effective_tier = _resolve_effective_tier(user)
    pro_expire_date = user.pro_expire_date if (user and effective_tier == "PRO") else None
    billing_issue_notice, billing_issue_grace_until = _resolve_billing_issue_notice(
        db, user_id, effective_tier
    )
    if user and user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()
    return {
        "user_id": settings.user_id,
        "account_email": account_email,
        "tier": effective_tier,
        "pro_expire_date": pro_expire_date,
        "billing_issue_notice": billing_issue_notice,
        "billing_issue_grace_until": billing_issue_grace_until,
        "company_name": settings.company_name,
        "logo_url": settings.logo_url,
        "pv_cost_per_kw": settings.pv_cost_per_kw,
        "ess_cost_per_kwh": settings.ess_cost_per_kwh,
        "margin_pct": settings.margin_pct,
    }

@router.put("/me", response_model=UserSettingsResponse)
def update_my_settings(
    settings_in: UserSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload)

):
    """修改当前用户的专属配置"""
    user_id = current_user.user_id
    settings = get_or_create_settings(db, user_id)
    user = db.query(User).filter(User.id == user_id).first()
    effective_tier = _resolve_effective_tier(user)

    # 动态更新前端传过来的非空字段
    update_data = settings_in.dict(exclude_unset=True)
    restricted_cost_keys = {"pv_cost_per_kw", "ess_cost_per_kwh", "margin_pct"}
    if effective_tier != "PRO" and any(key in update_data for key in restricted_cost_keys):
        raise HTTPException(status_code=403, detail="PRO required for cost settings")

    for key, value in update_data.items():
        setattr(settings, key, value)

    db.commit()
    db.refresh(settings)
    user = db.query(User).filter(User.id == user_id).first()
    account_email = _resolve_account_email(db, user_id)
    effective_tier = _resolve_effective_tier(user)
    pro_expire_date = user.pro_expire_date if (user and effective_tier == "PRO") else None
    billing_issue_notice, billing_issue_grace_until = _resolve_billing_issue_notice(
        db, user_id, effective_tier
    )
    if user and user.tier != effective_tier:
        user.tier = effective_tier
        db.commit()
    
    return {
        "user_id": settings.user_id,
        "account_email": account_email,
        "tier": effective_tier,
        "pro_expire_date": pro_expire_date,
        "billing_issue_notice": billing_issue_notice,
        "billing_issue_grace_until": billing_issue_grace_until,
        "company_name": settings.company_name,
        "logo_url": settings.logo_url,
        "pv_cost_per_kw": settings.pv_cost_per_kw,
        "ess_cost_per_kwh": settings.ess_cost_per_kwh,
        "margin_pct": settings.margin_pct,
    }