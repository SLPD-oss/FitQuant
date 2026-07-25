"""
训练记录表 ORM 模型
"""
from sqlalchemy import Column, String, Float, Integer, DateTime, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class TrainingRecord(Base):
    __tablename__ = "training_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=False, index=True)
    exercise_name = Column(String(100), nullable=False)
    training_type = Column(String(20), nullable=False)
    sets = Column(Integer, default=0)
    reps = Column(Integer, default=0)
    weight_kg = Column(Float, default=0)
    duration_minutes = Column(Integer, default=0)
    estimated_kcal = Column(Float, default=0)
    recorded_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
