from __future__ import annotations

import logging
import json
import os
import threading
from email.utils import formataddr, parseaddr
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from django.conf import settings
from django.core.mail import EmailMessage


logger = logging.getLogger(__name__)


def _display_name_or_email(*, name: str | None, email: str | None) -> str:
    name = (name or "").strip()
    email = (email or "").strip()
    if name:
        return name
    if email:
        return email
    return "Project Manager"


def _pm_sentence(*, pm_display: str, role: str, project_name: str, app_name: str) -> str:
    pm_display = (pm_display or "Project Manager").strip()
    role = (role or "").strip()
    project_name = (project_name or "").strip()
    app_name = (app_name or "Structura").strip()

    if project_name:
        # Requested wording:
        # "(Name of the Project Manager) added you as (Role) in the (Project Name) as Structura Construction Corp"
        return f"{pm_display} added you as {role} in the {project_name} as {app_name}."

    return f"{pm_display} added you as {role} in {app_name}."


def _send_email_best_effort(
    *,
    to_email: str,
    subject: str,
    message: str,
    invited_by_email: str | None = None,
    invited_by_name: str | None = None,
) -> None:
    to_email = (to_email or "").strip()
    if not to_email:
        return

    email_backend = getattr(settings, "EMAIL_BACKEND", "")
    if email_backend.endswith("console.EmailBackend"):
        logger.warning("Email backend is console; no real email will be delivered (to=%s)", to_email)

    smtp_host = getattr(settings, "EMAIL_HOST", "")
    smtp_port = getattr(settings, "EMAIL_PORT", None)
    smtp_tls = getattr(settings, "EMAIL_USE_TLS", None)
    smtp_user = getattr(settings, "EMAIL_HOST_USER", "")

    invited_by_email = (invited_by_email or "").strip()
    invited_by_name = (invited_by_name or "").strip()
    reply_to = [invited_by_email] if invited_by_email else None

    default_from_email = getattr(settings, "DEFAULT_FROM_EMAIL", None)
    sendgrid_key = (getattr(settings, "SENDGRID_API_KEY", "") or "").strip()
    sendgrid_from_override = (getattr(settings, "SENDGRID_FROM_EMAIL", "") or "").strip()

    from_email = default_from_email
    sender_header_value = default_from_email

    if invited_by_email and "@" in invited_by_email:
        _, parsed_email = parseaddr(invited_by_email)
        if parsed_email:
            display_name = invited_by_name or parsed_email
            from_email = formataddr((display_name, parsed_email))
        else:
            logger.warning("Invalid invited_by_email for From header: %r", invited_by_email)

    def _send_attempt(*, attempt_from: str | None, attempt_sender: str | None) -> None:
        if sendgrid_key:
            from_for_sendgrid = sendgrid_from_override or attempt_from or default_from_email
            status = _send_via_sendgrid(
                api_key=sendgrid_key,
                subject=subject,
                message=message,
                to_email=to_email,
                from_email=from_for_sendgrid,
                reply_to=reply_to,
            )
            logger.info(
                "Email sendgrid status=%s to=%s subject=%r from=%r reply_to=%r",
                status,
                to_email,
                subject,
                from_for_sendgrid,
                reply_to,
            )
            return

        email = EmailMessage(
            subject=subject,
            body=message,
            from_email=attempt_from,
            to=[to_email],
            reply_to=reply_to,
            headers={"Sender": attempt_sender} if attempt_sender else None,
        )
        sent_count = email.send(fail_silently=False)
        logger.info(
            "Email send result=%s to=%s subject=%r from=%r sender=%r reply_to=%r",
            sent_count,
            to_email,
            subject,
            attempt_from,
            attempt_sender,
            reply_to,
        )

    def _send_background() -> None:
        try:
            _send_attempt(attempt_from=from_email, attempt_sender=sender_header_value)
            return
        except Exception:
            logger.exception(
                "Failed sending email (to=%s subject=%r from=%r sender=%r reply_to=%r smtp_host=%r smtp_port=%r smtp_tls=%r smtp_user=%r backend=%r)",
                to_email,
                subject,
                from_email,
                sender_header_value,
                reply_to,
                smtp_host,
                smtp_port,
                smtp_tls,
                smtp_user,
                email_backend,
            )

        if default_from_email and from_email != default_from_email:
            try:
                _send_attempt(attempt_from=default_from_email, attempt_sender=None)
            except Exception:
                logger.exception(
                    "Email fallback also failed (to=%s subject=%r from=%r reply_to=%r smtp_host=%r smtp_port=%r smtp_tls=%r smtp_user=%r backend=%r)",
                    to_email,
                    subject,
                    default_from_email,
                    reply_to,
                    smtp_host,
                    smtp_port,
                    smtp_tls,
                    smtp_user,
                    email_backend,
                )

    threading.Thread(target=_send_background, daemon=True).start()


def _send_via_sendgrid(
    *,
    api_key: str,
    subject: str,
    message: str,
    to_email: str,
    from_email: str | None,
    reply_to: list[str] | None,
) -> int:
    """Send using SendGrid v3 API. Returns HTTP status code (202 means accepted)."""

    from_name, from_addr = parseaddr(from_email or "")
    if not from_addr:
        # Fallback to env var if DEFAULT_FROM_EMAIL isn't a real address.
        from_name, from_addr = parseaddr(os.getenv("SENDGRID_FROM_EMAIL", ""))

    if not from_addr:
        raise ValueError("SendGrid from_email is not configured")

    payload: dict = {
        "personalizations": [{"to": [{"email": to_email}], "subject": subject}],
        "from": {"email": from_addr},
        "content": [{"type": "text/plain", "value": message}],
    }
    if from_name:
        payload["from"]["name"] = from_name

    if reply_to and reply_to[0]:
        payload["reply_to"] = {"email": reply_to[0]}

    body = json.dumps(payload).encode("utf-8")
    req = Request(
        "https://api.sendgrid.com/v3/mail/send",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urlopen(req, timeout=20) as resp:
            return int(getattr(resp, "status", 0) or 0)
    except HTTPError as e:
        # Consume body for better logs.
        try:
            details = e.read().decode("utf-8", errors="replace")
        except Exception:
            details = "<unable to read body>"
        raise RuntimeError(f"SendGrid HTTPError {e.code}: {details}")
    except URLError as e:
        raise RuntimeError(f"SendGrid URLError: {e}")


def send_invitation_email(
    *,
    to_email: str,
    first_name: str | None = None,
    role: str,
    temp_password: str,
    invited_by_email: str | None = None,
    invited_by_name: str | None = None,
    project_name: str | None = None,
) -> None:
    """Send a simple invitation email (best-effort).

    This does not block account creation. Configure SMTP using Django EMAIL_* settings.
    """

    app_name = getattr(settings, "APP_NAME", "Structura")
    frontend_url = (getattr(settings, "FRONTEND_URL", "") or "").strip().rstrip("/")

    subject = f"You were added to {app_name}" if app_name else "Invitation"

    invited_by_email = (invited_by_email or "").strip()
    invited_by_name = (invited_by_name or "").strip()
    project_name = (project_name or "").strip()
    first_name = (first_name or "").strip()

    greeting = f"Hi {first_name}," if first_name else "Hi,"

    pm_display = _display_name_or_email(name=invited_by_name, email=invited_by_email)
    added_sentence = _pm_sentence(
        pm_display=pm_display,
        role=role,
        project_name=project_name,
        app_name=app_name,
    )

    lines: list[str] = [
        greeting,
        "",
        added_sentence,
        "",
        f"Email: {to_email}",
        f"Temporary password: {temp_password}",
    ]

    if frontend_url:
        lines.extend(["", f"Login here: {frontend_url}/login"])

    lines.extend(
        [
            "",
            "After logging in, please change your password right away (Settings → Change Password).",
        ]
    )

    if invited_by_email or invited_by_name:
        pm_name = invited_by_name or "Project Manager"
        pm_email = invited_by_email
        contact = f"{pm_name} ({pm_email})" if pm_email else pm_name
        lines.extend(
            [
                "",
                f"If you weren’t expecting this, you can ignore this email or contact the Project Manager: {contact}.",
            ]
        )

    lines.extend(["", "Thanks,", f"{app_name} Team"])

    message = "\n".join(lines)
    _send_email_best_effort(
        to_email=to_email,
        subject=subject,
        message=message,
        invited_by_email=invited_by_email,
        invited_by_name=invited_by_name,
    )


def send_project_assignment_email(
    *,
    to_email: str,
    first_name: str | None = None,
    role: str,
    invited_by_email: str | None = None,
    invited_by_name: str | None = None,
    project_name: str | None = None,
) -> None:
    """Send an email when an existing account is assigned to a project."""

    app_name = getattr(settings, "APP_NAME", "Structura")
    frontend_url = (getattr(settings, "FRONTEND_URL", "") or "").strip().rstrip("/")

    invited_by_email = (invited_by_email or "").strip()
    invited_by_name = (invited_by_name or "").strip()
    project_name = (project_name or "").strip()
    first_name = (first_name or "").strip()

    pm_display = _display_name_or_email(name=invited_by_name, email=invited_by_email)
    added_sentence = _pm_sentence(
        pm_display=pm_display,
        role=role,
        project_name=project_name,
        app_name=app_name,
    )

    subject_project = f" ({project_name})" if project_name else ""
    subject = f"Project assignment{subject_project}" if app_name else "Project assignment"

    greeting = f"Hi {first_name}," if first_name else "Hi,"
    lines: list[str] = [
        greeting,
        "",
        added_sentence,
    ]

    if frontend_url:
        lines.extend(["", f"Login here: {frontend_url}/login"])

    lines.extend(["", "Thanks,", f"{app_name} Team"])
    message = "\n".join(lines)

    _send_email_best_effort(
        to_email=to_email,
        subject=subject,
        message=message,
        invited_by_email=invited_by_email,
        invited_by_name=invited_by_name,
    )
    return


def send_signup_otp_email(*, to_email: str, otp_code: str) -> None:
    """Send signup OTP email in a best-effort background thread."""
    app_name = getattr(settings, "APP_NAME", "Structura")
    subject = f"{app_name} signup verification code"
    message = "\n".join(
        [
            "Hi,",
            "",
            f"Your verification code is: {otp_code}",
            "",
            "This code expires in 10 minutes.",
            "If you did not request this code, you can ignore this email.",
            "",
            f"{app_name} Team",
        ]
    )
    _send_email_best_effort(
        to_email=to_email,
        subject=subject,
        message=message,
    )

