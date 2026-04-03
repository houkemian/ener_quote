"""
Paddle Billing webhook signature verification (manual implementation).

Docs: https://developer.paddle.com/webhooks/signature-verification

Signed payload: ``{ts}:`` + raw request body (bytes, unchanged).
HMAC-SHA256 using the notification destination secret key; compare to ``h1`` (hex).
"""

from __future__ import annotations

import hmac
import hashlib
import time
from typing import Optional


def _parse_paddle_signature_header(header: str) -> tuple[Optional[str], list[str]]:
    """Parse ``Paddle-Signature: ts=...;h1=...`` (supports multiple ``h1`` during rotation)."""
    ts: Optional[str] = None
    h1_values: list[str] = []
    for part in header.split(";"):
        part = part.strip()
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        key, value = key.strip(), value.strip()
        if key == "ts":
            ts = value
        elif key == "h1":
            h1_values.append(value)
    return ts, h1_values


def verify_paddle_signature(
    raw_body: bytes,
    paddle_signature_header: Optional[str],
    secret_key: str,
    *,
    max_age_seconds: int = 3600,
) -> bool:
    """
    Verify the ``Paddle-Signature`` header for a raw webhook body.

    :param raw_body: Exact bytes received (do not re-serialize JSON).
    :param paddle_signature_header: Value of ``Paddle-Signature`` (or None).
    :param secret_key: Notification destination secret (``endpoint_secret_key``).
    :param max_age_seconds: Reject if ``ts`` is older/newer than this (replay / clock skew).
    """
    if not secret_key or not paddle_signature_header:
        return False

    ts_str, expected_hex_list = _parse_paddle_signature_header(paddle_signature_header)
    if not ts_str or not expected_hex_list:
        return False

    try:
        ts_int = int(ts_str)
    except ValueError:
        return False

    now = int(time.time())
    if abs(now - ts_int) > max_age_seconds:
        return False

    signed_content = f"{ts_str}:".encode("utf-8") + raw_body
    computed = hmac.new(
        secret_key.encode("utf-8"),
        signed_content,
        hashlib.sha256,
    ).hexdigest()

    return any(hmac.compare_digest(computed, exp) for exp in expected_hex_list)
