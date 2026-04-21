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
    REVENUECAT_WEBHOOK_AUTH,
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


def _resolve_user_from_app_user_id(db: Session, app_user_id: str) -> User | None:
    normalized = app_user_id.strip()
    if not normalized:
        return None
    user = db.query(User).filter(User.id == normalized).first()
    if user:
        return user
    return db.query(User).filter(User.email == normalized.lower()).first()


def _parse_revenuecat_expire(event: dict[str, Any]) -> datetime:
    expiration_ms = event.get("expiration_at_ms")
    if expiration_ms is not None:
        try:
            return datetime.utcfromtimestamp(int(expiration_ms) / 1000)
        except (TypeError, ValueError):
            pass

    expires_date = event.get("expires_date") or event.get("expiration_at")
    if isinstance(expires_date, str) and expires_date.strip():
        parsed = _parse_event_datetime(expires_date)
        if parsed:
            return parsed

    return datetime.utcnow() + timedelta(days=30)


def _parse_revenuecat_event_time(event: dict[str, Any]) -> datetime:
    event_ms = event.get("event_timestamp_ms")
    if event_ms is not None:
        try:
            return datetime.utcfromtimestamp(int(event_ms) / 1000)
        except (TypeError, ValueError):
            pass

    event_time = event.get("event_timestamp_at") or event.get("event_timestamp")
    if isinstance(event_time, str) and event_time.strip():
        parsed = _parse_event_datetime(event_time)
        if parsed:
            return parsed.replace(tzinfo=None) if parsed.tzinfo else parsed

    return datetime.utcnow()


def _record_revenuecat_event(
    db: Session,
    *,
    user: User,
    event: dict[str, Any],
    event_type: str,
) -> None:
    event_id_raw = event.get("id") or event.get("event_id")
    event_id = str(event_id_raw).strip() if event_id_raw else None
    if event_id:
        existed = db.query(PaymentOrder).filter(PaymentOrder.event_id == event_id).first()
        if existed:
            return

    occurred_at = _parse_revenuecat_event_time(event)
    status_map = {
        "INITIAL_PURCHASE": "PAID",
        "RENEWAL": "PAID",
        "BILLING_ISSUE": "BILLING_ISSUE",
        "CANCELLATION": "CANCELED",
        "EXPIRATION": "EXPIRED",
    }
    order = PaymentOrder(
        user_id=user.id,
        event_id=event_id,
        event_type=event_type,
        status=status_map.get(event_type, "INFO"),
        transaction_id=event.get("transaction_id"),
        subscription_id=event.get("original_transaction_id") or event.get("product_id"),
        customer_id=event.get("app_user_id"),
        customer_email=user.email,
        currency_code=event.get("currency"),
        amount=str(event.get("price")) if event.get("price") is not None else None,
        occurred_at=occurred_at,
        raw_data=event,
    )
    db.add(order)


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
        "Paddle create transaction request: endpoint=%s user_id=%s",
        "/transactions",
        current_user.user_id,
    )

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
            "Paddle create transaction failed: status=%s request_id=%s error_code=%s detail=%s",
            response.status_code,
            request_id,
            error_code,
            error_detail,
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

    logger.info(
        "Paddle webhook received: path=%s content_length=%s",
        request.url.path,
        len(raw),
    )

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
            "User upgraded to PRO via Paddle transaction.completed: user_id=%s expire_at=%s",
            user.id,
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
            "User renewed PRO via Paddle subscription.renewed: user_id=%s expire_at=%s",
            user.id,
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
            "User downgraded to FREE via Paddle %s: user_id=%s",
            event_type,
            user.id,
        )
        return {"status": "success", "event_type": event_type}

    webhook_event.process_status = "ignored"
    db.commit()
    return {"status": "ignored", "event_type": event_type}


@router.post("/webhook/revenuecat")
async def revenuecat_webhook(request: Request, db: Session = Depends(get_db)):
    """
    RevenueCat Webhook:
    - INITIAL_PURCHASE / RENEWAL => 用户升级 PRO
    - CANCELLATION / EXPIRATION => 用户降级 FREE
    """
    expected_auth = REVENUECAT_WEBHOOK_AUTH
    if expected_auth:
        auth_header = request.headers.get("authorization", "").strip()
        if auth_header != expected_auth:
            raise HTTPException(status_code=401, detail="Invalid RevenueCat webhook auth")

    payload = await request.json()
    event = payload.get("event") if isinstance(payload, dict) else None
    if not isinstance(event, dict):
        event = payload if isinstance(payload, dict) else {}

    event_type = str(event.get("type") or "").strip().upper()
    app_user_id = str(event.get("app_user_id") or "").strip()
    if not event_type or not app_user_id:
        raise HTTPException(status_code=400, detail="Missing event.type or event.app_user_id")

    user = _resolve_user_from_app_user_id(db, app_user_id)
    if not user:
        logger.warning(
            "RevenueCat webhook user not found: app_user_id=%s event_type=%s",
            app_user_id,
            event_type,
        )
        return {"status": "no_user", "event_type": event_type}

    _record_revenuecat_event(db, user=user, event=event, event_type=event_type)

    if event_type in {"INITIAL_PURCHASE", "RENEWAL"}:
        user.tier = "PRO"
        user.pro_expire_date = _parse_revenuecat_expire(event)
        db.commit()
        return {"status": "success", "event_type": event_type, "tier": "PRO"}

    if event_type == "BILLING_ISSUE":
        grace_end = _parse_revenuecat_event_time(event) + timedelta(days=3)
        current_expire = user.pro_expire_date or datetime.utcnow()
        user.tier = "PRO"
        user.pro_expire_date = max(current_expire, grace_end)
        db.commit()
        logger.warning(
            "RevenueCat BILLING_ISSUE: user_id=%s keep PRO grace until=%s",
            user.id,
            user.pro_expire_date,
        )
        return {
            "status": "success",
            "event_type": event_type,
            "tier": "PRO",
            "grace_until": user.pro_expire_date.isoformat() if user.pro_expire_date else None,
        }

    if event_type in {"CANCELLATION", "EXPIRATION"}:
        user.tier = "FREE"
        user.pro_expire_date = None
        db.commit()
        return {"status": "success", "event_type": event_type, "tier": "FREE"}

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