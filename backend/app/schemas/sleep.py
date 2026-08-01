"""
睡眠记录请求/响应模型
与前端 APIModels.swift 完全对齐，字段使用 snake_case。
"""
from pydantic import BaseModel, Field
from typing import List, Optional


class SleepRecordUpload(BaseModel):
    """单夜睡眠数据上报（HealthKit 采集字段 + 元数据）"""
    user_id: str = Field("", description="用户 UUID")
    sleep_date: str = Field(..., description="所属夜晚日期 YYYY-MM-DD", examples=["2026-07-31"])
    total_sleep_hours: float = Field(0, description="睡眠总时长（小时）")
    core_sleep_hours: float = Field(0, description="核心睡眠时长（小时）")
    deep_sleep_hours: float = Field(0, description="深睡眠时长（小时）")
    rem_sleep_hours: float = Field(0, description="REM 睡眠时长（小时）")
    awake_hours: float = Field(0, description="夜间清醒时长（小时）")
    resting_heart_rate: int = Field(0, description="晨起静息心率（次/分）")
    avg_hrv: int = Field(0, description="夜间平均 HRV（ms）")
    source: str = Field("healthkit", description="数据来源，默认 healthkit")


class SleepRecordOut(BaseModel):
    """睡眠记录输出（含后端派生指标 recovery_score / status / consecutive_low_score_days）"""
    record_id: str
    sleep_date: str
    total_sleep_hours: float
    core_sleep_hours: float
    deep_sleep_hours: float
    rem_sleep_hours: float
    awake_hours: float
    resting_heart_rate: int
    avg_hrv: int
    source: str
    recovery_score: int = Field(0, description="自研 0-100 恢复评分")
    recovery_status: str = Field("good", description="good / mild / severe")
    consecutive_low_score_days: int = Field(0, description="连续低分天数")


class SleepSuggestion(BaseModel):
    """训练建议（按状态 + 连续低分天数生成）"""
    title: str
    message: str


class SleepLatestResponse(BaseModel):
    """GET /api/sleep/latest 响应 data 结构"""
    record_id: str
    sleep_date: str
    total_sleep_hours: float
    core_sleep_hours: float
    deep_sleep_hours: float
    rem_sleep_hours: float
    awake_hours: float
    resting_heart_rate: int
    avg_hrv: int
    source: str
    recovery_score: int
    recovery_status: str
    consecutive_low_score_days: int
    suggestion: SleepSuggestion


class SleepHistoryResponse(BaseModel):
    """GET /api/sleep/history 响应 data 结构"""
    records: List[SleepRecordOut]
    total: int
