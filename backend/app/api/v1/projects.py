from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import TokenPayload, get_current_user_payload, get_db
from app.models.project import Project, ProjectCalculation
from app.schemas.project import (
    ProjectCalculationCreateRequest,
    ProjectCalculationResponse,
    ProjectCreateRequest,
    ProjectResponse,
)

router = APIRouter(prefix="/projects", tags=["Project Management"])


def _get_user_project_or_404(db: Session, project_id: UUID, user_id: str) -> Project:
    project = (
        db.query(Project)
        .filter(Project.id == project_id, Project.user_id == user_id)
        .first()
    )
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


@router.get("", response_model=list[ProjectResponse])
def list_projects(
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    return (
        db.query(Project)
        .filter(Project.user_id == current_user.user_id)
        .order_by(Project.created_at.desc())
        .all()
    )


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(
    payload: ProjectCreateRequest,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    project = Project(
        user_id=current_user.user_id,
        project_name=payload.project_name.strip(),
        client_name=payload.client_name.strip() if payload.client_name else None,
        location=payload.location.strip() if payload.location else None,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.get(
    "/{project_id}/calculations",
    response_model=list[ProjectCalculationResponse],
)
def list_project_calculations(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    _get_user_project_or_404(db, project_id, current_user.user_id)
    return (
        db.query(ProjectCalculation)
        .filter(ProjectCalculation.project_id == project_id)
        .order_by(ProjectCalculation.created_at.desc())
        .all()
    )


@router.post(
    "/{project_id}/calculations",
    response_model=ProjectCalculationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_project_calculation(
    project_id: UUID,
    payload: ProjectCalculationCreateRequest,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    _get_user_project_or_404(db, project_id, current_user.user_id)
    version_name = payload.version_name.strip()
    if not version_name:
        raise HTTPException(status_code=422, detail="version_name cannot be empty")

    existing = (
        db.query(ProjectCalculation)
        .filter(
            ProjectCalculation.project_id == project_id,
            ProjectCalculation.version_name == version_name,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=409,
            detail="A calculation with the same version_name already exists in this project",
        )

    calc = ProjectCalculation(
        project_id=project_id,
        version_name=version_name,
        parameters=payload.parameters,
        results=payload.results,
    )
    db.add(calc)
    db.commit()
    db.refresh(calc)
    return calc
