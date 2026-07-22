"""
数据同步路由: POST /api/sync/batch
"""
from fastapi import APIRouter
from app.schemas.sync import SyncBatchRequest
import uuid
from datetime import datetime

router = APIRouter(prefix="/api/sync", tags=["数据同步"])


@router.post("/batch", response_model=dict)
async def sync_batch(body: SyncBatchRequest):
    """批量同步用户数据（全量/增量）"""
    stats = {
        "body_records_uploaded": len(body.body_data),
        "meal_records_uploaded": len(body.meal_records),
        "training_records_uploaded": len(body.training_records),
        "drug_records_uploaded": len(body.drug_records),
        "supplement_records_uploaded": len(body.supplement_records),
    }
    data = {
        "sync_id": f"sync_{datetime.now().strftime('%Y%m%d')}_{uuid.uuid4().hex[:6]}",
        "synced_at": datetime.now().isoformat(),
        "stats": stats,
        "conflicts": [],
    }
    return {"code": 0, "message": "ok", "data": data}
