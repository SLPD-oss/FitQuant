"""
用户表 ORM 模型
"""
from sqlalchemy import Column, String, DateTime, Enum, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    phone = Column(String(20), unique=True, nullable=False, index=True)
    password_hash = Column(String(128), nullable=False)
    nickname = Column(String(50), default="")
    avatar_url = Column(String(256), default="")
    identity = Column(Enum("beginner", "enthusiast", "coach"), default="enthusiast")
    device_id = Column(String(64), default="")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
