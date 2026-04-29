from __future__ import annotations

from typing import Any

from google.auth.transport import requests
from google.oauth2 import id_token

from app.core.config import FIREBASE_PROJECT_ID


_request = requests.Request()


def verify_firebase_id_token(token: str) -> dict[str, Any]:
    raw = token.strip()
    if not raw:
        raise ValueError("Firebase token is empty")
    if not FIREBASE_PROJECT_ID:
        raise ValueError("FIREBASE_PROJECT_ID is not configured")
    try:
        claims = id_token.verify_firebase_token(raw, _request, audience=FIREBASE_PROJECT_ID)
    except Exception as exc:  # noqa: BLE001
        raise ValueError(f"Invalid Firebase token: {exc}") from exc
    if not claims:
        raise ValueError("Firebase token verification returned empty claims")
    if claims.get("aud") != FIREBASE_PROJECT_ID:
        raise ValueError("Firebase token audience mismatch")
    return claims
