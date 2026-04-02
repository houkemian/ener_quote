import os
from dotenv import load_dotenv

# 自动寻找项目根目录的 .env 文件并加载到操作系统的环境变量中
load_dotenv()

# 从环境变量中安全提取密钥
SECRET_KEY = os.getenv("SECRET_KEY", "default_secret_please_change")
STRIPE_API_KEY = os.getenv("STRIPE_API_KEY")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET")

# 顺便加个保险：如果没有读到 Stripe 密钥，在后端启动时就大声报错
if not STRIPE_API_KEY or not STRIPE_WEBHOOK_SECRET:
    print("⚠️ 警告: 未在 .env 文件中检测到 Stripe 密钥，支付模块将无法正常工作！")


# --- 邮件配置 ---
SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")