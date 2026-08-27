from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "AI Nutrition Coach API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_API_KEY_01: Optional[str] = None
    GEMINI_API_KEY_02: Optional[str] = None
    GEMINI_API_KEY_03: Optional[str] = None
    GEMINI_CHAT_API_KEY: Optional[str] = None
    GEMINI_API_KEYS: Optional[str] = None
    ELEVENLABS_API_KEY: Optional[str] = None
    
    def get_gemini_keys(self) -> List[str]:
        keys = []
        candidates = [
            self.GEMINI_API_KEY_01,
            self.GEMINI_API_KEY_02,
            self.GEMINI_API_KEY_03,
            self.GEMINI_CHAT_API_KEY,
        ]
        for candidate in candidates:
            if candidate and candidate.strip() and candidate.strip() not in keys:
                keys.append(candidate.strip())
        if self.GEMINI_API_KEYS:
            for k in self.GEMINI_API_KEYS.split(','):
                if k.strip() and k.strip() not in keys:
                    keys.append(k.strip())
        if self.GEMINI_API_KEY and self.GEMINI_API_KEY.strip() and self.GEMINI_API_KEY.strip() not in keys:
            keys.append(self.GEMINI_API_KEY.strip())
        return keys if keys else [""]
    
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()

