"""IAM router placeholder.

身份与访问管理（IAM）模块。账号注册、登录与密码重置已全面迁移到 Firebase
Authentication，仅由 ``app/api/v1/auth.py`` 中的 ``/auth/firebase`` 端点
负责把 Firebase ID token 同步到本地 ``iam_users`` 表。

本模块保留一个空 router 占位，便于未来挂载内部 IAM 管理类接口（例如
管理员封禁用户、批量导出账号清单等）。
"""

from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["IAM - 身份与访问管理"])
