from functools import lru_cache
from os import getenv

from dotenv import load_dotenv

load_dotenv()


class Settings:
    def __init__(self) -> None:
        self.database_url = getenv("DATABASE_URL", "sqlite:///./tourist_spot_finder.db")
        self.secret_key = getenv("APP_SECRET_KEY", "dev-secret-key")
        origins = getenv(
            "FRONTEND_ORIGINS",
            "http://localhost:8080,http://127.0.0.1:8080",
        )
        self.frontend_origins = [origin.strip() for origin in origins.split(",") if origin.strip()]
        self.smtp_host = getenv("SMTP_HOST", "")
        self.smtp_port = int(getenv("SMTP_PORT", "587"))
        self.smtp_username = getenv("SMTP_USERNAME", "")
        self.smtp_password = getenv("SMTP_PASSWORD", "")
        self.smtp_from_email = getenv("SMTP_FROM_EMAIL", self.smtp_username)
        self.otp_expiry_minutes = int(getenv("OTP_EXPIRY_MINUTES", "10"))
        self.require_email_verification = getenv("REQUIRE_EMAIL_VERIFICATION", "false").lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
        self.admin_key = getenv("ADMIN_KEY", "tourist-admin-123")
        admin_emails = getenv("ADMIN_EMAILS", "")
        self.admin_emails = {
            email.strip().lower() for email in admin_emails.split(",") if email.strip()
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
