import json
import logging
from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user_payload, TokenPayload
from app.core.config import (
    PADDLE_API_KEY,
    PADDLE_CHECKOUT_CLOSED_REDIRECT_URL,
    PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL,
    PADDLE_CLIENT_TOKEN,
    PADDLE_PRICE_ID,
    PADDLE_WEBHOOK_SECRET,
    paddle_api_base_url,
    paddle_js_environment,
)
from app.modules.iam.models import User
from app.services.paddle_signature import verify_paddle_signature
from fastapi.responses import HTMLResponse

logger = logging.getLogger(__name__)

router = APIRouter()


def _paddle_headers() -> dict[str, str]:
    if not PADDLE_API_KEY:
        raise HTTPException(status_code=500, detail="Paddle API key not configured")
    return {
        "Authorization": f"Bearer {PADDLE_API_KEY}",
        "Content-Type": "application/json",
    }


@router.post("/checkout")
def create_checkout_session(
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    """
    创建 Paddle Billing 结账交易并返回 ``checkout.url``（托管收银台链接）。
    将当前用户 UUID 写入 ``custom_data.user_id``，供 Webhook 提权使用。
    """
    if not PADDLE_PRICE_ID:
        raise HTTPException(status_code=500, detail="PADDLE_PRICE_ID not configured")

    base = paddle_api_base_url()
    request_url = f"{base}/transactions"
    payload: dict[str, Any] = {
        "items": [{"price_id": PADDLE_PRICE_ID, "quantity": 1}],
        "collection_mode": "automatic",
        "custom_data": {"user_id": str(current_user.user_id)},
    }
    logger.info(
        "Paddle create transaction request: base=%s endpoint=%s payload=%s",
        base,
        "/transactions",
        payload,
    )
    logger.info("Paddle final request URL: %s", request_url)

    try:
        with httpx.Client(timeout=30.0) as client:
            response = client.post(
                request_url,
                headers=_paddle_headers(),
                json=payload,
            )
    except httpx.RequestError as e:
        logger.exception("Paddle API request failed: %s", e)
        raise HTTPException(status_code=502, detail="Paddle API unreachable") from e

    if response.status_code not in (200, 201):
        logger.warning("Paddle raw response text: %s", response.text)
        parsed_error: dict[str, Any] = {}
        request_id: str | None = None
        error_code: str | None = None
        error_detail: str | None = None
        if "application/json" in response.headers.get("content-type", ""):
            try:
                body = response.json()
                parsed_error = body.get("error") or {}
                request_id = (body.get("meta") or {}).get("request_id")
                error_code = parsed_error.get("code")
                error_detail = parsed_error.get("detail") or parsed_error.get("message")
            except Exception:
                pass

        logger.warning(
            "Paddle create transaction failed: status=%s request_id=%s error_code=%s detail=%s raw=%s",
            response.status_code,
            request_id,
            error_code,
            error_detail,
            response.text[:2000],
        )

        if error_code == "transaction_default_checkout_url_not_set":
            logger.error(
                "Paddle dashboard missing Default Payment Link. Please set it in Checkout settings: "
                "https://developer.paddle.com/v1/errors/transactions/transaction_default_checkout_url_not_set"
            )

        detail: str
        if parsed_error:
            detail = str(
                parsed_error.get("detail")
                or parsed_error.get("message")
                or response.text[:800]
            )
        else:
            detail = response.text[:800]
        raise HTTPException(status_code=400, detail=detail)

    logger.info("Paddle success raw response text: %s", response.text)
    body = response.json()
    data = body.get("data") or {}
    checkout = data.get("checkout") or {}
    url = checkout.get("url")
    if not url:
        logger.warning("Paddle response missing checkout.url: %s", body)
        raise HTTPException(
            status_code=502,
            detail="Paddle did not return checkout.url; check catalog price and default payment link in Paddle.",
        )

    # 防御性校验：如果返回的是你自己的回跳域名（仅带 _ptxn），说明 Paddle Default Payment Link 配错了，
    # 当前 URL 不是托管收银台地址，前端会被立即拦截并关闭 WebView。
    if url.startswith("https://api.dothings.one") and "_ptxn=" in url:
        logger.error(
            "Paddle checkout.url is misconfigured Default Payment Link, got callback-like url: %s",
            url,
        )
        raise HTTPException(
            status_code=500,
            detail=(
                "Paddle Default Payment Link is misconfigured. "
                "Please set it to a Paddle-hosted checkout link in Paddle Dashboard, "
                "not the callback domain (https://api.dothings.one)."
            ),
        )

    # 与前端约定字段名保持不变，降低改动面
    return {"checkout_url": url}


@router.post("/webhook")
async def paddle_webhook(request: Request, db: Session = Depends(get_db)):
    """
    Paddle Billing Webhook：校验 ``Paddle-Signature`` 后处理 ``transaction.completed``，
    将 ``custom_data.user_id`` 对应用户 ``tier`` 设为 PRO。
    """
    raw = await request.body()
    sig_header = request.headers.get("paddle-signature") or request.headers.get(
        "Paddle-Signature"
    )

    if not PADDLE_WEBHOOK_SECRET:
        raise HTTPException(status_code=500, detail="Webhook secret not configured")

    if not verify_paddle_signature(raw, sig_header, PADDLE_WEBHOOK_SECRET):
        logger.warning("Paddle webhook signature verification failed")
        raise HTTPException(status_code=400, detail="Invalid signature")

    try:
        event = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=400, detail="Invalid JSON body") from e

    event_type = event.get("event_type")
    if event_type != "transaction.completed":
        return {"status": "ignored", "event_type": event_type}

    data = event.get("data") or {}
    custom = data.get("custom_data") or {}
    user_id_str = custom.get("user_id")
    if not user_id_str:
        logger.warning(
            "transaction.completed without custom_data.user_id: txn=%s",
            data.get("id"),
        )
        return {"status": "no_user_id"}

    user = db.query(User).filter(User.id == user_id_str).first()
    if user:
        user.tier = "PRO"
        db.commit()
        logger.info("User %s upgraded to PRO via Paddle transaction.completed", user.email)
    else:
        logger.warning("Paddle webhook: user_id not found: %s", user_id_str)

    return {"status": "success"}


@router.get("/checkout-ui")
def render_paddle_checkout_ui():
    """
    专门为 Flutter WebView 提供的 HTML 宿主页面。
    Paddle API 只要跳转到这里，Paddle.js 就会接管并自动弹窗！
    """
    if not PADDLE_CLIENT_TOKEN:
        raise HTTPException(
            status_code=500,
            detail="PADDLE_CLIENT_TOKEN not configured (Paddle Dashboard client-side token)",
        )

    js_env = paddle_js_environment()
    success_url = json.dumps(PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL)
    closed_url = json.dumps(PADDLE_CHECKOUT_CLOSED_REDIRECT_URL)
    client_token = json.dumps(PADDLE_CLIENT_TOKEN)
    js_env_literal = json.dumps(js_env)

    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Secure Checkout</title>
        <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
        <script>
            Paddle.Environment.set({js_env_literal});
            Paddle.Initialize({{
                token: {client_token},
                eventCallback: function(data) {{
                    if (data.name === "checkout.completed") {{
                        window.location.href = {success_url};
                    }}
                    if (data.name === "checkout.closed") {{
                        window.location.href = {closed_url};
                    }}
                }}
            }});
        </script>
    </head>
    <body style="background-color: #f4f5f7; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; font-family: sans-serif;">
        <div style="text-align: center; color: #666;">
            <h2>正在安全连接支付网关...</h2>
            <p>如果收银台没有自动弹出，请检查网络。</p>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)