"""
自研睡眠恢复评分算法（启发式，仅供健身恢复参考，非医疗诊断）
============================
评分维度（满分 100）：
- 睡眠时长  30 分：≥7.5h 满分，线性递减，<4.5h 记 0
- 睡眠结构  25 分：深睡 ≥1.5h 得 12 分 + 夜间清醒 ≤0.5h 得 8 分 + REM ≥1.5h 得 5 分（均线性）
- HRV       25 分：与个人近 7 天基线比较，达到基线满分，低于基线线性扣减
- 静息心率  20 分：≤ 基线满分，高于基线按差值线性扣减

状态映射：≥80 good（恢复良好）/ ≥60 mild（轻度恢复不足）/ <60 severe（恢复严重不足）
派生指标（不落库）：recovery_score / recovery_status / consecutive_low_score_days
"""
from typing import List, Optional

# ── 常量 ──
TARGET_TOTAL_HOURS = 7.5
MIN_TOTAL_HOURS = 4.5
TARGET_DEEP_HOURS = 1.5
TARGET_REM_HOURS = 1.5
MAX_AWAKE_HOURS = 0.5

SCORE_GOOD = 80
SCORE_MILD = 60
LOW_SCORE_THRESHOLD = 60  # 低于此分数计为"低分夜"


def _clamp(value: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, value))


def compute_score(
    total_hours: float,
    deep_hours: float,
    rem_hours: float,
    awake_hours: float,
    resting_heart_rate: int,
    avg_hrv: int,
    baseline_hrv: Optional[float] = None,
    baseline_rhr: Optional[float] = None,
) -> int:
    """计算单夜 0-100 恢复评分。

    基线缺省时使用通用参考值（HRV 60ms / 静息心率 60bpm），
    有个人近 7 天历史时优先传入个人基线，实现相对比较。
    """
    baseline_hrv = baseline_hrv if baseline_hrv and baseline_hrv > 0 else 60.0
    baseline_rhr = baseline_rhr if baseline_rhr and baseline_rhr > 0 else 60.0

    # 1) 睡眠时长分（30）
    if total_hours >= TARGET_TOTAL_HOURS:
        duration_score = 30.0
    elif total_hours <= MIN_TOTAL_HOURS:
        duration_score = 0.0
    else:
        duration_score = 30.0 * (total_hours - MIN_TOTAL_HOURS) / (TARGET_TOTAL_HOURS - MIN_TOTAL_HOURS)

    # 2) 睡眠结构分（25）
    deep_score = _clamp(12.0 * deep_hours / TARGET_DEEP_HOURS, 0, 12)
    awake_score = 8.0 if awake_hours <= MAX_AWAKE_HOURS else _clamp(8.0 - (awake_hours - MAX_AWAKE_HOURS) * 8.0, 0, 8)
    rem_score = _clamp(5.0 * rem_hours / TARGET_REM_HOURS, 0, 5)
    structure_score = _clamp(deep_score + awake_score + rem_score, 0, 25)

    # 3) HRV 分（25，相对个人基线）
    hrv_ratio = avg_hrv / baseline_hrv if baseline_hrv > 0 else 1.0
    hrv_score = _clamp(25.0 * min(hrv_ratio, 1.6), 0, 25)

    # 4) 静息心率分（20，相对个人基线）
    if resting_heart_rate <= baseline_rhr:
        rhr_score = 20.0
    else:
        rhr_score = _clamp(20.0 - (resting_heart_rate - baseline_rhr) * 2.0, 0, 20)

    return int(round(_clamp(duration_score + structure_score + hrv_score + rhr_score)))


def status_of(score: int) -> str:
    """0-100 分 → 状态枚举（与前端 SleepRecoveryStatus 分级一致）"""
    if score >= SCORE_GOOD:
        return "good"
    if score >= SCORE_MILD:
        return "mild"
    return "severe"


def consecutive_low_days(scores: List[int]) -> int:
    """从最近一夜（列表首位，最新在前）往前数，连续 score < 60 的天数。
    约定：scores 按日期倒序传入（最新一夜在第一位）。"""
    count = 0
    for score in scores:
        if score < LOW_SCORE_THRESHOLD:
            count += 1
        else:
            break
    return count


def suggestion_for(score: int, consecutive_days: int) -> dict:
    """按状态 + 连续低分天数生成训练建议（文案与前端三套状态文案对齐）"""
    status = status_of(score)
    if status == "good":
        return {
            "title": "今日恢复状态良好",
            "message": "睡眠与身体恢复状态优秀，可正常执行原定力量、有氧训练计划",
        }
    if status == "mild":
        return {
            "title": "轻度恢复不足提醒",
            "message": "睡眠结构一般、自主神经活跃度偏低，建议今日适当下调训练重量与组数，降低高强度训练占比",
        }
    # severe
    title = "重度休息建议" if consecutive_days >= 2 else "恢复不足提醒"
    message = "睡眠碎片化偏高、身体应激状态较高（关联皮质醇偏高趋势），不建议进行力量训练、高强度有氧"
    if consecutive_days >= 2:
        message += f"。已连续 {consecutive_days} 晚评分偏低，今日建议以休息与低强度活动为主"
    message += "。推荐替代方案：轻度散步、低强度活动，饮食清淡、维持蛋白、不加大热量缺口"
    return {"title": title, "message": message}
