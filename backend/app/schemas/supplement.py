from pydantic import BaseModel, Field
from typing import Optional

class SupplementPlanRequest(BaseModel):
    weight_kg: float = Field(..., description="体重（千克）", examples=[70.5])
    height_cm: float = Field(..., description="身高（厘米）", examples=[170])
    age: int = Field(..., description="年龄", examples=[25])
    sex: str = Field(..., description="性别: male / female", examples=["male"])
    body_fat_percent: float = Field(..., description="体脂率（%）", examples=[20.0])
    activity_level: str = Field(..., description="活动水平", examples=["moderate"])
    waist_cm: float = Field(..., description="腰围（厘米）", examples=[78])
    neck_cm: float = Field(..., description="颈围（厘米）", examples=[38])

class NutritionTargets(BaseModel):
    daily_kcal: float = Field(..., examples=[1500])
    protein_g: float = Field(..., examples=[141])
    fat_g: float = Field(..., examples=[52])
    carbs_g: float = Field(..., examples=[160])
    fiber_g: float = Field(..., examples=[25])
    base_deficit_kcal: float = Field(..., examples=[600])

class LiteratureRef(BaseModel):
    title: str
    doi: str = ""

class SupplementPlanResponse(BaseModel):
    bmi: float
    bmi_screening_zone: str
    tdee_kcal: float
    bmr_kcal: float
    protein_target_g: float
    protein_note: str
    whey_scoops_ref: float
    creatine_mg_per_day: float
    creatine_note: str
    vitamin_d3_iu_per_day: float
    fish_oil_mg_per_day: float
    water_liters_ref: float
    body_fat_estimate_pct: float
    body_fat_note: str
    nutrition_targets: NutritionTargets
    literature_refs: list[LiteratureRef] = []
