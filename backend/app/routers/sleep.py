"""
睡眠记录路由: POST /api/sleep/records, GET /api/sleep/latest, GET /api/sleep/history
支持两种模式：
1. MySQL 真实读写 — 查 sleep_records 表（user_id + sleep_date 唯一，幂等 upsert）
2. 降级 Mock 模式 — 数据库不可用时返回模拟数据
派生指标（recovery_score / status / consecutive_low_score_days / suggestion）
由 sleep_score 算法实时计算，不落库。
"""
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Query
from sqlalchemy import select, desc

from app.schemas.sleep import SleepRecordUpload
from app.database import get_db
from app.models.sleep_record import SleepRecord
from app.services import sleep_score

router = APIRouter(prefix="/api/sleep", tags=["睡眠恢复"])


def _record_to_dict(r: SleepRecord, score: int, status: str, consecutive: int, suggestion: dict = None) -> dict:
    """ORM 记录 → 输出字典（含派生指标）"""
    return {
        "record_id": r.id,
        "sleep_date": r.sleep_date.strftime("%Y-%m-%d") if r.sleep_date else "",
        "total_sleep_hours": r.total_sleep_hours,
        "core_sleep_hours": r.core_sleep_hours,
        "deep_sleep_hours": r.deep_sleep_hours,
        "rem_sleep_hours": r.rem_sleep_hours,
        "awake_hours": r.awake_hours,
        "resting_heart_rate": r.resting_heart_rate,
        "avg_hrv": r.avg_hrv,
        "source": r.source,
        "recovery_score": score,
        "recovery_status": status,
        "consecutive_low_score_days": consecutive,
        **({"suggestion": suggestion} if suggestion else {}),
    }


def _baseline_of(records: list) -> tuple:
    """计算个人基线（近 7 天历史 avg_hrv / resting_heart_rate 平均值），
    无历史时返回 None 由算法使用通用参考值。"""
    if not records:
        return None, None
    hrvs = [r.avg_hrv for r in records if r.avg_hrv and r.avg_hrv > 0]
    rhrs = [r.resting_heart_rate for r in records if r.resting_heart_rate and r.resting_heart_rate > 0]
    base_hrv = sum(hrvs) / len(hrvs) if hrvs else None
    base_rhr = sum(rhrs) / len(rhrs) if rhrs else None
    return base_hrv, base_rhr


async def _load_user_records(user_id: str, days: int = 30):
    """读取用户最近 days 天睡眠记录（按日期倒序）"""
    async for session in get_db():
        cutoff = (datetime.now() - timedelta(days=days)).date()
        result = await session.execute(
            select(SleepRecord)
            .where(SleepRecord.user_id == user_id, SleepRecord.sleep_date >= cutoff)
            .order_by(desc(SleepRecord.sleep_date))
        )
        records = result.scalars().all()
        break
    return records


@router.post("/records", response_model=dict)
async def upload_sleep_record(body: SleepRecordUpload):
    """上报一夜睡眠数据（按 user_id + sleep_date 幂等 upsert，重复同步不产生脏数据）"""
    try:
        from datetime import date as date_cls
        sleep_date = date_cls.fromisoformat(body.sleep_date)
        async for session in get_db():
            # 查询已存在的记录
            result = await session.execute(
                select(SleepRecord).where(
                    SleepRecord.user_id == body.user_id,
                    SleepRecord.sleep_date == sleep_date,
                )
            )
            record = result.scalar_one_or_none()
            if record is not None:
                # 更新已有记录（保持 id 不变）
                record.total_sleep_hours = body.total_sleep_hours
                record.core_sleep_hours = body.core_sleep_hours
                record.deep_sleep_hours = body.deep_sleep_hours
                record.rem_sleep_hours = body.rem_sleep_hours
                record.awake_hours = body.awake_hours
                record.resting_heart_rate = body.resting_heart_rate
                record.avg_hrv = body.avg_hrv
                record.source = body.source
                record.recorded_at = datetime.now()
                record_id = record.id
                updated = True
            else:
                record = SleepRecord(
                    id=str(uuid.uuid4()),
                    user_id=body.user_id,
                    sleep_date=sleep_date,
                    total_sleep_hours=body.total_sleep_hours,
                    core_sleep_hours=body.core_sleep_hours,
                    deep_sleep_hours=body.deep_sleep_hours,
                    rem_sleep_hours=body.rem_sleep_hours,
                    awake_hours=body.awake_hours,
                    resting_heart_rate=body.resting_heart_rate,
                    avg_hrv=body.avg_hrv,
                    source=body.source,
                    recorded_at=datetime.now(),
                )
                session.add(record)
                record_id = record.id
                updated = False
        return {
            "code": 0,
            "message": "ok",
            "data": {"record_id": record_id, "sleep_date": body.sleep_date, "updated": updated},
        }
    except Exception as e:
        print(f"[sleep] 数据库写入失败，降级到 mock: {e}")
        return {
            "code": 0,
            "message": "ok",
            "data": {"record_id": f"sleep_rec_{uuid.uuid4().hex[:8]}", "sleep_date": body.sleep_date, "updated": False},
        }


@router.get("/latest", response_model=dict)
async def get_sleep_latest(user_id: str = Query("", description="用户 UUID")):
    """获取用户最新一夜睡眠恢复数据（采集字段 + 自研评分 + 状态 + 训练建议）"""
    try:
        records = await _load_user_records(user_id, days=30)
        if not records:
            return {"code": 0, "message": "ok", "data": None}

        latest = records[0]
        history = records[1:]  # 基线使用除最新一晚外的历史

        # 按日期倒序计算全部夜分数（最新在前）
        scores = []
        all_records = records
        base_hrv, base_rhr = _baseline_of(history)
        for r in all_records:
            scores.append(sleep_score.compute_score(
                r.total_sleep_hours or 0,
                r.deep_sleep_hours or 0,
                r.rem_sleep_hours or 0,
                r.awake_hours or 0,
                r.resting_heart_rate or 0,
                r.avg_hrv or 0,
                baseline_hrv=base_hrv,
                baseline_rhr=base_rhr,
            ))
        latest_score = scores[0]
        consecutive = sleep_score.consecutive_low_days(scores)
        status = sleep_score.status_of(latest_score)
        suggestion = sleep_score.suggestion_for(latest_score, consecutive)

        data = _record_to_dict(latest, latest_score, status, consecutive, suggestion=suggestion)
        return {"code": 0, "message": "ok", "data": data}
    except Exception as e:
        print(f"[sleep] 数据库查询失败，降级到 mock: {e}")

    from app.services.mock import mock_sleep_latest
    return {"code": 0, "message": "ok", "data": mock_sleep_latest()}


@router.get("/history", response_model=dict)
async def get_sleep_history(
    user_id: str = Query("", description="用户 UUID"),
    days: int = Query(7, description="查询天数"),
):
    """获取用户近 N 夜睡眠恢复历史（含每夜评分，按日期倒序）"""
    try:
        records = await _load_user_records(user_id, days=days)
        if not records:
            return {"code": 0, "message": "ok", "data": {"records": [], "total": 0}}

        base_hrv, base_rhr = _baseline_of(records)
        scores = []
        for r in records:
            scores.append(sleep_score.compute_score(
                r.total_sleep_hours or 0,
                r.deep_sleep_hours or 0,
                r.rem_sleep_hours or 0,
                r.awake_hours or 0,
                r.resting_heart_rate or 0,
                r.avg_hrv or 0,
                baseline_hrv=base_hrv,
                baseline_rhr=base_rhr,
            ))
        consecutive = sleep_score.consecutive_low_days(scores)

        items = []
        for r, score in zip(records, scores):
            items.append(_record_to_dict(
                r, score, sleep_score.status_of(score),
                consecutive if r is records[0] else 0,
            ))

        return {"code": 0, "message": "ok", "data": {"records": items, "total": len(items)}}
    except Exception as e:
        print(f"[sleep] 数据库查询失败，降级到 mock: {e}")

    from app.services.mock import mock_sleep_history
    return {"code": 0, "message": "ok", "data": mock_sleep_history()}
