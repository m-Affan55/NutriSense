from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "AI Nutrition Coach API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    USDA_API_KEY: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_API_KEY_01: Optional[str] = None
    GEMINI_API_KEY_02: Optional[str] = None
    GEMINI_API_KEY_03: Optional[str] = None
    GEMINI_CHAT_API_KEY: Optional[str] = None
    GEMINI_API_KEYS: Optional[str] = None
    ELEVENLABS_API_KEY: Optional[str] = None
    
    def get_gemini_keys(self) -> List[str]:
        """
        Returns deduplicated list of Gemini API keys.
        GEMINI_API_KEY (primary) is listed first for highest pool priority.
        """
        keys = []

        def _add(k: Optional[str]) -> None:
            if k and k.strip() and k.strip() not in keys:
                keys.append(k.strip())

        # Primary key first — highest pool priority
        _add(self.GEMINI_API_KEY)
        # Numbered rotation keys
        _add(self.GEMINI_API_KEY_01)
        _add(self.GEMINI_API_KEY_02)
        _add(self.GEMINI_API_KEY_03)
        # Chat-specific key
        _add(self.GEMINI_CHAT_API_KEY)
        # Comma-separated bulk key list (lowest priority)
        if self.GEMINI_API_KEYS:
            for k in self.GEMINI_API_KEYS.split(','):
                _add(k)

        return keys if keys else [""]
    
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()

