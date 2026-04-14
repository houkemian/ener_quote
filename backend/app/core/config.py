import os
from dotenv import load_dotenv

# 自动寻找项目根目录的 .env 文件并加载到操作系统的环境变量中
load_dotenv()

# 从环境变量中安全提取密钥
SECRET_KEY = os.getenv("SECRET_KEY", "default_secret_please_change")

# --- Paddle Billing (替代原 Stripe) ---
# API Key：Paddle Dashboard → Developer tools → Authentication
PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")
# 价格 ID：Catalog → Prices，形如 pri_xxx
PADDLE_PRICE_ID = os.getenv("PADDLE_PRICE_ID")
# sandbox 或 production（决定 API 根 URL）
PADDLE_ENVIRONMENT = os.getenv("PADDLE_ENVIRONMENT", "sandbox").strip().lower()
# Webhook：通知目标里的 endpoint secret（验签用）
PADDLE_WEBHOOK_SECRET = os.getenv("PADDLE_WEBHOOK_SECRET")
# Paddle.js（/payment/checkout-ui）：Dashboard → Developer tools → Authentication → Client-side token
PADDLE_CLIENT_TOKEN = os.getenv("PADDLE_CLIENT_TOKEN")
# 嵌入式收银台事件回调里跳转的 URL，需与 Flutter WebView 拦截规则一致（建议带 _ptxn=）
PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL = os.getenv(
    "PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL",
    "https://api.dothings.one/?_ptxn=completed",
)
PADDLE_CHECKOUT_CLOSED_REDIRECT_URL = os.getenv(
    "PADDLE_CHECKOUT_CLOSED_REDIRECT_URL",
    "https://api.dothings.one/?_ptxn=cancelled",
)

if not PADDLE_API_KEY or not PADDLE_PRICE_ID or not PADDLE_WEBHOOK_SECRET:
    print(
        "⚠️ 警告: 未在 .env 中完整配置 PADDLE_API_KEY / PADDLE_PRICE_ID / "
        "PADDLE_WEBHOOK_SECRET，支付模块将无法正常工作。"
    )


def paddle_api_base_url() -> str:
    if PADDLE_ENVIRONMENT in ("production", "live", "prod"):
        return "https://api.paddle.com"
    return "https://sandbox-api.paddle.com"


def paddle_js_environment() -> str:
    """Paddle.js Paddle.Environment.set：'sandbox' 或 'production'。"""
    if PADDLE_ENVIRONMENT in ("production", "live", "prod"):
        return "production"
    return "sandbox"


# --- 邮件配置 ---
# 兼容历史变量 SMTP_SERVER，同时优先采用 SMTP_HOST
SMTP_HOST = os.getenv("SMTP_HOST") or os.getenv("SMTP_SERVER")
SMTP_SERVER = SMTP_HOST
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "EnerQuote")
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "false").strip().lower() == "true"

# --- OAuth (Google / Microsoft ID token verification on backend) ---
# Comma-separated OAuth 2.0 Client IDs (Web / iOS / Android) that may appear as `aud` in Google ID tokens.
GOOGLE_OAUTH_CLIENT_IDS = os.getenv("GOOGLE_OAUTH_CLIENT_IDS", "191848630682-d0imac6vatistl9o2vnhv8qrtkrp2dj9.apps.googleusercontent.com,191848630682-tvkajg83h26ldjo9ph9ne5nup23a52pb.apps.googleusercontent.com")
# Azure "Application (client) ID" — must match the client used by the mobile app (flutter_appauth).
MICROSOFT_OAUTH_CLIENT_ID = os.getenv("MICROSOFT_OAUTH_CLIENT_ID", "")
