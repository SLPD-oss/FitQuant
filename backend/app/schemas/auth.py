"""
认证模块 — 数据模型
对应 API: POST /api/auth/login, POST /api/auth/register
"""
from pydantic import BaseModel, Field
from typing import Optional


class LoginRequest(BaseModel):
    """用户登录请求体"""
    phone: str = Field(..., description="手机号", examples=["13800138000"])
    password: str = Field(..., description="密码")
    device_id: str = Field(..., description="设备标识", examples=["UUID"])


class RegisterRequest(BaseModel):
    """用户注册请求体"""
    phone: str = Field(..., description="手机号，11位数字", examples=["13800138000"])
    password: str = Field(..., description="密码，至少6位", examples=["123456"])
    nickname: Optional[str] = Field("", description="昵称（选填）", examples=["健身达人"])
    identity: Optional[str] = Field("enthusiast", description="用户身份", examples=["enthusiast"])


class UserInfo(BaseModel):
    """登录成功返回的用户信息"""
    user_id: str = Field(..., examples=["u_abc123"])
    phone: str = Field(..., examples=["138****8000"])
    nickname: str = Field(..., examples=["健身达人"])
    avatar_url: str = Field(..., examples=["https://cdn.xxx/avatars/u_abc123.png"])
    identity: str = Field(..., description="用户身份: beginner / enthusiast / coach", examples=["enthusiast"])


class LoginResponse(BaseModel):
    """登录成功响应体 data 字段"""
    token: str = Field(..., description="JWT 访问令牌")
    refresh_token: str = Field(..., description="刷新令牌（7 天有效期）")
    expires_in: int = Field(..., description="令牌有效期（秒）", examples=[86400])
    user: UserInfo
