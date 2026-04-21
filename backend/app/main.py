import logging
import os
import random
from pathlib import Path

import redis
from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi.responses import FileResponse
from fastapi.templating import Jinja2Templates

from fastapi.middleware.cors import CORSMiddleware
from app.api.v1 import simulation, auth # 引入 auth
from app.api.deps import get_current_user_payload, get_db
from sqlalchemy.orm import Session

from app.modules.iam.router import router as iam_router # 导入独立模块
from app.api.v1.locations import router as locations_router

from app.db.database import engine, Base
# 引入你写好的 IAM User 模型，这样 Base 才能“看到”它
from app.modules.iam.models import User

# 🌟 1. 必须导入 UserSettings 模型，否则 Base.metadata.create_all 看不到它！
from app.models.user_settings import UserSettings 
# 🌟 2. 导入我们刚刚写好的 settings 路由
from app.api.v1.settings import router as settings_router
from app.api.v1 import payment  # 🌟 新增：引入咱们写好的支付模块
from app.modules.iam.models import PaymentOrder
from app.utils.email_sender import send_register_otp_email


def _setup_logging() -> logging.Logger:
    """Ensure app logger prints under uvicorn and direct runs."""
    app_logger = logging.getLogger("app")
    app_logger.setLevel(logging.INFO)

    uvicorn_logger = logging.getLogger("uvicorn.error")
    if uvicorn_logger.handlers:
        app_logger.handlers = uvicorn_logger.handlers
        app_logger.propagate = False
    elif not app_logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
            )
        )
        app_logger.addHandler(handler)
        app_logger.propagate = False

    return app_logger


logger = _setup_logging()
logger.info("App logger initialized.")

TEMPLATES = Jinja2Templates(
    directory=str(Path(__file__).resolve().parents[1] / "templates")
)
DELETE_PORTAL_OTP_PREFIX = "delete_portal:otp:"
DELETE_PORTAL_COOLDOWN_PREFIX = "delete_portal:cooldown:"
DELETE_PORTAL_OTP_TTL_SECONDS = 300
DELETE_PORTAL_COOLDOWN_SECONDS = 60
redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    db=int(os.getenv("REDIS_DB", "2")),
    password=os.getenv("REDIS_PASSWORD"),
    decode_responses=True,
)


# 1. 初始化 FastAPI 应用，并配置专业的 Swagger 文档信息
app = FastAPI(
    title="光储大师 (PV + ESS Quote Master) 计算引擎",
    description="面向 2026 年全球市场的 B 端光储财务与物理模拟核心 API。支持 8760 小时能量流闭环与拉美高息/通胀/备电金融测算。",
    version="0.1.0",
)

# 🌟 一键生成所有数据库表！(如果表已经存在，它不会覆盖)
Base.metadata.create_all(bind=engine)

# 2. 配置 CORS (跨域资源共享)
# 为了方便前期开发，这里允许所有来源("*")。上线时需替换为你的真实 App 域名。
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(iam_router, prefix="/api/v1")

# 3. 注册核心业务路由
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"]) # 注册登录接口
app.include_router(
    settings_router, 
    prefix="/api/v1", 
    tags=["settings"],
    dependencies=[Depends(get_current_user_payload)] # 👈 保安站在这里
)

# 2. 🌟 测算业务模块：在 Router 级别统一挂载拦截器！
# 这样 simulation.py 里的所有 @router.post 都不用再写鉴权代码了，进这个门必须刷卡！
app.include_router(
    simulation.router, 
    prefix="/api/v1", 
    tags=["Simulation"],
    dependencies=[Depends(get_current_user_payload)] # 👈 保安站在这里
)

app.include_router(
    locations_router, 
    prefix="/api/v1", 
    tags=["locations"])

app.include_router(
    payment.router, 
    prefix="/api/v1/payment", 
    tags=["Payment - Paddle Billing"])


@app.post("/webhook/revenuecat", tags=["Payment - RevenueCat Webhook"])
async def revenuecat_webhook_entry(
    request: Request,
    db: Session = Depends(get_db),
):
    # 兼容直连地址，同时复用 payment 模块中的核心处理逻辑。
    return await payment.revenuecat_webhook(request, db)


# 4. 健康检查探针 (Health Check)
# 用于云服务器自动检测该引擎是否存活
@app.get("/", tags=["System / 系统"])
async def root():
    return {
        "status": "online",
        "message": "光储大师计算引擎已启动！请访问 /docs 查看交互式 API 文档。",
        "engine_version": "V0.3 (拉美金融完全体)"
    }

@app.get("/privacy", tags=["Legal"])
@app.get("/privacy.html", tags=["Legal"])
def get_privacy_policy():
    return FileResponse(os.path.join("static", "privacy.html"))

@app.get("/terms", tags=["Legal"])
@app.get("/terms.html", tags=["Legal"])
def get_terms_of_service():
    return FileResponse(os.path.join("static", "terms.html"))


@app.get("/account-deletion", tags=["Legal"])
async def account_deletion_portal(request: Request):
    return TEMPLATES.TemplateResponse(
        request=request,
        name="delete_account_portal.html",
    )


@app.post("/account-deletion/send-code", tags=["Legal"])
async def send_account_deletion_code(payload: dict, db: Session = Depends(get_db)):
    email_raw = str(payload.get("email", "")).strip().lower()
    if "@" not in email_raw:
        raise HTTPException(status_code=422, detail="Invalid email format")

    cooldown_key = f"{DELETE_PORTAL_COOLDOWN_PREFIX}{email_raw}"
    if redis_client.exists(cooldown_key):
        raise HTTPException(status_code=429, detail="Please wait before requesting a new code")

    user = db.query(User).filter(User.email == email_raw).first()
    if not user:
        # 避免泄露账号是否存在，前端统一显示“已发送”
        return {"ok": True, "message": "If the email exists, a verification code has been sent"}

    otp_code = f"{random.randint(0, 999999):06d}"
    redis_client.setex(f"{DELETE_PORTAL_OTP_PREFIX}{email_raw}", DELETE_PORTAL_OTP_TTL_SECONDS, otp_code)
    redis_client.setex(cooldown_key, DELETE_PORTAL_COOLDOWN_SECONDS, "1")
    await send_register_otp_email(email_raw, otp_code, "en")

    return {"ok": True, "message": "Verification code sent"}


@app.post("/account-deletion/confirm", tags=["Legal"])
async def confirm_account_deletion(payload: dict, db: Session = Depends(get_db)):
    email_raw = str(payload.get("email", "")).strip().lower()
    code = str(payload.get("code", "")).strip()
    acknowledged = bool(payload.get("acknowledged", False))

    if "@" not in email_raw:
        raise HTTPException(status_code=422, detail="Invalid email format")
    if len(code) != 6 or not code.isdigit():
        raise HTTPException(status_code=422, detail="Invalid verification code")
    if not acknowledged:
        raise HTTPException(status_code=400, detail="You must acknowledge the deletion warning")

    otp_key = f"{DELETE_PORTAL_OTP_PREFIX}{email_raw}"
    saved_code = redis_client.get(otp_key)
    if not saved_code or saved_code != code:
        raise HTTPException(status_code=400, detail="Verification code is invalid or expired")

    with db.begin():
        user = db.query(User).filter(User.email == email_raw).first()
        if not user:
            redis_client.delete(otp_key)
            return {"ok": True, "message": "Account already deleted"}

        db.query(PaymentOrder).filter(PaymentOrder.user_id == user.id).update(
            {PaymentOrder.user_id: None},
            synchronize_session=False,
        )
        db.query(UserSettings).filter(UserSettings.user_id == user.id).delete(
            synchronize_session=False
        )
        db.delete(user)

    redis_client.delete(otp_key)
    redis_client.delete(f"{DELETE_PORTAL_COOLDOWN_PREFIX}{email_raw}")
    return {"ok": True, "message": "Your account has been permanently deleted"}