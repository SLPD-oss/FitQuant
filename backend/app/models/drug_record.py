"""
用药记录表 ORM 模型
"""
from sqlalchemy import Column, String, Float, DateTime, Integer, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class DrugRecord(Base):
    __tablename__ = "drug_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=False, index=True)
    drug_name = Column(String(100), nullable=False)
    category = Column(String(20), default="other")
    status = Column(String(20), default="viewing")
    dosage = Column(String(50), default="")
    unit = Column(String(20), default="mg")
    frequency = Column(String(50), default="")
    recorded_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
