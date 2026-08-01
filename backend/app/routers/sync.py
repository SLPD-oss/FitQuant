"""
数据同步路由: POST /api/sync/batch
支持两种模式：
1. MySQL 真实写入 — 批量写入 body_records/meal_records/training_records/drug_records
2. 降级 Mock 模式 — 数据库不可用时返回统计值
"""
import uuid
from datetime import datetime, date
from fastapi import APIRouter
from sqlalchemy import select
from app.schemas.sync import SyncBatchRequest
from app.database import get_db
from app.models.body_record import BodyRecord
from app.models.meal_record import MealRecord
from app.models.training_record import TrainingRecord
from app.models.drug_record import DrugRecord
from app.models.sleep_record import SleepRecord

router = APIRouter(prefix="/api/sync", tags=["数据同步"])


@router.post("/batch", response_model=dict)
async def sync_batch(body: SyncBatchRequest):
    """批量同步用户数据到 MySQL"""
    sync_id = f"sync_{datetime.now().strftime('%Y%m%d')}_{uuid.uuid4().hex[:6]}"
    stats = {"body": 0, "meal": 0, "training": 0, "drug": 0, "supplement": 0, "sleep": 0}

    try:
        async for session in get_db():
            # 写入身体数据
            for item in body.body_data:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()
                session.add(BodyRecord(
                    id=str(uuid.uuid4()),
                    user_id=body.user_id,
                    height_cm=item.height_cm,
                    weight_kg=item.weight_kg,
                    age=item.age,
                    sex=item.sex,
                    waist_cm=item.waist_cm,
                    chest_cm=item.chest_cm,
                    neck_cm=item.neck_cm,
                    hip_cm=item.hip_cm,
                    body_fat_percent=item.body_fat_percent,
                    activity_level=item.activity_level,
                    recorded_at=dt,
                ))
                stats["body"] += 1

            # 写入饮食记录
            for item in body.meal_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()
                session.add(MealRecord(
                    id=str(uuid.uuid4()),
                    user_id=body.user_id,
                    food_name=item.food_name,
                    meal_type=item.meal_type,
                    protein_g=item.protein_g,
                    fat_g=item.fat_g,
                    carbs_g=item.carbs_g,
                    fiber_g=item.fiber_g,
                    kcal=item.kcal,
                    recorded_at=dt,
                ))
                stats["meal"] += 1

            # 写入训练记录
            for item in body.training_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()
                session.add(TrainingRecord(
                    id=str(uuid.uuid4()),
                    user_id=body.user_id,
                    exercise_name=item.exercise_name,
                    training_type=item.training_type,
                    sets=item.sets,
                    reps=item.reps,
                    weight_kg=item.weight_kg,
                    duration_minutes=item.duration_minutes,
                    estimated_kcal=item.estimated_kcal,
                    recorded_at=dt,
                ))
                stats["training"] += 1

            # 写入用药记录
            for item in body.drug_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()
                session.add(DrugRecord(
                    id=str(uuid.uuid4()),
                    user_id=body.user_id,
                    drug_name=item.drug_name,
                    category=item.category,
                    status=item.status,
                    dosage=item.dosage,
                    unit=item.unit,
                    frequency=item.frequency,
                    recorded_at=dt,
                ))
                stats["drug"] += 1

            stats["supplement"] = len(body.supplement_records)

            # 写入睡眠记录（幂等 upsert：user_id + sleep_date 唯一）
            for item in body.sleep_records:
                try:
                    sleep_date = date.fromisoformat(item.sleep_date)
                except Exception:
                    continue
                result = await session.execute(
                    select(SleepRecord).where(
                        SleepRecord.user_id == body.user_id,
                        SleepRecord.sleep_date == sleep_date,
                    )
                )
                existing = result.scalar_one_or_none()
                recorded_at = datetime.now()
                if item.recorded_at:
                    try:
                        recorded_at = datetime.fromisoformat(item.recorded_at.replace("Z", "+00:00"))
                    except Exception:
                        recorded_at = datetime.now()
                if existing is not None:
                    existing.total_sleep_hours = item.total_sleep_hours
                    existing.core_sleep_hours = item.core_sleep_hours
                    existing.deep_sleep_hours = item.deep_sleep_hours
                    existing.rem_sleep_hours = item.rem_sleep_hours
                    existing.awake_hours = item.awake_hours
                    existing.resting_heart_rate = item.resting_heart_rate
                    existing.avg_hrv = item.avg_hrv
                    existing.source = item.source
                    existing.recorded_at = recorded_at
                else:
                    session.add(SleepRecord(
                        id=str(uuid.uuid4()),
                        user_id=body.user_id,
                        sleep_date=sleep_date,
                        total_sleep_hours=item.total_sleep_hours,
                        core_sleep_hours=item.core_sleep_hours,
                        deep_sleep_hours=item.deep_sleep_hours,
                        rem_sleep_hours=item.rem_sleep_hours,
                        awake_hours=item.awake_hours,
                        resting_heart_rate=item.resting_heart_rate,
                        avg_hrv=item.avg_hrv,
                        source=item.source,
                        recorded_at=recorded_at,
                    ))
                stats["sleep"] += 1

        return {
            "code": 0,
            "message": "ok",
            "data": {
                "sync_id": sync_id,
                "synced_at": datetime.now().isoformat(),
                "stats": {
                    "body_records_uploaded": stats["body"],
                    "meal_records_uploaded": stats["meal"],
                    "training_records_uploaded": stats["training"],
                    "drug_records_uploaded": stats["drug"],
                    "supplement_records_uploaded": stats["supplement"],
                    "sleep_records_uploaded": stats["sleep"],
                },
                "conflicts": [],
            }
        }
    except Exception as e:
        print(f"[sync] 数据库写入失败，降级到 mock: {e}")
        return {
            "code": 0,
            "message": f"同步完成（mock，数据库未写入: {e}）",
            "data": {
                "sync_id": sync_id,
                "synced_at": datetime.now().isoformat(),
                "stats": {
                    "body_records_uploaded": len(body.body_data),
                    "meal_records_uploaded": len(body.meal_records),
                    "training_records_uploaded": len(body.training_records),
                    "drug_records_uploaded": len(body.drug_records),
                    "supplement_records_uploaded": len(body.supplement_records),
                    "sleep_records_uploaded": len(body.sleep_records),
                },
                "conflicts": [],
            }
        }
