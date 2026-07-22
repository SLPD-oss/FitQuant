"""
药品路由: POST /api/drug/lookup, POST /api/drug/risk-check
"""
from fastapi import APIRouter
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
