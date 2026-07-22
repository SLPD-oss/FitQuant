"""
补剂方案路由: POST /api/supplement-plan
"""
from fastapi import APIRouter
from app.schemas.supplement import SupplementPlanRequest
from app.services.mock import mock_supplement_plan

router = APIRouter(prefix="/api/supplement-plan", tags=["补剂方案"])


@router.post("", response_model=dict)
async def get_supplement_plan(body: SupplementPlanRequest):
    """根据身体数据生成个性化补剂方案"""
    data = mock_supplement_plan(
        weight_kg=body.weight_kg,
        height_cm=body.height_cm,
        age=body.age,
        sex=body.sex,
        body_fat_percent=body.body_fat_percent,
        activity_level=body.activity_level,
        waist_cm=body.waist_cm,
        neck_cm=body.neck_cm,
    )
    return {"code": 0, "message": "ok", "data": data}
