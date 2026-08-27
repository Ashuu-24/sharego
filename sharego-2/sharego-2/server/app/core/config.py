from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = Field("Flyro")
    timezone: str = Field("Asia/Karachi")
    currency: str = Field("PKR")
    env: str = Field("dev")
    api_docs_enabled: bool = Field(False)

    db_url: str = Field("sqlite:///./Flyro.db")

    jwt_secret: str = Field("change_me")
    jwt_alg: str = Field("HS256")
    jwt_expire_minutes: int = Field(60)
    jwt_issuer: str | None = Field(None)
    jwt_audience: str | None = Field(None)
    password_min_length: int = Field(8)

    otp_sender_email: str = Field("no-reply@Flyro.local")
    otp_smtp_host: str = Field("localhost")
    otp_smtp_port: int = Field(1025)
    otp_smtp_user: str | None = Field(None)
    otp_smtp_pass: str | None = Field(None)
    otp_resend_seconds: int = Field(30)
    otp_max_attempts: int = Field(3)
    otp_ttl_seconds: int = Field(300)
    otp_bcrypt_rounds: int = Field(12)
    otp_throttle_window_seconds: int = Field(60)
    otp_throttle_limit: int = Field(3)

    media_root: str = Field("./media")
    media_base_url: str = Field("/media")
    static_root: str = Field("./static")
    migration_required_strict: bool = Field(True)
    cors_allowed_origins: str = Field(
        "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173"
    )
    trusted_hosts: str = Field("localhost,127.0.0.1")
    security_headers_enabled: bool = Field(True)

    minio_endpoint: str | None = Field(None)
    minio_access_key: str | None = Field(None)
    minio_secret_key: str | None = Field(None)
    minio_bucket: str | None = Field(None)
    minio_secure: bool = Field(False)

    google_client_id: str | None = Field(None)

    aviationstack_api_key: str | None = Field(None)

    gemini_api_key: str | None = Field(None)
    gemini_model: str = Field("gemini-2.0-flash")
    gemini_rate_limit_per_hour: int = Field(30)

    openai_api_key: str | None = Field(None)
    openai_model: str = Field("gpt-4o-mini")

    nvidia_api_key: str | None = Field(None)
    nvidia_model: str = Field("minimaxai/minimax-m2.5")

    feature_escrow_sim: bool = Field(True)
    feature_ai_readonly: bool = Field(True)
    request_retry_attempts: int = Field(3)
    admin_cookie_name: str = Field("Flyro_admin_access")
    admin_session_minutes: int = Field(480)
    admin_cookie_secure: bool = Field(False)
    admin_cookie_samesite: str = Field("strict")


@lru_cache
def get_settings() -> Settings:
    return Settings()
