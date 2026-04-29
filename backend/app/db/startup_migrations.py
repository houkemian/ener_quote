from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_firebase_uid_column(engine: Engine) -> tuple[bool, bool]:
    """
    Returns:
      (column_created, index_ensured)
    """
    inspector = inspect(engine)
    columns = {col["name"] for col in inspector.get_columns("iam_users")}

    column_created = False
    with engine.begin() as conn:
        if "firebase_uid" not in columns:
            conn.execute(text("ALTER TABLE iam_users ADD COLUMN firebase_uid VARCHAR(255)"))
            column_created = True

        conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_iam_users_firebase_uid "
                "ON iam_users(firebase_uid)"
            )
        )
    return column_created, True
