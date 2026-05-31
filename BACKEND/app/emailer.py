from email.message import EmailMessage
import smtplib

from .config import get_settings


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

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as server:
        server.starttls()
        server.login(settings.smtp_username, settings.smtp_password)
        server.send_message(message)
