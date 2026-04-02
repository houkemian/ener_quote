import stripe
from fastapi import APIRouter, Depends, Request, HTTPException
from sqlalchemy.orm import Session
import json

# 🌟 1. 修复：引入真实的数据库入口和 JWT 安检门
from app.api.deps import get_db, get_current_user_payload, TokenPayload
# 🌟 2. 修复：精准引入 IAM 模块下真实在用的 User 模型
from app.modules.iam.models import User

from app.core.config import STRIPE_API_KEY, STRIPE_WEBHOOK_SECRET

router = APIRouter()

# 你的 Stripe 测试环境私钥

stripe.api_key = STRIPE_API_KEY

# 你的商品价格 ID
PRICE_ID = "price_1T5kUtCdfKFiLrNdLfYlkOgI"

@router.post("/checkout")
def create_checkout_session(current_user: TokenPayload = Depends(get_current_user_payload)): # 👈 修复为 TokenPayload
    """
    生成 Stripe 结账链接：前端点击“升级”按钮时调用此接口
    """
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price': PRICE_ID,
                'quantity': 1,
            }],
            mode='subscription', 
            success_url='https://dothings.one/docs', 
            cancel_url='https://dothings.one/docs',
            # 🌟 极其重要：把用户的真实 UUID 绑在订单上！
            client_reference_id=str(current_user.user_id), 
        )
        return {"checkout_url": session.url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    """
    Stripe 自动发货员 (安全校验版)
    """
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    
    # 🌟 将这里的 whsec_... 替换成你刚刚在 Stripe 后台复制的真实 Signing secret！

    endpoint_secret = STRIPE_WEBHOOK_SECRET 
    
    try:
        # 核心防伪校验：验证这通请求真的是 Stripe 发来的，而不是黑客伪造的
        event = stripe.Webhook.construct_event(
            payload, sig_header, endpoint_secret
        )
    except ValueError as e:
        print("❌ Webhook 报错：Payload 无效")
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError as e:
        print("❌ Webhook 报错：数字签名验证失败，可能是伪造请求！")
        raise HTTPException(status_code=400, detail="Invalid signature")

    # 当监听到“付款成功”事件时
    if event['type'] == 'checkout.session.completed':
        session_data = event['data']['object']
        
        # 拿回我们之前塞进去的用户 UUID
        user_id_str = session_data.get('client_reference_id')
        
        if user_id_str:
            user = db.query(User).filter(User.id == user_id_str).first()
            if user:
                # 🌟 自动提权！
                user.tier = "PRO"
                db.commit()
                print(f"==========================================")
                print(f"💰 叮咚！收银台响了！")
                print(f"👤 用户: {user.email}")
                print(f"👑 状态: 已成功自动升级为 PRO！")
                print(f"==========================================")

    return {"status": "success"}