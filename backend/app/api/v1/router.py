from fastapi import APIRouter
from app.api.v1.endpoints import health_profile

api_router = APIRouter()

api_router.include_router(health_profile.router, prefix="/profile", tags=["profile"])
