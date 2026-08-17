from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "AI Nutrition Coach API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Database connection string
    # DATABASE_URL: str = "postgresql://user:password@localhost:5432/db_name"
    
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

settings = Settings()
