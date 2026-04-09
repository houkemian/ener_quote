import smtplib
from email.message import EmailMessage
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import aiosmtplib

from app.core.config import (
    SMTP_SERVER,
    SMTP_PORT,
    SMTP_USER,
    SMTP_PASSWORD,
    SMTP_FROM_NAME,
    SMTP_USE_TLS,
)

def send_otp_email(to_email: str, otp_code: str, lang: str = "en"):
    """
    发送带有高质感 HTML 样式的 6 位验证码邮件（支持多语言）
    """
    if not SMTP_USER or not SMTP_PASSWORD:
        print("⚠️ 邮件发送失败：未配置 SMTP 环境变量。")
        return

    # 1. 准备多语言字典 (默认兜底为英文 en)
    i18n = {
        "en": {
            "subject": "[Quote Master] Your Password Reset Code",
            "title": "Reset Your Password",
            "greeting": "Hello,",
            "instruction": "We received a request to reset your password. Your verification code is:",
            "validity": "This code is valid for <strong>15 minutes</strong>. If you did not request a password reset, please ignore this email.",
            "team": "Quote Master PV+ESS Team"
        },
        "zh": {
            "subject": "[Quote Master] 您的密码重置验证码",
            "title": "重置您的密码",
            "greeting": "您好，",
            "instruction": "我们收到了您重置密码的请求。您的验证码是：",
            "validity": "此验证码在 <strong>15 分钟</strong> 内有效。如果您没有请求重置密码，请忽略此邮件。",
            "team": "Quote Master PV+ESS 团队"
        },
        "es": {
            "subject": "[Quote Master] Tu código para restablecer la contraseña",
            "title": "Restablece tu contraseña",
            "greeting": "Hola,",
            "instruction": "Hemos recibido una solicitud para restablecer tu contraseña. Tu código de verificación es:",
            "validity": "Este código es válido por <strong>15 minutos</strong>. Si no solicitaste restablecer tu contraseña, puedes ignorar este correo de forma segura.",
            "team": "El equipo de Quote Master PV+ESS"
        },
        # 🌟 新增：巴西葡萄牙语 (Português do Brasil)
        "pt": {
            "subject": "[Quote Master] Seu código de redefinição de senha",
            "title": "Redefinir sua senha",
            "greeting": "Olá,",
            "instruction": "Recebemos uma solicitação para redefinir sua senha. Seu código de verificação é:",
            "validity": "Este código é válido por <strong>15 minutos</strong>. Se você não solicitou a redefinição de senha, pode ignorar este e-mail com segurança.",
            "team": "Equipe Quote Master PV+ESS"
        }
    }

    # 获取当前语言的文案，如果前端传了不支持的语言，默认回退到英文
    t = i18n.get(lang, i18n["en"])

    # 2. 构造邮件对象
    msg = MIMEMultipart()
    msg['From'] = f"Quote Master <{SMTP_USER}>"
    msg['To'] = to_email
    msg['Subject'] = t["subject"]

    # 3. 注入翻译文案的 HTML 模板
    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; background-color: #f4f4f5; padding: 20px;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
          <h2 style="color: #1E293B; text-align: center;">{t["title"]}</h2>
          <p style="color: #475569; font-size: 16px;">{t["greeting"]}</p>
          <p style="color: #475569; font-size: 16px;">{t["instruction"]}</p>
          <div style="text-align: center; margin: 30px 0;">
            <span style="display: inline-block; font-size: 32px; font-weight: bold; color: #00E676; background-color: #1E293B; padding: 10px 30px; border-radius: 8px; letter-spacing: 5px;">
              {otp_code}
            </span>
          </div>
          <p style="color: #475569; font-size: 14px;">{t["validity"]}</p>
          <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 30px 0;" />
          <p style="color: #94a3b8; font-size: 12px; text-align: center;">{t["team"]}</p>
        </div>
      </body>
    </html>
    """
    
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))

    # 4. 发送
    try:
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
            print(f"✅ 真实验证码 {otp_code} 已成功发送至 {to_email} ({lang})")
    except Exception as e:
        print(f"❌ 邮件发送失败: {e}")


async def send_register_otp_email(to_email: str, otp_code: str, lang: str = "en"):
    """
    异步发送注册验证码邮件（6位数字，5分钟有效）。
    """
    if not SMTP_USER or not SMTP_PASSWORD or not SMTP_SERVER:
        print("⚠️ 注册验证码发送失败：未配置 SMTP 环境变量。")
        return

    i18n = {
        "en": {
            "subject": "[EnerQuote] Your registration verification code",
            "title": "Complete your registration",
            "instruction": "Use this 6-digit code to finish creating your account:",
            "validity": "This code is valid for 5 minutes.",
        },
        "zh": {
            "subject": "[EnerQuote] 您的注册验证码",
            "title": "完成您的注册",
            "instruction": "请使用以下 6 位验证码完成注册：",
            "validity": "验证码 5 分钟内有效。",
        },
        "es": {
            "subject": "[EnerQuote] Tu codigo de verificacion de registro",
            "title": "Completa tu registro",
            "instruction": "Usa este codigo de 6 digitos para terminar de crear tu cuenta:",
            "validity": "Este codigo es valido por 5 minutos.",
        },
        "pt": {
            "subject": "[EnerQuote] Seu codigo de verificacao de cadastro",
            "title": "Conclua seu cadastro",
            "instruction": "Use este codigo de 6 digitos para concluir a criacao da conta:",
            "validity": "Este codigo e valido por 5 minutos.",
        },
    }
    t = i18n.get(lang, i18n["en"])

    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; background-color: #f4f4f5; padding: 20px;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 8px;">
          <h2 style="color: #1E293B; text-align: center;">{t["title"]}</h2>
          <p style="color: #475569; font-size: 16px;">{t["instruction"]}</p>
          <div style="text-align: center; margin: 24px 0;">
            <span style="display: inline-block; font-size: 32px; font-weight: bold; color: #00E676; background-color: #1E293B; padding: 10px 28px; border-radius: 8px; letter-spacing: 5px;">
              {otp_code}
            </span>
          </div>
          <p style="color: #475569; font-size: 14px;">{t["validity"]}</p>
          <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
          <p style="color: #94a3b8; font-size: 12px; text-align: center;">{SMTP_FROM_NAME}</p>
        </div>
      </body>
    </html>
    """

    message = EmailMessage()
    message["From"] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
    message["To"] = to_email
    message["Subject"] = t["subject"]
    message.set_content(f"{t['instruction']} {otp_code}. {t['validity']}")
    message.add_alternative(html_body, subtype="html")

    try:
        await aiosmtplib.send(
            message,
            hostname=SMTP_SERVER,
            port=SMTP_PORT,
            username=SMTP_USER,
            password=SMTP_PASSWORD,
            use_tls=not SMTP_USE_TLS,
            start_tls=SMTP_USE_TLS,
            timeout=20,
        )
    except Exception as e:
        print(f"❌ 注册验证码邮件发送失败: {e}")
        raise