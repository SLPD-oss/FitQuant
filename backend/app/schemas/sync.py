from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class BodySyncRecord(BaseModel):
    recorded_at: str
    weight_kg: float
    body_fat_percent: float
    waist_cm: float

class MealSyncRecord(BaseModel):
    recorded_at: str
    meal_type: str
    protein_g: float
    fat_g: float
    carbs_g: float
    kcal: float

class TrainingSyncRecord(BaseModel):
    recorded_at: str
    exercise_name: str
    sets: int
    reps: int
    weight_kg: float

class DrugSyncRecord(BaseModel):
    recorded_at: str
    drug_name: str
    status: str

class SupplementSyncRecord(BaseModel):
    recorded_at: str
    name: str
    dosage: str
    unit: str

class SyncBatchRequest(BaseModel):
    sync_mode: str = Field(..., description="full / incremental")
    last_sync_at: Optional[str] = Field(None, description="增量同步时间戳")
    body_data: list[BodySyncRecord] = []
    meal_records: list[MealSyncRecord] = []
    training_records: list[TrainingSyncRecord] = []
    drug_records: list[DrugSyncRecord] = []
    supplement_records: list[SupplementSyncRecord] = []

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
