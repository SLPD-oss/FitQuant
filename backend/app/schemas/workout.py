from pydantic import BaseModel, Field
from typing import Optional

class WorkoutClassifyRequest(BaseModel):
    action_name: str = Field(..., examples=["杠铃卧推"])

class WorkoutClassifyResponse(BaseModel):
    action_name: str
    training_type: str = Field(..., description="strength / cardio")
    aerobic_sub_type: Optional[str] = Field(None, description="steadyCardio / hiit / null")
    primary_muscle_group: str = Field(..., description="主要目标肌群")
    secondary_muscle_groups: list[str] = []
    sub_muscle_options: list[str] = []
    is_high_risk_wrist: bool = Field(..., description="TFCC 风险标记")
    estimated_kcal_per_min: float = Field(..., description="每分钟消耗 kcal")
    common_equipment: list[str] = []
    difficulty: str = Field(..., description="beginner / intermediate / advanced")
