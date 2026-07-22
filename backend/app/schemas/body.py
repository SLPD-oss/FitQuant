from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class BodyDataUploadRequest(BaseModel):
    height_cm: float = Field(..., description="身高（厘米）", examples=[170])
    weight_kg: float = Field(..., description="体重（千克）", examples=[70.5])
    age: int = Field(..., description="年龄", examples=[25])
    sex: str = Field(..., description="性别: male / female", examples=["male"])
    chest_cm: float = Field(..., description="胸围（厘米）", examples=[92])
    waist_cm: float = Field(..., description="腰围（厘米）", examples=[78])
    neck_cm: float = Field(..., description="颈围（厘米）", examples=[38])
    hip_cm: float = Field(..., description="臀围（厘米）", examples=[90])
    body_fat_percent: float = Field(..., description="体脂率（%）", examples=[20.0])
    activity_level: str = Field(..., description="活动水平", examples=["moderate"])
    recorded_at: datetime = Field(..., description="测量时间")

class BodyDataUploadResponse(BaseModel):
    record_id: str = Field(..., examples=["body_rec_001"])
    created_at: datetime

class BodyHistoryRecord(BaseModel):
    recorded_at: str = Field(..., examples=["2026-07-01"])
    weight_kg: float
    body_fat_percent: float

class BodyTrend(BaseModel):
    weight_change_kg: float
    body_fat_change_pct: float

class BodyHistoryResponse(BaseModel):
    records: List[BodyHistoryRecord]
    trend: BodyTrend
