"""
Verify OAuth ID tokens from Google and Microsoft (Azure AD / personal accounts).

Used by POST /api/v1/auth/oauth/google and .../oauth/microsoft.
"""
from __future__ import annotations

import logging
import os
from typing import Any

import httpx
import jwt
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from jwt import PyJWKClient

logger = logging.getLogger(__name__)


def _google_client_ids() -> list[str]:
    raw = os.getenv("GOOGLE_OAUTH_CLIENT_IDS", "").strip()
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


def verify_google_id_token(raw_token: str) -> dict[str, Any]:
    audiences = _google_client_ids()
    if not audiences:
        raise ValueError("GOOGLE_OAUTH_CLIENT_IDS is not configured")

    request = google_requests.Request()
    last_err: Exception | None = None
    for aud in audiences:
        try:
            info = google_id_token.verify_oauth2_token(
                raw_token,
                request,
                audience=aud,
            )
            if not info.get("email"):
                raise ValueError("Google token missing email claim")
            return dict(info)
        except Exception as e:  # noqa: BLE001 — try next audience
            last_err = e
            continue
    raise ValueError(f"Invalid Google ID token: {last_err}")


def _microsoft_client_id() -> str:
    cid = os.getenv("MICROSOFT_OAUTH_CLIENT_ID", "").strip()
    if not cid:
        raise ValueError("MICROSOFT_OAUTH_CLIENT_ID is not configured")
    return cid


def verify_microsoft_id_token(raw_token: str) -> dict[str, Any]:
    """
    Validate Azure AD v2.0 ID token (common / multitenant or single tenant).
    """
    _ = _microsoft_client_id()

    # Decode header to locate signing key (kid)
    unverified_header = jwt.get_unverified_header(raw_token)
    if unverified_header.get("alg") != "RS256":
        raise ValueError("Unsupported Microsoft token algorithm")

    oidc_url = (
        "https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration"
    )
    try:
        with httpx.Client(timeout=15.0) as client:
            oidc = client.get(oidc_url).json()
            jwks_uri = oidc["jwks_uri"]
    except Exception as e:  # noqa: BLE001
        logger.exception("Failed to load Microsoft OIDC metadata")
        raise ValueError("Microsoft OIDC discovery failed") from e

    jwk_client = PyJWKClient(jwks_uri)
    signing_key = jwk_client.get_signing_key_from_jwt(raw_token)

    unverified_payload = jwt.decode(
        raw_token,
        options={"verify_signature": False},
    )
    issuer = unverified_payload.get("iss")
    if not issuer or not str(issuer).startswith("https://login.microsoftonline.com/"):
        raise ValueError("Invalid Microsoft token issuer")

    audience = _microsoft_client_id()
    decoded = jwt.decode(
        raw_token,
        signing_key.key,
        algorithms=["RS256"],
        audience=audience,
        issuer=issuer,
        options={"verify_aud": True},
    )

    # Email: v2 tokens may use email, preferred_username, or upn
    email = (
        decoded.get("email")
        or decoded.get("preferred_username")
        or decoded.get("upn")
    )
    if not email or not isinstance(email, str):
        raise ValueError("Microsoft token missing email-like claim")

    sub = decoded.get("sub")
    if not sub:
        raise ValueError("Microsoft token missing sub")

    out = dict(decoded)
    out["email"] = email.strip().lower()
    out["sub"] = str(sub)
    return out
