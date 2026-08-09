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
    """饮食记录同步项"""
    # 【删除同步修复】客户端本地 id：后端优先按 (user_id, id) 匹配 upsert，
    # 保证前后端 id 一致，删除按 id 传播（与药物分支同一机制）
    record_id: str = ""
    recorded_at: str
    meal_type: str
    food_name: str = ""
    protein_g: float = 0
    fat_g: float = 0
    carbs_g: float = 0
    fiber_g: float = 0
    kcal: float = 0

class TrainingSyncRecord(BaseModel):
    """训练记录同步项"""
    # 【删除同步修复】客户端本地 id：后端优先按 (user_id, id) 匹配 upsert，
    # 保证前后端 id 一致，删除按 id 传播（与药物分支同一机制）
    record_id: str = ""
    recorded_at: str
    exercise_name: str
    training_type: str = "strength"
    sets: int = 0
    reps: int = 0
    weight_kg: float = 0
    duration_minutes: int = 0
    estimated_kcal: float = 0

class DrugSyncRecord(BaseModel):
    """用药记录同步项"""
    # 【重复记录修复】客户端本地 id：后端优先按 (user_id, id) 匹配 upsert，
    # 保证前后端 id 一致，合并时按 id 命中，避免「切页返回出现两条相同记录」
    record_id: str = ""
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

class DeletedDrugRecord(BaseModel):
    """待删除的用药记录：优先按 record_id（后端行 ID）删除，缺失时按幂等键 (drug_name, recorded_at) 兜底"""
    record_id: str = ""
    drug_name: str = ""
    recorded_at: str = ""

class DeletedMealRecord(BaseModel):
    """待删除的饮食记录：优先按 record_id（后端行 ID）删除，缺失时按幂等键 (meal_type, food_name, recorded_at) 兜底"""
    record_id: str = ""
    meal_type: str = ""
    food_name: str = ""
    recorded_at: str = ""

class DeletedTrainingRecord(BaseModel):
    """待删除的训练记录：优先按 record_id（后端行 ID）删除，缺失时按幂等键 (exercise_name, recorded_at) 兜底"""
    record_id: str = ""
    exercise_name: str = ""
    recorded_at: str = ""

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
    deleted_drug_records: list[DeletedDrugRecord] = []
    # 【删除同步修复】饮食/训练删除传播：前端把待删除记录的 ID 或幂等键随包上传，
    # 后端先删后插，避免被删记录在切页重新拉取后「复活」
    deleted_meal_records: list[DeletedMealRecord] = []
    deleted_training_records: list[DeletedTrainingRecord] = []
    # 【删除同步修复】显式清空标记：前端「一键删除所有药物」时传 true，
    # 后端无条件删除该用户全部用药记录，不依赖墓碑 id 匹配（墓碑机制对历史膨胀数据失效）
    clear_all_drugs: bool = False
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
