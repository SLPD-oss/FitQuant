"""
认证路由: POST /api/auth/login
支持两种模式：
1. MySQL 真实认证 — 查 users 表验证密码哈希
2. 降级 Mock 模式 — 数据库不可用时返回模拟数据
"""
import hashlib, uuid as uuid_mod
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.auth import LoginRequest, LoginResponse, UserInfo
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/api/auth", tags=["认证"])


def _mock_token():
    return f"eyJmock_{uuid_mod.uuid4().hex[:24]}"


@router.post("/login", response_model=dict)
async def login(body: LoginRequest):
    """
    用户登录，返回 JWT 令牌
    - 优先查询 MySQL 用户表验证密码
    - 数据库不可用时降级到 mock 数据
    """
    # 1. 尝试 MySQL 真实认证
    try:
        async for session in get_db():
            result = await session.execute(
                select(User).where(User.phone == body.phone)
            )
            user = result.scalar_one_or_none()

        if user is not None:
            # 验证密码：SHA256
            input_hash = hashlib.sha256(body.password.encode()).hexdigest()
            if user.password_hash == input_hash:
                data = {
                    "token": _mock_token(),
                    "refresh_token": _mock_token(),
                    "expires_in": 86400,
                    "user": {
                        "user_id": user.user_id,
                        "phone": user.phone[:3] + "****" + user.phone[-4:],
                        "nickname": user.nickname,
                        "avatar_url": user.avatar_url,
                        "identity": user.identity if user.identity else "enthusiast",
                    }
                }
                return {"code": 0, "message": "ok", "data": data}
            else:
                return {"code": 1001, "message": "密码错误", "data": None}

        return {"code": 1002, "message": "用户不存在", "data": None}

    except Exception as e:
        print(f"[auth] 数据库查询失败，降级到 mock: {e}")

    # 2. Mock 降级（数据库不可用时）
    from app.services.mock import mock_login
    data = mock_login(body.phone, body.password, body.device_id)
    return {"code": 0, "message": "ok", "data": data}
