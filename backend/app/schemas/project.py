from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class ProjectCreateRequest(BaseModel):
    project_name: str = Field(min_length=1, max_length=200)
    client_name: str | None = Field(default=None, max_length=200)
    location: str | None = Field(default=None, max_length=255)


class ProjectUpdateRequest(BaseModel):
    project_name: str | None = Field(default=None, min_length=1, max_length=200)
    client_name: str | None = Field(default=None, max_length=200)
    location: str | None = Field(default=None, max_length=255)


class ProjectResponse(BaseModel):
    id: UUID
    user_id: str
    project_name: str
    client_name: str | None
    location: str | None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ProjectCalculationCreateRequest(BaseModel):
    version_name: str = Field(min_length=1, max_length=120)
    parameters: dict[str, Any]
    results: dict[str, Any]


class ProjectCalculationResponse(BaseModel):
    id: UUID
    project_id: UUID
    version_name: str
    parameters: dict[str, Any]
    results: dict[str, Any]
    created_at: datetime

    class Config:
        from_attributes = True
