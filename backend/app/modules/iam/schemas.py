from pydantic import BaseModel, Field


class FirebaseIdTokenRequest(BaseModel):
    firebase_id_token: str = Field(
        ...,
        min_length=20,
        description="Firebase ID token issued by the client SDK.",
    )


class DevLoginRequest(BaseModel):
    email: str = Field(default="gavinhkm@gmail.com")
    firebase_uid: str = Field(default="fb54a649-2adf-4ad1-b0cb-e5b1f46dd940")
    tier: str = Field(default="PRO")
    pro_expire_date: str = Field(default="2026-09-01")
    is_active: bool = Field(default=True)
