import smtplib
from email.message import EmailMessage
import logging

from .config import get_settings

logger = logging.getLogger(__name__)


def send_verification_email(to_email: str, code: str) -> None:
    send_code_email(
        to_email=to_email,
        subject="Tourist Spot Finder PH verification code",
        intro="Your Tourist Spot Finder PH verification code is:",
        code=code,
    )


def send_password_reset_email(to_email: str, code: str) -> None:
    send_code_email(
        to_email=to_email,
        subject="Tourist Spot Finder PH password reset code",
        intro="Your password reset code is:",
        code=code,
    )


def send_code_email(to_email: str, subject: str, intro: str, code: str) -> None:
    settings = get_settings()
    if not settings.smtp_host or not settings.smtp_username or not settings.smtp_password:
        raise RuntimeError("SMTP is not configured")

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.smtp_from_email
    message["To"] = to_email
    message.set_content(
        "\n".join(
            [
                intro,
                "",
                code,
                "",
                f"This code expires in {settings.otp_expiry_minutes} minutes.",
            ]
        )
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(settings.smtp_username, settings.smtp_password)
            server.send_message(message)
    except (OSError, smtplib.SMTPException) as exc:
        logger.exception(
            "SMTP failed: host=%s port=%s username=%s from=%s to=%s error=%s",
            settings.smtp_host,
            settings.smtp_port,
            settings.smtp_username,
            settings.smtp_from_email,
            to_email,
            exc,
        )
        raise RuntimeError("SMTP failed to send email") from exc
