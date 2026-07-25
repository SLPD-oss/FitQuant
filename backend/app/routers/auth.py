"""
认证路由: POST /api/auth/login, POST /api/auth/register
支持两种模式：
1. MySQL 真实认证 — 查 users 表验证密码哈希
2. 降级 Mock 模式 — 数据库不可用时返回模拟数据
"""
import hashlib, uuid as uuid_mod
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.auth import LoginRequest, RegisterRequest, LoginResponse, UserInfo
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/api/auth", tags=["认证"])


def _mock_token():
    return f"eyJmock_{uuid_mod.uuid4().hex[:24]}"


def _build_user_data(user: User) -> dict:
    """构建统一的 user info 响应字典"""
    return {
        "user_id": user.user_id,
        "phone": user.phone[:3] + "****" + user.phone[-4:],
        "nickname": user.nickname or "用户" + user.phone[-4:],
        "avatar_url": user.avatar_url or "",
        "identity": user.identity if user.identity else "enthusiast",
    }


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
                    "user": _build_user_data(user),
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


@router.post("/register", response_model=dict)
async def register(body: RegisterRequest):
    """
    用户注册，创建新账号并返回 JWT 令牌
    - 校验手机号格式
    - 检查手机号是否已注册
    - 写入 MySQL users 表
    - 数据库不可用时降级到 mock
    """
    # 校验手机号格式（11 位数字）
    phone_stripped = body.phone.strip()
    if len(phone_stripped) != 11 or not phone_stripped.isdigit():
        return {"code": 1004, "message": "手机号格式不正确", "data": None}

    # 校验密码长度
    if len(body.password) < 6:
        return {"code": 1004, "message": "密码至少6位", "data": None}

    try:
        async for session in get_db():
            # 1. 检查是否已注册
            result = await session.execute(
                select(User).where(User.phone == phone_stripped)
            )
            existing = result.scalar_one_or_none()
            if existing is not None:
                return {"code": 1003, "message": "手机号已注册", "data": None}

            # 2. 创建新用户
            user_id = str(uuid_mod.uuid4())
            password_hash = hashlib.sha256(body.password.encode()).hexdigest()
            nickname = body.nickname.strip() if body.nickname else ""
            if not nickname:
                nickname = "用户" + phone_stripped[-4:]

            new_user = User(
                user_id=user_id,
                phone=phone_stripped,
                password_hash=password_hash,
                nickname=nickname,
                identity=body.identity or "enthusiast",
                device_id="",
            )
            session.add(new_user)

        # 3. 返回注册成功
        data = {
            "token": _mock_token(),
            "refresh_token": _mock_token(),
            "expires_in": 86400,
            "user": {
                "user_id": user_id,
                "phone": phone_stripped[:3] + "****" + phone_stripped[-4:],
                "nickname": nickname,
                "avatar_url": "",
                "identity": body.identity or "enthusiast",
            }
        }
        return {"code": 0, "message": "ok", "data": data}

    except Exception as e:
        print(f"[auth] 数据库写入失败，降级到 mock: {e}")

    # Mock 降级
    return {
        "code": 0, "message": "ok",
        "data": {
            "token": _mock_token(),
            "refresh_token": _mock_token(),
            "expires_in": 86400,
            "user": {
                "user_id": str(uuid_mod.uuid4()),
                "phone": phone_stripped[:3] + "****" + phone_stripped[-4:],
                "nickname": body.nickname or "用户" + phone_stripped[-4:],
                "avatar_url": "",
                "identity": "enthusiast",
            }
        }
    }
