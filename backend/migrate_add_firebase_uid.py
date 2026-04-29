from app.db.startup_migrations import ensure_firebase_uid_column
from app.db.database import engine


def main() -> None:
    column_created, _ = ensure_firebase_uid_column(engine)
    if column_created:
        print("Added column iam_users.firebase_uid")
    else:
        print("Column iam_users.firebase_uid already exists")
    print("Ensured unique index ix_iam_users_firebase_uid")


if __name__ == "__main__":
    main()
