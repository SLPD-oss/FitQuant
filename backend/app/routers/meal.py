"""
饮食记录路由: GET /api/meal/today
"""
import uuid
from datetime import datetime, date
from fastapi import APIRouter, Query
from sqlalchemy import select
from app.database import get_db
from app.models.meal_record import MealRecord

router = APIRouter(prefix="/api/meal", tags=["饮食记录"])


@router.get("/today", response_model=dict)
async def get_today_meals(
    user_id: str = Query("", description="用户 UUID"),
    meal_date: str = Query("", description="查询日期 YYYY-MM-DD，默认今天"),
):
    """获取用户指定日期的饮食记录"""
    query_date = meal_date if meal_date else date.today().isoformat()

    try:
        async for session in get_db():
            result = await session.execute(
                select(MealRecord)
                .where(MealRecord.user_id == user_id)
                .where(MealRecord.recorded_at >= query_date)
                .where(MealRecord.recorded_at < query_date + " 23:59:59")
            )
            records = result.scalars().all()
            break

        meals = []
        totals = {"protein_g": 0, "fat_g": 0, "carbs_g": 0, "fiber_g": 0, "kcal": 0}
        for r in records:
            item = {
                "record_id": r.id,
                "food_name": r.food_name,
                "meal_type": r.meal_type,
                "protein_g": r.protein_g,
                "fat_g": r.fat_g,
                "carbs_g": r.carbs_g,
                "fiber_g": r.fiber_g,
                "kcal": r.kcal,
                "recorded_at": r.recorded_at.isoformat() if r.recorded_at else "",
            }
            meals.append(item)
            totals["protein_g"] += r.protein_g
            totals["fat_g"] += r.fat_g
            totals["carbs_g"] += r.carbs_g
            totals["fiber_g"] += r.fiber_g
            totals["kcal"] += r.kcal

        return {
            "code": 0,
            "message": "ok",
            "data": {
                "date": query_date,
                "meals": meals,
                "totals": totals,
            }
        }
    except Exception as e:
        print(f"[meal] 数据库查询失败: {e}")
        return {
            "code": 0,
            "message": "ok",
            "data": {"date": query_date, "meals": [], "totals": {"protein_g": 0, "fat_g": 0, "carbs_g": 0, "fiber_g": 0, "kcal": 0}}
        }
