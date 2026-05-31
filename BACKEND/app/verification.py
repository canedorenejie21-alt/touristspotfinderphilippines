from datetime import datetime, timedelta
import hashlib
import secrets

from sqlalchemy.orm import Session

from .config import get_settings
from .emailer import send_password_reset_email, send_verification_email
from .models import EmailVerificationCode, PasswordResetCode, User


def generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_code(code: str) -> str:
    settings = get_settings()
    return hashlib.sha256(f"{settings.secret_key}:{code}".encode("utf-8")).hexdigest()


def create_and_send_verification_code(db: Session, user: User) -> None:
    code = generate_code()
    expires_at = datetime.utcnow() + timedelta(minutes=get_settings().otp_expiry_minutes)

    db.query(EmailVerificationCode).filter(
        EmailVerificationCode.user_id == user.id,
        EmailVerificationCode.used_at.is_(None),
    ).delete()
    db.add(
        EmailVerificationCode(
            user_id=user.id,
            code_hash=hash_code(code),
            expires_at=expires_at,
        )
    )
    db.commit()

    send_verification_email(user.email, code)


def create_and_send_password_reset_code(db: Session, user: User) -> None:
    code = generate_code()
    expires_at = datetime.utcnow() + timedelta(minutes=get_settings().otp_expiry_minutes)

    db.query(PasswordResetCode).filter(
        PasswordResetCode.user_id == user.id,
        PasswordResetCode.used_at.is_(None),
    ).delete()
    db.add(
        PasswordResetCode(
            user_id=user.id,
            code_hash=hash_code(code),
            expires_at=expires_at,
        )
    )
    db.commit()

    send_password_reset_email(user.email, code)
