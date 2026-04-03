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

if not PADDLE_API_KEY or not PADDLE_PRICE_ID or not PADDLE_WEBHOOK_SECRET:
    print(
        "⚠️ 警告: 未在 .env 中完整配置 PADDLE_API_KEY / PADDLE_PRICE_ID / "
        "PADDLE_WEBHOOK_SECRET，支付模块将无法正常工作。"
    )


def paddle_api_base_url() -> str:
    if PADDLE_ENVIRONMENT in ("production", "live", "prod"):
        return "https://api.paddle.com"
    return "https://sandbox-api.paddle.com"


# --- 邮件配置 ---
SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
