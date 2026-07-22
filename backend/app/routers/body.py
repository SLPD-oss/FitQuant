"""
身体数据路由: PUT /api/body, GET /api/body/history
"""
from fastapi import APIRouter, Query
from app.schemas.body import BodyDataUploadRequest, BodyHistoryResponse
from app.services.mock import mock_upload_body, mock_body_history

router = APIRouter(prefix="/api/body", tags=["身体数据"])


@router.put("", response_model=dict)
async def upload_body(body: BodyDataUploadRequest):
    """上传身体测量数据"""
    data = mock_upload_body()
    return {"code": 0, "message": "ok", "data": data}


@router.get("/history", response_model=dict)
async def get_body_history(days: int = Query(30, description="查询天数")):
    """获取身体数据历史趋势"""
    data = mock_body_history()
    return {"code": 0, "message": "ok", "data": data}
