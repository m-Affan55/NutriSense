from pydantic import BaseModel
from typing import List

class FoodItem(BaseModel):
    name: str
    local_name: str
    estimated_weight_g: float
    calories: int
    protein_g: float
    carbs_g: float
    fat_g: float
    cooking_method_note: str

class MealScanResponse(BaseModel):
    is_food: bool
    meal_name: str
    items: List[FoodItem]
    total_calories: int
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    recognition_confidence: str
    health_warnings: List[str]
    suggestions: List[str]
