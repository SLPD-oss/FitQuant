"""
数据同步路由: POST /api/sync/batch
支持两种模式：
1. MySQL 真实写入 — 批量写入 body_records/meal_records/training_records/drug_records
2. 降级 Mock 模式 — 数据库不可用时返回统计值
"""
import uuid
from datetime import datetime, date
from fastapi import APIRouter
from sqlalchemy import select, delete
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
    stats = {"body": 0, "meal": 0, "training": 0, "drug": 0, "drug_deleted": 0, "meal_deleted": 0, "training_deleted": 0, "supplement": 0, "sleep": 0}

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

            # 删除饮食记录（删除传播，先删后插，避免与 upsert 同键冲突）
            # 【Bug 修复｜删除同步】与药物分支同一机制：原实现只有无条件 INSERT、无删除逻辑，
            # 被删记录永久留在库中，前端切页重新拉取后「复活」。修复：前端把待删除记录的
            # ID 或幂等键随包上传，后端在此按 (user_id, id) 或 (user_id, meal_type, food_name, recorded_at) 执行删除。
            for item in body.deleted_meal_records:
                if item.record_id:
                    result = await session.execute(
                        delete(MealRecord).where(
                            MealRecord.user_id == body.user_id,
                            MealRecord.id == item.record_id,
                        )
                    )
                    stats["meal_deleted"] += result.rowcount
                if item.meal_type and item.food_name and item.recorded_at:
                    try:
                        dt = datetime.fromisoformat(item.recorded_at.replace("Z", "+00:00"))
                    except Exception:
                        dt = None
                    if dt is not None:
                        result = await session.execute(
                            delete(MealRecord).where(
                                MealRecord.user_id == body.user_id,
                                MealRecord.meal_type == item.meal_type,
                                MealRecord.food_name == item.food_name,
                                MealRecord.recorded_at == dt,
                            )
                        )
                        stats["meal_deleted"] += result.rowcount

            # 写入饮食记录（幂等 upsert）
            # 【Bug 修复｜删除同步】原实现无条件 INSERT（每次生成新 UUID），前后端 id 不一致，
            # 前端按本地 id 删除匹配不到后端行，切页拉取后「复活」。
            # 修复：优先按 (user_id, record_id) 匹配 —— 前端同步携带本地 id，命中则更新该行
            # （前后端 id 一致），未命中但带 id 时按该 id 插入（不再生成新 UUID）。
            # 旧版本客户端不带 record_id 时回退幂等键 (user_id, meal_type, food_name, recorded_at)，向后兼容。
            for item in body.meal_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()

                # ① 优先按客户端 id 匹配
                if item.record_id:
                    existing = (
                        await session.execute(
                            select(MealRecord).where(
                                MealRecord.user_id == body.user_id,
                                MealRecord.id == item.record_id,
                            )
                        )
                    ).scalar_one_or_none()
                    if existing is not None:
                        existing.food_name = item.food_name
                        existing.meal_type = item.meal_type
                        existing.protein_g = item.protein_g
                        existing.fat_g = item.fat_g
                        existing.carbs_g = item.carbs_g
                        existing.fiber_g = item.fiber_g
                        existing.kcal = item.kcal
                        existing.recorded_at = dt
                        stats["meal"] += 1
                        continue

                # ② 按幂等键 (user_id, meal_type, food_name, recorded_at) 查重
                result = await session.execute(
                    select(MealRecord).where(
                        MealRecord.user_id == body.user_id,
                        MealRecord.meal_type == item.meal_type,
                        MealRecord.food_name == item.food_name,
                        MealRecord.recorded_at == dt,
                    )
                )
                existing_rows = result.scalars().all()
                if existing_rows:
                    # 幂等命中：更新第一条为最新状态，删除其余同键重复行（收敛存量膨胀数据）
                    first = existing_rows[0]
                    first.protein_g = item.protein_g
                    first.fat_g = item.fat_g
                    first.carbs_g = item.carbs_g
                    first.fiber_g = item.fiber_g
                    first.kcal = item.kcal
                    for dup in existing_rows[1:]:
                        await session.delete(dup)
                else:
                    # ③ 插入：优先使用客户端 id（保持前后端一致），否则生成新 UUID
                    session.add(MealRecord(
                        id=item.record_id if item.record_id else str(uuid.uuid4()),
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

            # 删除训练记录（删除传播，先删后插，避免与 upsert 同键冲突）
            # 【Bug 修复｜删除同步】与药物分支同一机制：原实现只有无条件 INSERT、无删除逻辑，
            # 被删记录永久留在库中，前端切页重新拉取后「复活」。修复：前端把待删除记录的
            # ID 或幂等键随包上传，后端在此按 (user_id, id) 或 (user_id, exercise_name, recorded_at) 执行删除。
            for item in body.deleted_training_records:
                if item.record_id:
                    result = await session.execute(
                        delete(TrainingRecord).where(
                            TrainingRecord.user_id == body.user_id,
                            TrainingRecord.id == item.record_id,
                        )
                    )
                    stats["training_deleted"] += result.rowcount
                if item.exercise_name and item.recorded_at:
                    try:
                        dt = datetime.fromisoformat(item.recorded_at.replace("Z", "+00:00"))
                    except Exception:
                        dt = None
                    if dt is not None:
                        result = await session.execute(
                            delete(TrainingRecord).where(
                                TrainingRecord.user_id == body.user_id,
                                TrainingRecord.exercise_name == item.exercise_name,
                                TrainingRecord.recorded_at == dt,
                            )
                        )
                        stats["training_deleted"] += result.rowcount

            # 写入训练记录（幂等 upsert）
            # 【Bug 修复｜删除同步】与饮食/药物分支同一机制：无条件 INSERT 导致前后端 id 不一致，
            # 前端按本地 id 删除匹配不到后端行，切页拉取后「复活」。
            # 修复：优先按 (user_id, record_id) 匹配 —— 命中则更新该行，未命中但带 id 时按该 id 插入；
            # 旧版本客户端不带 record_id 时回退幂等键 (user_id, exercise_name, recorded_at)，向后兼容。
            for item in body.training_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()

                # ① 优先按客户端 id 匹配
                if item.record_id:
                    existing = (
                        await session.execute(
                            select(TrainingRecord).where(
                                TrainingRecord.user_id == body.user_id,
                                TrainingRecord.id == item.record_id,
                            )
                        )
                    ).scalar_one_or_none()
                    if existing is not None:
                        existing.exercise_name = item.exercise_name
                        existing.training_type = item.training_type
                        existing.sets = item.sets
                        existing.reps = item.reps
                        existing.weight_kg = item.weight_kg
                        existing.duration_minutes = item.duration_minutes
                        existing.estimated_kcal = item.estimated_kcal
                        existing.recorded_at = dt
                        stats["training"] += 1
                        continue

                # ② 按幂等键 (user_id, exercise_name, recorded_at) 查重
                result = await session.execute(
                    select(TrainingRecord).where(
                        TrainingRecord.user_id == body.user_id,
                        TrainingRecord.exercise_name == item.exercise_name,
                        TrainingRecord.recorded_at == dt,
                    )
                )
                existing_rows = result.scalars().all()
                if existing_rows:
                    # 幂等命中：更新第一条为最新状态，删除其余同键重复行（收敛存量膨胀数据）
                    first = existing_rows[0]
                    first.training_type = item.training_type
                    first.sets = item.sets
                    first.reps = item.reps
                    first.weight_kg = item.weight_kg
                    first.duration_minutes = item.duration_minutes
                    first.estimated_kcal = item.estimated_kcal
                    for dup in existing_rows[1:]:
                        await session.delete(dup)
                else:
                    # ③ 插入：优先使用客户端 id（保持前后端一致），否则生成新 UUID
                    session.add(TrainingRecord(
                        id=item.record_id if item.record_id else str(uuid.uuid4()),
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

            # 删除用药记录（删除传播，先删后插，避免与 upsert 同键冲突）
            # 【Bug 修复｜删除同步】原实现只有 upsert、无删除逻辑，被删记录永久留在库中，
            # 前端切页重新拉取后「复活」。修复：前端把待删除记录的 ID 或幂等键随包上传，
            # 后端在此按 (user_id, id) 或 (user_id, drug_name, recorded_at) 执行删除。
            # 【清空兜底】clear_all_drugs=true 时无条件删除该用户全部用药记录——
            # 墓碑按 id 删除对历史膨胀/残留数据可能失效，一键删除必须真正清空云端。
            if body.clear_all_drugs:
                result = await session.execute(
                    delete(DrugRecord).where(DrugRecord.user_id == body.user_id)
                )
                stats["drug_deleted"] += result.rowcount
            else:
                for item in body.deleted_drug_records:
                    if item.record_id:
                        result = await session.execute(
                            delete(DrugRecord).where(
                                DrugRecord.user_id == body.user_id,
                                DrugRecord.id == item.record_id,
                            )
                        )
                        stats["drug_deleted"] += result.rowcount
                    if item.drug_name and item.recorded_at:
                        try:
                            dt = datetime.fromisoformat(item.recorded_at.replace("Z", "+00:00"))
                        except Exception:
                            dt = None
                        if dt is not None:
                            result = await session.execute(
                                delete(DrugRecord).where(
                                    DrugRecord.user_id == body.user_id,
                                    DrugRecord.drug_name == item.drug_name,
                                    DrugRecord.recorded_at == dt,
                                )
                            )
                            stats["drug_deleted"] += result.rowcount

            # 写入用药记录
            # 【Bug 修复｜幂等 upsert】原实现无条件 INSERT（每次生成新 UUID）导致 full 全量同步时
            # 数据库记录无限重复累积（用药 Tab 切换数据膨胀问题）。
            # 修复：按 (user_id, drug_name, recorded_at) 幂等键查重 ——
            #   不存在 → 插入；存在 → 更新第一条并删除其余同键重复行（自动收敛存量重复）。
            # 幂等键稳定性依赖前端不重建 createdAt（recorded_at 保持稳定）。
            # 【重复记录修复】优先按 (user_id, record_id) 匹配：前端同步携带本地 id，
            # 命中则更新该行（前后端 id 一致），未命中但带 id 时按该 id 插入（不再生成新 UUID）。
            # 旧版本客户端不带 record_id 时回退到幂等键逻辑，向后兼容。
            for item in body.drug_records:
                recorded_at = item.recorded_at
                try:
                    dt = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
                except Exception:
                    dt = datetime.now()

                # ① 优先按客户端 id 匹配
                if item.record_id:
                    existing = (
                        await session.execute(
                            select(DrugRecord).where(
                                DrugRecord.user_id == body.user_id,
                                DrugRecord.id == item.record_id,
                            )
                        )
                    ).scalar_one_or_none()
                    if existing is not None:
                        existing.drug_name = item.drug_name
                        existing.category = item.category
                        existing.status = item.status
                        existing.dosage = item.dosage
                        existing.unit = item.unit
                        existing.frequency = item.frequency
                        existing.recorded_at = dt
                        stats["drug"] += 1
                        continue

                # ② 按幂等键 (user_id, drug_name, recorded_at) 查重
                result = await session.execute(
                    select(DrugRecord).where(
                        DrugRecord.user_id == body.user_id,
                        DrugRecord.drug_name == item.drug_name,
                        DrugRecord.recorded_at == dt,
                    )
                )
                existing_rows = result.scalars().all()
                if existing_rows:
                    # 幂等命中：更新第一条为最新状态，删除其余同键重复行（收敛存量膨胀数据）
                    first = existing_rows[0]
                    first.category = item.category
                    first.status = item.status
                    first.dosage = item.dosage
                    first.unit = item.unit
                    first.frequency = item.frequency
                    for dup in existing_rows[1:]:
                        await session.delete(dup)
                else:
                    # ③ 插入：优先使用客户端 id（保持前后端一致），否则生成新 UUID
                    session.add(DrugRecord(
                        id=item.record_id if item.record_id else str(uuid.uuid4()),
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
                    "drug_records_deleted": stats["drug_deleted"],
                    "meal_records_deleted": stats["meal_deleted"],
                    "training_records_deleted": stats["training_deleted"],
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
