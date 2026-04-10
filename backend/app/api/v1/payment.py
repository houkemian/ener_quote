import html
import json
import logging
from datetime import datetime, timedelta
from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
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
from app.modules.iam.models import PaymentOrder, PaddleWebhookEvent
from app.services.paddle_signature import verify_paddle_signature
from fastapi.responses import HTMLResponse

logger = logging.getLogger(__name__)

router = APIRouter()

# /checkout-ui 页面文案（与 Flutter app 语言对齐：en / zh / es / pt）
_CHECKOUT_UI_I18N: dict[str, dict[str, str]] = {
    "en": {
        "html_lang": "en",
        "title": "Secure Checkout",
        "heading": "Connecting to secure payment…",
        "hint": "If the checkout does not open, check your network.",
    },
    "zh": {
        "html_lang": "zh-Hans",
        "title": "安全收银",
        "heading": "正在连接安全支付网关…",
        "hint": "若收银台未自动弹出，请检查网络连接。",
    },
    "es": {
        "html_lang": "es",
        "title": "Pago seguro",
        "heading": "Conectando al pago seguro…",
        "hint": "Si no aparece el checkout, comprueba tu conexión.",
    },
    "pt": {
        "html_lang": "pt-BR",
        "title": "Checkout seguro",
        "heading": "Conectando ao pagamento seguro…",
        "hint": "Se o checkout não abrir, verifique sua rede.",
    },
}


def _resolve_checkout_ui_lang(request: Request, lang: str | None) -> str:
    if lang:
        code = lang.strip().split("-")[0].lower()
        if code in _CHECKOUT_UI_I18N:
            return code
    accept = request.headers.get("accept-language") or ""
    for segment in accept.split(","):
        token = segment.strip().split(";")[0].strip()
        if not token:
            continue
        code = token.split("-")[0].lower()
        if code in _CHECKOUT_UI_I18N:
            return code
    return "en"


def _paddle_headers() -> dict[str, str]:
    if not PADDLE_API_KEY:
        raise HTTPException(status_code=500, detail="Paddle API key not configured")
    return {
        "Authorization": f"Bearer {PADDLE_API_KEY}",
        "Content-Type": "application/json",
    }


def _resolve_user_from_event(db: Session, data: dict[str, Any]) -> User | None:
    """Try resolve user by custom_data.user_id first, then customer email."""
    custom = data.get("custom_data") or {}
    user_id = custom.get("user_id")
    if user_id:
        user = db.query(User).filter(User.id == str(user_id)).first()
        if user:
            return user

    customer = data.get("customer") or {}
    customer_email = customer.get("email")
    if customer_email:
        return db.query(User).filter(User.email == str(customer_email)).first()

    return None


def _parse_event_datetime(raw_dt: Any) -> datetime | None:
    if not raw_dt or not isinstance(raw_dt, str):
        return None
    try:
        # Paddle 常见格式：2026-04-10T12:00:00Z
        return datetime.fromisoformat(raw_dt.replace("Z", "+00:00"))
    except ValueError:
        return None


def _extract_money_fields(data: dict[str, Any]) -> tuple[str | None, str | None]:
    details = data.get("details") or {}
    totals = details.get("totals") or {}

    currency = (
        totals.get("currency_code")
        or details.get("currency_code")
        or data.get("currency_code")
    )
    amount = (
        totals.get("grand_total")
        or totals.get("total")
        or details.get("amount")
        or data.get("amount")
    )
    return (
        str(currency) if currency is not None else None,
        str(amount) if amount is not None else None,
    )


def _create_order_if_absent(
    db: Session,
    *,
    user: User | None,
    event_id: str | None,
    event_type: str,
    status: str,
    data: dict[str, Any],
) -> bool:
    # 事件有 event_id 时，先做幂等去重
    if event_id:
        existed = (
            db.query(PaymentOrder)
            .filter(PaymentOrder.event_id == event_id)
            .first()
        )
        if existed:
            return False

    customer = data.get("customer") or {}
    occurred_at = _parse_event_datetime(data.get("occurred_at"))
    currency_code, amount = _extract_money_fields(data)

    order = PaymentOrder(
        user_id=user.id if user else None,
        event_id=event_id,
        event_type=event_type,
        status=status,
        transaction_id=data.get("id"),
        subscription_id=data.get("subscription_id") or data.get("subscription", {}).get("id"),
        customer_id=customer.get("id"),
        customer_email=customer.get("email"),
        currency_code=currency_code,
        amount=amount,
        occurred_at=occurred_at,
        raw_data=data,
    )
    db.add(order)
    return True


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
   
    # 与前端约定字段名保持不变，降低改动面asd


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

    logger.info("Paddle webhook path params: %s", request.path_params)
    logger.info("Paddle webhook request body: %s", raw)
    logger.info("Paddle webhook request headers: %s", request.headers)
    logger.info("Paddle webhook request query params: %s", request.query_params)

    if not PADDLE_WEBHOOK_SECRET:
        raise HTTPException(status_code=500, detail="Webhook secret not configured")

    raw_text = raw.decode("utf-8", errors="replace")
    webhook_event = PaddleWebhookEvent(
        signature_header=sig_header,
        signature_valid=False,
        process_status="received",
        request_headers=dict(request.headers),
        request_query=dict(request.query_params),
        request_path=str(request.url.path),
        raw_body=raw_text,
    )
    db.add(webhook_event)
    db.commit()
    db.refresh(webhook_event)

    try:
        event = json.loads(raw_text)
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        webhook_event.process_status = "invalid_json"
        webhook_event.error_message = str(e)
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid JSON body") from e

    event_type = event.get("event_type")
    data = event.get("data") or {}
    event_id = event.get("event_id")

    webhook_event.event_id = str(event_id) if event_id else None
    webhook_event.event_type = str(event_type) if event_type else None
    webhook_event.signature_valid = verify_paddle_signature(raw, sig_header, PADDLE_WEBHOOK_SECRET)

    if not webhook_event.signature_valid:
        webhook_event.process_status = "invalid_signature"
        webhook_event.error_message = "Paddle webhook signature verification failed"
        db.commit()
        logger.warning("Paddle webhook signature verification failed")
        raise HTTPException(status_code=400, detail="Invalid signature")

    if event_type == "transaction.completed":
        user = _resolve_user_from_event(db, data)
        _create_order_if_absent(
            db,
            user=user,
            event_id=str(event_id) if event_id else None,
            event_type=event_type,
            status="PAID",
            data=data,
        )
        if not user:
            webhook_event.process_status = "no_user"
            webhook_event.error_message = "transaction.completed user not found"
            db.commit()
            logger.warning(
                "transaction.completed cannot resolve user: txn=%s custom_data=%s customer=%s",
                data.get("id"),
                data.get("custom_data"),
                data.get("customer"),
            )
            return {"status": "no_user"}

        user.tier = "PRO"
        user.pro_expire_date = datetime.utcnow() + timedelta(days=30)
        webhook_event.process_status = "processed"
        db.commit()
        logger.info(
            "User %s upgraded to PRO via Paddle transaction.completed, expire_at=%s",
            user.email,
            user.pro_expire_date,
        )
        return {"status": "success", "event_type": event_type}

    if event_type == "subscription.renewed":
        user = _resolve_user_from_event(db, data)
        _create_order_if_absent(
            db,
            user=user,
            event_id=str(event_id) if event_id else None,
            event_type=event_type,
            status="PAID",
            data=data,
        )
        if not user:
            webhook_event.process_status = "no_user"
            webhook_event.error_message = "subscription.renewed user not found"
            db.commit()
            logger.warning(
                "subscription.renewed cannot resolve user: subscription=%s custom_data=%s customer=%s",
                data.get("id"),
                data.get("custom_data"),
                data.get("customer"),
            )
            return {"status": "no_user", "event_type": event_type}

        user.tier = "PRO"
        user.pro_expire_date = datetime.utcnow() + timedelta(days=30)
        webhook_event.process_status = "processed"
        db.commit()
        logger.info(
            "User %s renewed PRO via Paddle subscription.renewed, expire_at=%s",
            user.email,
            user.pro_expire_date,
        )
        return {"status": "success", "event_type": event_type}

    if event_type in {"subscription.canceled", "subscription.cancled", "subscription.past_due"}:
        user = _resolve_user_from_event(db, data)
        if not user:
            webhook_event.process_status = "no_user"
            webhook_event.error_message = f"{event_type} user not found"
            db.commit()
            logger.warning(
                "%s cannot resolve user: subscription=%s custom_data=%s customer=%s",
                event_type,
                data.get("id"),
                data.get("custom_data"),
                data.get("customer"),
            )
            return {"status": "no_user", "event_type": event_type}

        user.tier = "FREE"
        user.pro_expire_date = None
        webhook_event.process_status = "processed"
        db.commit()
        logger.info(
            "User %s downgraded to FREE via Paddle %s",
            user.email,
            event_type,
        )
        return {"status": "success", "event_type": event_type}

    webhook_event.process_status = "ignored"
    db.commit()
    return {"status": "ignored", "event_type": event_type}


@router.get("/checkout-ui")
def render_paddle_checkout_ui(
    request: Request,
    lang: str | None = Query(
        default=None,
        description="UI language: en, zh, es, pt (falls back to Accept-Language, then English)",
    ),
):
    """
    专门为 Flutter WebView 提供的 HTML 宿主页面。
    Paddle API 只要跳转到这里，Paddle.js 就会接管并自动弹窗！

    国际化：优先使用查询参数 ``lang``（如 ``?lang=zh``），否则根据 ``Accept-Language``，默认英文。
    """
    if not PADDLE_CLIENT_TOKEN:
        raise HTTPException(
            status_code=500,
            detail="PADDLE_CLIENT_TOKEN not configured (Paddle Dashboard client-side token)",
        )

    ui_lang = _resolve_checkout_ui_lang(request, lang)
    ui = _CHECKOUT_UI_I18N[ui_lang]
    html_lang = html.escape(ui["html_lang"])
    page_title = html.escape(ui["title"])
    heading = html.escape(ui["heading"])
    hint = html.escape(ui["hint"])

    js_env = paddle_js_environment()
    success_url = json.dumps(PADDLE_CHECKOUT_SUCCESS_REDIRECT_URL)
    closed_url = json.dumps(PADDLE_CHECKOUT_CLOSED_REDIRECT_URL)
    client_token = json.dumps(PADDLE_CLIENT_TOKEN)
    js_env_literal = json.dumps(js_env)

    html_content = f"""
    <!DOCTYPE html>
    <html lang="{html_lang}">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{page_title}</title>
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
            <h2>{heading}</h2>
            <p>{hint}</p>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)