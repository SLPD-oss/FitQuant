"""
身体数据路由: PUT /api/body, GET /api/body/latest, GET /api/body/history
支持两种模式：
1. MySQL 真实读写 — 查 body_records 表
2. 降级 Mock 模式 — 数据库不可用时返回模拟数据
"""
import uuid
from datetime import datetime
from fastapi import APIRouter, Query
from sqlalchemy import select, desc

from app.schemas.body import BodyDataUploadRequest, BodyHistoryResponse, BodyHistoryRecord
from app.database import get_db
from app.models.body_record import BodyRecord

router = APIRouter(prefix="/api/body", tags=["身体数据"])


@router.put("", response_model=dict)
async def upload_body(body: BodyDataUploadRequest):
    """上传身体测量数据（优先写 MySQL，失败降级 mock）"""
    try:
        async for session in get_db():
            record = BodyRecord(
                id=str(uuid.uuid4()),
                user_id=body.user_id,
                height_cm=body.height_cm,
                weight_kg=body.weight_kg,
                age=body.age,
                sex=body.sex,
                chest_cm=body.chest_cm,
                waist_cm=body.waist_cm,
                neck_cm=body.neck_cm,
                hip_cm=body.hip_cm,
                body_fat_percent=body.body_fat_percent,
                activity_level=body.activity_level,
                recorded_at=datetime.fromisoformat(body.recorded_at.replace("Z", "+00:00")),
            )
            session.add(record)
        return {
            "code": 0,
            "message": "ok",
            "data": {
                "record_id": record.id,
                "created_at": datetime.now().isoformat(),
                "success": True,
            }
        }
    except Exception as e:
        print(f"[body] 数据库写入失败，降级到 mock: {e}")

    from app.services.mock import mock_upload_body
    data = mock_upload_body()
    return {"code": 0, "message": "ok", "data": data}


@router.get("/latest", response_model=dict)
async def get_body_latest(user_id: str = Query("", description="用户 UUID")):
    """获取用户最新一条身体数据"""
    try:
        async for session in get_db():
            result = await session.execute(
                select(BodyRecord)
                .where(BodyRecord.user_id == user_id)
                .order_by(desc(BodyRecord.recorded_at))
                .limit(1)
            )
            record = result.scalar_one_or_none()
            break

        if record is not None:
            return {
                "code": 0,
                "message": "ok",
                "data": {
                    "record_id": record.id,
                    "height_cm": record.height_cm,
                    "weight_kg": record.weight_kg,
                    "age": record.age,
                    "sex": record.sex,
                    "chest_cm": record.chest_cm,
                    "waist_cm": record.waist_cm,
                    "neck_cm": record.neck_cm,
                    "hip_cm": record.hip_cm,
                    "body_fat_percent": record.body_fat_percent,
                    "activity_level": record.activity_level,
                    "recorded_at": record.recorded_at.isoformat() if record.recorded_at else "",
                }
            }
        return {"code": 0, "message": "ok", "data": None}
    except Exception as e:
        print(f"[body] 数据库查询失败，降级到 mock: {e}")

    from app.services.mock import mock_body_history
    mock = mock_body_history()
    records = mock.get("records", [])
    latest = records[-1] if records else {"recorded_at": "", "weight_kg": 0, "body_fat_percent": 0}
    return {"code": 0, "message": "ok", "data": latest}


@router.get("/history", response_model=dict)
async def get_body_history(
    user_id: str = Query("", description="用户 UUID"),
    days: int = Query(30, description="查询天数"),
):
    """获取身体数据历史趋势"""
    try:
        async for session in get_db():
            result = await session.execute(
                select(BodyRecord)
                .where(BodyRecord.user_id == user_id)
                .order_by(BodyRecord.recorded_at.asc())
            )
            records = result.scalars().all()
            break

        if records:
            history = [
                BodyHistoryRecord(
                    recorded_at=r.recorded_at.strftime("%Y-%m-%d") if r.recorded_at else "",
                    weight_kg=r.weight_kg,
                    body_fat_percent=r.body_fat_percent,
                    height_cm=r.height_cm,
                    waist_cm=r.waist_cm,
                    neck_cm=r.neck_cm,
                    hip_cm=r.hip_cm,
                )
                for r in records
            ]
            first = records[0]
            last = records[-1]
            trend = {
                "weight_change_kg": round(last.weight_kg - first.weight_kg, 1),
                "body_fat_change_pct": round(last.body_fat_percent - first.body_fat_percent, 1),
            }
            return {
                "code": 0,
                "message": "ok",
                "data": {
                    "records": [h.model_dump() for h in history],
                    "trend": trend,
                }
            }
        return {"code": 0, "message": "ok", "data": {"records": [], "trend": {"weight_change_kg": 0, "body_fat_change_pct": 0}}}
    except Exception as e:
        print(f"[body] 数据库查询失败，降级到 mock: {e}")

    from app.services.mock import mock_body_history
    data = mock_body_history()
    return {"code": 0, "message": "ok", "data": data}
