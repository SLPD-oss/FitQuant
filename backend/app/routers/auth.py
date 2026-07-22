"""
认证路由: POST /api/auth/login
"""
from fastapi import APIRouter, HTTPException
from app.schemas.auth import LoginRequest, LoginResponse, UserInfo
from app.services.mock import mock_login

router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post("/login", response_model=dict)
async def login(body: LoginRequest):
    """用户登录，返回 JWT 令牌"""
    data = mock_login(body.phone, body.password, body.device_id)
    return {"code": 0, "message": "ok", "data": data}
