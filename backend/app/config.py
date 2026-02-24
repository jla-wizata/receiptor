import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str = ""

    # Google Cloud Vision — use file path locally, JSON content in cloud
    google_application_credentials: str = ""  # path to JSON file (local dev)
    google_credentials_json: str = ""          # raw JSON content (cloud deployment)

    # App
    app_env: str = "development"
    secret_key: str = "change-me"


settings = Settings()

# Google client library reads this from os.environ, not from our settings object
if settings.google_application_credentials:
    os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", settings.google_application_credentials)
