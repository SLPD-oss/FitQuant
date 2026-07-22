from pydantic import BaseModel, Field
from typing import Optional

class NutritionPer100g(BaseModel):
    protein_g: float
    fat_g: float
    carbs_g: float
    fiber_g: float
    kcal: float
    sodium_mg: float
    sugar_g: float

class FoodAlternative(BaseModel):
    name: str
    protein_g: float
    kcal: float

class FoodRecognitionResponse(BaseModel):
    food_name: str = Field(..., examples=["鸡胸肉（熟）"])
    confidence: float = Field(..., description="识别置信度", examples=[0.95])
    serving_size_g: float = Field(..., description="标准份量（克）", examples=[100])
    nutrition_per_100g: NutritionPer100g
    possible_alternatives: list[FoodAlternative] = []
    allergen_warnings: list[str] = []
