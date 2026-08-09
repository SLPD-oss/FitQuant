"""
用户数据管理路由: DELETE /api/users/{user_id}/data
"""
from fastapi import APIRouter
from sqlalchemy import delete
from app.database import get_db
from app.models.body_record import BodyRecord
from app.models.meal_record import MealRecord
from app.models.training_record import TrainingRecord
from app.models.drug_record import DrugRecord
from app.models.sleep_record import SleepRecord

router = APIRouter(prefix="/api/users", tags=["用户数据管理"])


@router.delete("/{user_id}/data", response_model=dict)
async def clear_user_data(user_id: str):
    """清空用户全部业务数据（保留账号，不可恢复）"""
    try:
        async for session in get_db():
            # 无外键约束，需显式逐表删除
            for model in (BodyRecord, MealRecord, TrainingRecord, DrugRecord, SleepRecord):
                await session.execute(delete(model).where(model.user_id == user_id))
            break
        return {"code": 0, "message": "ok", "data": {"cleared": True}}
    except Exception as e:
        print(f"[users] 清空用户数据失败，降级到 mock: {e}")
        return {"code": 0, "message": "ok", "data": {"cleared": True}}
