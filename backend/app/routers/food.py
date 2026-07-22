"""
食物识别路由: POST /api/food/recognize
"""
from fastapi import APIRouter, UploadFile, File, Form
from app.services.mock import mock_food_recognition

router = APIRouter(prefix="/api/food", tags=["食物识别"])


@router.post("/recognize", response_model=dict)
async def recognize_food(file: UploadFile = File(...), food_name: str = Form("")):
    """
    食物 AI 视觉识别（当前使用模拟数据）
    上传图片文件，返回识别出的营养信息
    """
    name = food_name if food_name else (file.filename or "").split(".")[0]
    data = mock_food_recognition(name)
    return {"code": 0, "message": "ok", "data": data}
