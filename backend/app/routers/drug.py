"""
药品路由: POST /api/drug/lookup, POST /api/drug/risk-check
"""
from fastapi import APIRouter, Query
from app.schemas.drug import DrugLookupRequest, DrugRiskCheckRequest
from app.services.mock import mock_drug_lookup, mock_drug_risk_check

router = APIRouter(prefix="/api/drug", tags=["药品"])


@router.post("/lookup", response_model=dict)
async def drug_lookup(body: DrugLookupRequest):
    """查询药品分类信息"""
    data = mock_drug_lookup(body.drug_name)
    return {"code": 0, "message": "ok", "data": data}


@router.post("/risk-check", response_model=dict)
async def drug_risk_check(body: DrugRiskCheckRequest):
    """校验药物与当前训练计划是否存在风险"""
    drug_names = [d.drug_name for d in body.active_drugs]
    data = mock_drug_risk_check(drug_names)
    return {"code": 0, "message": "ok", "data": data}


@router.get("/list", response_model=dict)
async def get_drug_list(
    user_id: str = Query("", description="用户 UUID"),
):
    """获取用户用药记录列表"""
    from sqlalchemy import select
    from app.database import get_db
    from app.models.drug_record import DrugRecord

    try:
        async for session in get_db():
            result = await session.execute(
                select(DrugRecord)
                .where(DrugRecord.user_id == user_id)
                .order_by(DrugRecord.created_at.desc())
            )
            records = result.scalars().all()
            break

        items = []
        for r in records:
            items.append({
                "record_id": r.id,
                "drug_name": r.drug_name,
                "category": r.category,
                "status": r.status,
                "dosage": r.dosage,
                "unit": r.unit,
                "frequency": r.frequency,
                "recorded_at": r.recorded_at.isoformat() if r.recorded_at else "",
            })

        return {"code": 0, "message": "ok", "data": {"records": items, "total": len(items)}}
    except Exception as e:
        print(f"[drug] 数据库查询失败: {e}")
        return {"code": 0, "message": "ok", "data": {"records": [], "total": 0}}
