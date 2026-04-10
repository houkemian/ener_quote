# 文件路径: app/api/v1/settings.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.api.deps import get_db
from app.api.deps import get_current_user_payload, TokenPayload

# 假设你之前在 deps.py 里写过 JWT 验证，名叫 get_current_user_payload
# 这个函数应该返回解析后的 Token Payload，里面包含了当前请求的 user_id (通常是 sub 字段)
from app.api.deps import get_current_user_payload 

from app.models.user_settings import UserSettings
from app.schemas.user_settings import UserSettingsUpdate, UserSettingsResponse
from app.modules.iam.models import User

router = APIRouter(prefix="/settings", tags=["业务配置 - Settings"])

def get_or_create_settings(db: Session, user_id: str) -> UserSettings:
    """内部辅助函数：获取用户配置，如果没有则懒加载创建"""
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings

@router.get("/me", response_model=UserSettingsResponse)
def get_my_settings(
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload)
):
    """获取当前登录用户的专属配置"""
    user_id = current_user.user_id # 根据你 JWT 里的实际主键字段名来定
    settings = get_or_create_settings(db, user_id)
    user = db.query(User).filter(User.id == user_id).first()
    return {
        "user_id": settings.user_id,
        "account_email": user.email if user else None,
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

    # 动态更新前端传过来的非空字段
    update_data = settings_in.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(settings, key, value)

    db.commit()
    db.refresh(settings)
    user = db.query(User).filter(User.id == user_id).first()
    
    print(f"✅ 用户 {user_id} 的业务配置已更新。")
    return {
        "user_id": settings.user_id,
        "account_email": user.email if user else None,
        "company_name": settings.company_name,
        "logo_url": settings.logo_url,
        "pv_cost_per_kw": settings.pv_cost_per_kw,
        "ess_cost_per_kwh": settings.ess_cost_per_kwh,
        "margin_pct": settings.margin_pct,
    }