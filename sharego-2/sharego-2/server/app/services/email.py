"""Lightweight OTP email sender using Python's built-in smtplib."""
from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

log = logging.getLogger(__name__)


def send_otp_email(
    *,
    to_email: str,
    otp_code: str,
    sender: str,
    smtp_host: str,
    smtp_port: int,
    smtp_user: str | None = None,
    smtp_pass: str | None = None,
) -> bool:
    """Send the OTP code via SMTP. Returns True on success, False on failure.

    Never raises — callers should fall through gracefully if email fails.
    """
    subject = "Your Flyro verification code"
    html_body = f"""\
<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px">
  <h2 style="color:#1DA1A3">Flyro</h2>
  <p>Your one-time verification code is:</p>
  <div style="font-size:32px;font-weight:bold;letter-spacing:8px;
              background:#f5f5f5;padding:16px 24px;border-radius:8px;
              text-align:center;margin:16px 0">{otp_code}</div>
  <p style="color:#666;font-size:13px">
    This code expires in 5 minutes. If you did not request this, ignore this email.
  </p>
</div>"""
    text_body = f"Your Flyro verification code is: {otp_code}\n\nThis code expires in 5 minutes."

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to_email
    msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
            if smtp_user and smtp_pass:
                server.starttls()
                server.login(smtp_user, smtp_pass)
            server.sendmail(sender, [to_email], msg.as_string())
        log.info("OTP email sent to %s", to_email)
        return True
    except Exception:
        log.exception("Failed to send OTP email to %s", to_email)
        return False
