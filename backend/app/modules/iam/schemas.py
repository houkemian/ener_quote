from pydantic import BaseModel, Field


class FirebaseIdTokenRequest(BaseModel):
    firebase_id_token: str = Field(
        ...,
        min_length=20,
        description="Firebase ID token issued by the client SDK.",
    )
