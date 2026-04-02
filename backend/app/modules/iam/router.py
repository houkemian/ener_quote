from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from app.utils.email_sender import send_otp_email # 🌟 引入咱们刚写的发件工具
from sqlalchemy.orm import Session
# 根据你的实际项目路径导入数据库依赖
from app.api.deps import get_db 

from .models import User
from .security import get_password_hash

import random
from datetime import datetime, timedelta
# 记得把刚写的 Schema 也引进来
from .schemas import UserRegister, UserResponse, ForgotPasswordRequest, ResetPasswordRequest

router = APIRouter(prefix="/auth", tags=["IAM - 身份与访问管理"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user_in: UserRegister, db: Session = Depends(get_db)):
    # 1. 查重：邮箱是否被注册过？
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="该邮箱已被注册。如果是您的账号，请直接登录。"
        )

    # 2. 密码加盐哈希
    hashed_pw = get_password_hash(user_in.password)

    # 3. 创建新用户，默认掉入 "FREE" 免费版漏斗
    new_user = User(
        email=user_in.email,
        hashed_password=hashed_pw,
        auth_provider="local",
        tier="FREE"
    )

    # 4. 落库保存
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    print(f"🎉 [IAM 模块] 新用户注册成功: {new_user.email}, 初始权限: {new_user.tier}")
    
    return new_user

# 注意：你原先写在 api/v1/auth.py 里的 login 接口，可以直接平移到这个文件里！

@router.post("/forgot-password")
async def request_password_reset(req: ForgotPasswordRequest, background_tasks: BackgroundTasks,db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        # 为了防黑客探测，即使邮箱不存在，也返回成功
        return {"message": "如果该邮箱已注册，验证码已发送。"}

    # 1. 生成 6 位纯数字验证码，15 分钟内有效
    code = str(random.randint(100000, 999999))
    user.reset_code = code
    user.reset_code_expire = datetime.utcnow() + timedelta(minutes=15)
    db.commit()

    background_tasks.add_task(send_otp_email, user.email, code, req.language)

    return {"message": "如果该邮箱已注册，验证码已发送。"}


@router.post("/reset-password")
async def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    # 校验验证码及是否过期
    if user.reset_code != req.reset_code or user.reset_code_expire < datetime.utcnow():
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    # 验证通过，重置密码
    user.hashed_password = get_password_hash(req.new_password)
    # 🌟 销毁验证码，防止二次使用
    user.reset_code = None
    user.reset_code_expire = None
    db.commit()

    return {"message": "密码重置成功，请使用新密码登录。"}