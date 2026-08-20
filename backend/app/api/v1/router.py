from fastapi import APIRouter
from app.api.v1.endpoints import health_profile, meals, profile, coach

api_router = APIRouter()

api_router.include_router(health_profile.router, prefix="/profile", tags=["profile"])
api_router.include_router(profile.router, prefix="/profile", tags=["profile"])
api_router.include_router(meals.router, prefix="/meals", tags=["meals"])
api_router.include_router(coach.router, prefix="/coach", tags=["coach"])
