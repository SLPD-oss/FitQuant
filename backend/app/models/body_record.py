"""
身体数据记录表 ORM 模型
"""
from sqlalchemy import Column, String, Float, Integer, DateTime, Enum, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class BodyRecord(Base):
    __tablename__ = "body_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=False, index=True)
    height_cm = Column(Float, nullable=False)
    weight_kg = Column(Float, nullable=False)
    age = Column(Integer, nullable=False)
    sex = Column(Enum("male", "female"), nullable=False)
    chest_cm = Column(Float, default=0)
    waist_cm = Column(Float, default=0)
    neck_cm = Column(Float, default=0)
    hip_cm = Column(Float, default=0)
    body_fat_percent = Column(Float, default=0)
    activity_level = Column(String(20), default="moderate")
    recorded_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
