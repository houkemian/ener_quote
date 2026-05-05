import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from app.db.database import Base


class Project(Base):
    __tablename__ = "projects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, ForeignKey("iam_users.id"), nullable=False, index=True)
    project_name = Column(String(200), nullable=False)
    client_name = Column(String(200), nullable=True)
    location = Column(String(255), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    calculations = relationship(
        "ProjectCalculation",
        back_populates="project",
        cascade="all, delete-orphan",
        order_by="desc(ProjectCalculation.created_at)",
    )


class ProjectCalculation(Base):
    __tablename__ = "project_calculations"
    __table_args__ = (
        UniqueConstraint("project_id", "version_name", name="uq_project_calc_project_version"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(
        UUID(as_uuid=True),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version_name = Column(String(120), nullable=False)
    parameters = Column(JSONB, nullable=False)
    results = Column(JSONB, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    project = relationship("Project", back_populates="calculations")
