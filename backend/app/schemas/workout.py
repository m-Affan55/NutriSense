from typing import List, Optional
from pydantic import BaseModel, Field

class Exercise(BaseModel):
    name: str = Field(..., description="Name of the exercise (e.g. Incline Dumbbell Press, Bodyweight Squats)")
    target_muscle: str = Field(..., description="Primary muscle targeted (e.g. Chest, Quads, Glutes, Core)")
    sets: int = Field(default=3, ge=1, le=10, description="Number of sets")
    reps: str = Field(default="10-12", description="Repetition range or duration string (e.g. '10-12 reps' or '45 seconds')")
    rest_seconds: int = Field(default=60, ge=0, le=300, description="Rest period between sets in seconds")
    form_cues: str = Field(default="", description="Key form technique tips for safety and maximum engagement")
    precautions: str = Field(default="", description="Safety precaution or modification if user has medical condition")

class WorkoutDay(BaseModel):
    day_name: str = Field(..., description="Day of the week: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday")
    is_rest_day: bool = Field(default=False, description="True if this day is a designated rest or active recovery day")
    workout_title: str = Field(default="Rest & Active Recovery", description="Title of the workout routine")
    target_focus: str = Field(default="Recovery & Mobility", description="Target focus (e.g., Upper Body Hypertrophy, Low-Impact Cardio & Core)")
    duration_mins: int = Field(default=0, ge=0, le=180, description="Estimated total duration in minutes")
    estimated_calories_burned: int = Field(default=0, ge=0, le=1500, description="Estimated calories burned during workout")
    warm_up: str = Field(default="", description="Dynamic warm-up and joint mobility instructions")
    exercises: List[Exercise] = Field(default_factory=list, description="List of exercises for this session")
    cool_down: str = Field(default="", description="Post-workout static stretching and cooldown guidance")
    clinical_safety_notes: str = Field(default="", description="Medical or condition-specific safety advice for this day")

class WorkoutPlanResponse(BaseModel):
    plan_name: str = Field(..., description="Personalized plan title (e.g., Clinical Metabolic Conditioning & Muscle Builder)")
    goal_summary: str = Field(..., description="Brief summary of how this plan achieves the user's specific health goals")
    weekly_frequency: str = Field(default="4 Days Workout, 3 Days Rest", description="Weekly split summary")
    medical_considerations: List[str] = Field(default_factory=list, description="Key clinical guidelines applied to this user's profile")
    weekly_schedule: List[WorkoutDay] = Field(..., description="7-day schedule from Monday through Sunday")

class WorkoutPlanRequest(BaseModel):
    user_id: str = Field(..., min_length=1, max_length=128)
    client_profile: Optional[dict] = None
    is_ramadan: Optional[bool] = False
    language: Optional[str] = "en"
