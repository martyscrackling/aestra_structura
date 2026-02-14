from __future__ import annotations

import logging
from email.utils import formataddr, parseaddr

from django.conf import settings
from django.core.mail import EmailMessage


logger = logging.getLogger(__name__)


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

    to_email = (to_email or "").strip()
    if not to_email:
        return

    email_backend = getattr(settings, "EMAIL_BACKEND", "")
    if email_backend.endswith("console.EmailBackend"):
        logger.warning(
            "Email backend is console; no real email will be delivered (to=%s role=%s)",
            to_email,
            role,
        )

    smtp_host = getattr(settings, "EMAIL_HOST", "")
    smtp_port = getattr(settings, "EMAIL_PORT", None)
    smtp_tls = getattr(settings, "EMAIL_USE_TLS", None)
    smtp_user = getattr(settings, "EMAIL_HOST_USER", "")

    app_name = getattr(settings, "APP_NAME", "Structura")
    frontend_url = (getattr(settings, "FRONTEND_URL", "") or "").strip().rstrip("/")

    subject = f"You’ve been invited to {app_name}" if app_name else "Invitation"

    invited_by_email = (invited_by_email or "").strip()
    invited_by_name = (invited_by_name or "").strip()
    project_name = (project_name or "").strip()
    first_name = (first_name or "").strip()

    greeting = f"Hi {first_name}," if first_name else "Hi,"

    project_line = ""
    if project_name:
        project_line = f" for the project: {project_name}"

    lines: list[str] = [
        greeting,
        "",
        f"You’ve been invited to join {app_name}{project_line}.",
        "",
        f"Role: {role}",
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
                f"If you weren’t expecting this invitation, you can ignore this email or contact the Project Manager: {contact}.",
            ]
        )

    lines.extend(["", "Thanks,", f"{app_name} Team"])

    message = "\n".join(lines)

    default_from_email = getattr(settings, "DEFAULT_FROM_EMAIL", None)

    # NOTE:
    # - Actual deliverability depends on SMTP provider + DMARC alignment.
    # - Using a dynamic From address (PM's email) often requires OAuth or an allowed alias.
    # - We set the RFC5322 Sender header to the configured default sender so the SMTP
    #   authenticated mailbox remains the sending identity.
    from_email = default_from_email
    sender_header_value = default_from_email

    if invited_by_email and "@" in invited_by_email:
        _, parsed_email = parseaddr(invited_by_email)
        if parsed_email:
            display_name = invited_by_name or parsed_email
            from_email = formataddr((display_name, parsed_email))
        else:
            logger.warning("Invalid invited_by_email for From header: %r", invited_by_email)

    reply_to = [invited_by_email] if invited_by_email else None
    try:
        email = EmailMessage(
            subject=subject,
            body=message,
            from_email=from_email,
            to=[to_email],
            reply_to=reply_to,
            headers={"Sender": sender_header_value} if sender_header_value else None,
        )
        sent_count = email.send(fail_silently=False)
        logger.info(
            "Invitation email send result=%s to=%s subject=%r from=%r sender=%r reply_to=%r",
            sent_count,
            to_email,
            subject,
            from_email,
            sender_header_value,
            reply_to,
        )
    except Exception:
        # Never fail account creation because email failed.
        logger.exception(
            "Failed sending invitation email (to=%s role=%s subject=%r from=%r sender=%r reply_to=%r smtp_host=%r smtp_port=%r smtp_tls=%r smtp_user=%r backend=%r)",
            to_email,
            role,
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

        # Some SMTP providers (including Gmail) may reject or rewrite messages if the
        # From address is not aligned with the authenticated sender. If we attempted
        # to send "From=PM" and it failed, retry with the configured default sender.
        if default_from_email and from_email != default_from_email:
            try:
                fallback = EmailMessage(
                    subject=subject,
                    body=message,
                    from_email=default_from_email,
                    to=[to_email],
                    reply_to=reply_to,
                )
                sent_count = fallback.send(fail_silently=False)
                logger.info(
                    "Invitation email fallback send result=%s to=%s subject=%r from=%r reply_to=%r",
                    sent_count,
                    to_email,
                    subject,
                    default_from_email,
                    reply_to,
                )
            except Exception:
                logger.exception(
                    "Invitation email fallback also failed (to=%s role=%s subject=%r from=%r reply_to=%r smtp_host=%r smtp_port=%r smtp_tls=%r smtp_user=%r backend=%r)",
                    to_email,
                    role,
                    subject,
                    default_from_email,
                    reply_to,
                    smtp_host,
                    smtp_port,
                    smtp_tls,
                    smtp_user,
                    email_backend,
                )
        return
