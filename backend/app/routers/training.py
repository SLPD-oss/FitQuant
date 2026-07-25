"""
训练记录路由: GET /api/training/history
"""
import uuid
from datetime import datetime
from fastapi import APIRouter, Query
from sqlalchemy import select, desc
from app.database import get_db
from app.models.training_record import TrainingRecord

router = APIRouter(prefix="/api/training", tags=["训练记录"])


@router.get("/history", response_model=dict)
async def get_training_history(
    user_id: str = Query("", description="用户 UUID"),
    days: int = Query(30, description="查询天数"),
):
    """获取用户训练记录历史"""
    try:
        async for session in get_db():
            result = await session.execute(
                select(TrainingRecord)
                .where(TrainingRecord.user_id == user_id)
                .order_by(desc(TrainingRecord.recorded_at))
            )
            records = result.scalars().all()
            break

        items = []
        for r in records:
            items.append({
                "record_id": r.id,
                "exercise_name": r.exercise_name,
                "training_type": r.training_type,
                "sets": r.sets,
                "reps": r.reps,
                "weight_kg": r.weight_kg,
                "duration_minutes": r.duration_minutes,
                "estimated_kcal": r.estimated_kcal,
                "recorded_at": r.recorded_at.isoformat() if r.recorded_at else "",
            })

        return {
            "code": 0,
            "message": "ok",
            "data": {"records": items, "total": len(items)}
        }
    except Exception as e:
        print(f"[training] 数据库查询失败: {e}")
        return {"code": 0, "message": "ok", "data": {"records": [], "total": 0}}
