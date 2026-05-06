from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import TokenPayload, get_current_user_payload, get_db
from app.models.project import Project, ProjectCalculation
from app.services.parameter_cleaner import clean_project_parameters
from app.services.pvgis import fetch_pvgis_hourly_irradiance
from app.services.result_optimizer import optimize_results_for_db
from app.schemas.project import (
    ProjectCalculationCreateRequest,
    ProjectCalculationResponse,
    ProjectCreateRequest,
    ProjectResponse,
    ProjectUpdateRequest,
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


@router.patch("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: UUID,
    payload: ProjectUpdateRequest,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    project = _get_user_project_or_404(db, project_id, current_user.user_id)

    updates = 0
    if payload.project_name is not None:
        project_name = payload.project_name.strip()
        if not project_name:
            raise HTTPException(status_code=422, detail="project_name cannot be empty")
        project.project_name = project_name
        updates += 1
    if payload.client_name is not None:
        project.client_name = payload.client_name.strip() if payload.client_name.strip() else None
        updates += 1
    if payload.location is not None:
        project.location = payload.location.strip() if payload.location.strip() else None
        updates += 1

    if updates == 0:
        raise HTTPException(status_code=422, detail="No updatable fields provided")

    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.get(
    "/{project_id}/calculations",
    response_model=list[ProjectCalculationResponse],
)
async def list_project_calculations(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    _get_user_project_or_404(db, project_id, current_user.user_id)
    calculations = (
        db.query(ProjectCalculation)
        .filter(ProjectCalculation.project_id == project_id)
        .order_by(ProjectCalculation.created_at.desc())
        .all()
    )
    await _hydrate_irradiance_for_history(calculations)
    return calculations


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

    cleaned_parameters = clean_project_parameters(payload.parameters)

    optimized_results = optimize_results_for_db(payload.results)

    calc = ProjectCalculation(
        project_id=project_id,
        version_name=version_name,
        parameters=cleaned_parameters,
        results=optimized_results,
    )
    db.add(calc)
    db.commit()
    db.refresh(calc)
    return calc


@router.delete(
    "/{project_id}/calculations/{calculation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_project_calculation(
    project_id: UUID,
    calculation_id: UUID,
    db: Session = Depends(get_db),
    current_user: TokenPayload = Depends(get_current_user_payload),
):
    _get_user_project_or_404(db, project_id, current_user.user_id)
    calc = (
        db.query(ProjectCalculation)
        .filter(
            ProjectCalculation.id == calculation_id,
            ProjectCalculation.project_id == project_id,
        )
        .first()
    )
    if not calc:
        raise HTTPException(status_code=404, detail="Calculation not found")
    db.delete(calc)
    db.commit()


async def _hydrate_irradiance_for_history(calculations: list[ProjectCalculation]) -> None:
    """Fill missing irradiance_8760 using saved lat/lon for read-time compatibility."""
    cache: dict[tuple[float, float], list[float]] = {}
    for calc in calculations:
        parameters = calc.parameters if isinstance(calc.parameters, dict) else None
        if parameters is None:
            continue

        physics = parameters.get("physics_params")
        if not isinstance(physics, dict):
            continue
        env = physics.get("env")
        if not isinstance(env, dict):
            continue
        if env.get("irradiance_8760"):
            continue

        lat = env.get("lat")
        lon = env.get("lon")
        if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
            continue
        if lat == 0.0 and lon == 0.0:
            continue

        key = (float(lat), float(lon))
        if key not in cache:
            try:
                cache[key] = await fetch_pvgis_hourly_irradiance(lat=key[0], lon=key[1])
            except Exception:
                continue
        env["irradiance_8760"] = cache[key]
