"""
饮食记录表 ORM 模型
"""
from sqlalchemy import Column, String, Float, DateTime, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class MealRecord(Base):
    __tablename__ = "meal_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=False, index=True)
    food_name = Column(String(100), nullable=False)
    meal_type = Column(String(20), nullable=False)
    protein_g = Column(Float, default=0)
    fat_g = Column(Float, default=0)
    carbs_g = Column(Float, default=0)
    fiber_g = Column(Float, default=0)
    kcal = Column(Float, default=0)
    recorded_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
