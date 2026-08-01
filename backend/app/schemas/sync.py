from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class BodySyncRecord(BaseModel):
    recorded_at: str
    weight_kg: float
    body_fat_percent: float
    waist_cm: float
    height_cm: float = 0
    age: int = 0
    sex: str = ""
    chest_cm: float = 0
    neck_cm: float = 0
    hip_cm: float = 0
    activity_level: str = ""

class MealSyncRecord(BaseModel):
    recorded_at: str
    meal_type: str
    food_name: str = ""
    protein_g: float = 0
    fat_g: float = 0
    carbs_g: float = 0
    fiber_g: float = 0
    kcal: float = 0

class TrainingSyncRecord(BaseModel):
    recorded_at: str
    exercise_name: str
    training_type: str = "strength"
    sets: int = 0
    reps: int = 0
    weight_kg: float = 0
    duration_minutes: int = 0
    estimated_kcal: float = 0

class DrugSyncRecord(BaseModel):
    recorded_at: str
    drug_name: str
    category: str = "other"
    status: str = "viewing"
    dosage: str = ""
    unit: str = "mg"
    frequency: str = ""

class SupplementSyncRecord(BaseModel):
    recorded_at: str
    name: str
    dosage: str = ""
    unit: str = ""

class SleepSyncRecord(BaseModel):
    sleep_date: str
    total_sleep_hours: float = 0
    core_sleep_hours: float = 0
    deep_sleep_hours: float = 0
    rem_sleep_hours: float = 0
    awake_hours: float = 0
    resting_heart_rate: int = 0
    avg_hrv: int = 0
    source: str = "healthkit"
    recorded_at: str = ""

class SyncBatchRequest(BaseModel):
    sync_mode: str = Field(..., description="full / incremental")
    last_sync_at: Optional[str] = Field(None, description="增量同步时间戳")
    user_id: str = Field("", description="用户 UUID")
    body_data: list[BodySyncRecord] = []
    meal_records: list[MealSyncRecord] = []
    training_records: list[TrainingSyncRecord] = []
    drug_records: list[DrugSyncRecord] = []
    supplement_records: list[SupplementSyncRecord] = []
    sleep_records: list[SleepSyncRecord] = []

class SyncStats(BaseModel):
    body_records_uploaded: int
    meal_records_uploaded: int
    training_records_uploaded: int
    drug_records_uploaded: int
    supplement_records_uploaded: int

class SyncBatchResponse(BaseModel):
    sync_id: str
    synced_at: str
    stats: SyncStats
    conflicts: list = []
