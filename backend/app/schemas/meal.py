from pydantic import BaseModel
from typing import List

class FoodItem(BaseModel):
    name: str
    estimated_weight_g: float
    calories: int
    protein_g: float
    carbs_g: float
    fat_g: float

class MealScanResponse(BaseModel):
    meal_name: str
    items: List[FoodItem]
    total_calories: int
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    health_warnings: List[str]
    suggestions: List[str]
