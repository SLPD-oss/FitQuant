"""
训练动作分类路由: POST /api/workout/classify
"""
from fastapi import APIRouter
from app.schemas.workout import WorkoutClassifyRequest
from app.services.mock import mock_workout_classify

router = APIRouter(prefix="/api/workout", tags=["训练动作"])


@router.post("/classify", response_model=dict)
async def workout_classify(body: WorkoutClassifyRequest):
    """识别训练动作分类和目标肌群"""
    data = mock_workout_classify(body.action_name)
    return {"code": 0, "message": "ok", "data": data}
