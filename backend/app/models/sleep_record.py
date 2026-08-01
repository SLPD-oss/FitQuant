"""
睡眠记录表 ORM 模型
每夜 1 条（user_id + sleep_date 唯一）。
recovery_score / consecutive_low_score_days 为派生指标，由后端算法实时计算，不落库。
"""
from sqlalchemy import Column, String, Float, Integer, Date, DateTime, func
from sqlalchemy.dialects.mysql import CHAR
import uuid
from app.database import Base


class SleepRecord(Base):
    __tablename__ = "sleep_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=False, index=True)
    sleep_date = Column(Date, nullable=False)
    total_sleep_hours = Column(Float, default=0)
    core_sleep_hours = Column(Float, default=0)
    deep_sleep_hours = Column(Float, default=0)
    rem_sleep_hours = Column(Float, default=0)
    awake_hours = Column(Float, default=0)
    resting_heart_rate = Column(Integer, default=0)
    avg_hrv = Column(Integer, default=0)
    source = Column(String(20), default="healthkit")
    recorded_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
