"""
HTML email templates for transactional notifications.

All templates return a styled HTML string (inline CSS, mobile-friendly,
Uber-inspired black / white / green accent design).

Each template function accepts an optional ``db`` parameter. When supplied,
the function queries the ``EmailTemplate`` table for a matching
``template_key``. If an active row exists, its ``body_html`` is returned
(with variable substitution). Otherwise the hardcoded template is used.
"""

from __future__ import annotations

import re

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger

_logger = get_logger(__name__)


async def _try_db_template(
    db: AsyncSession | None,
    template_key: str,
    variables: dict[str, str],
) -> str | None:
    """Return rendered HTML from DB template if available, else None."""
    if db is None:
        return None
    try:
        from app.repositories.email_template_repo import email_template_repo

        tmpl = await email_template_repo.get_by_key(db, template_key)
        if tmpl and tmpl.is_active:
            html = tmpl.body_html
            for k, v in variables.items():
                html = html.replace(f"{{{{{k}}}}}", str(v))
            return html
    except Exception:
        _logger.debug("DB template lookup failed for %s, using hardcoded", template_key)
    return None

# ═══════════════════════════════════════════════════════════
# Shared layout wrapper
# ═══════════════════════════════════════════════════════════

_PRIMARY = "#000000"
_ACCENT = "#1DB954"
_ACCENT_LIGHT = "#e8f8ef"
_TEXT = "#333333"
_TEXT_SECONDARY = "#666666"
_BORDER = "#e5e5e5"
_BG = "#f7f7f7"


_branding_cache: dict[str, str] = {}


async def load_branding(db) -> None:
    """Cache email branding from platform settings. Call once per email send batch."""
    from app.services import platform_settings as s
    _branding_cache["logo_url"] = await s.get_str(db, "email_template_logo_url")
    _branding_cache["footer_text"] = await s.get_str(db, "email_template_footer_text")


def _wrap(title: str, body_html: str) -> str:
    """Wrap body content in the standard email shell."""
    logo_url = _branding_cache.get("logo_url", "")
    footer_text = _branding_cache.get(
        "footer_text",
        "You received this email because of your activity on CrowdFund Event.",
    )
    header_content = (
        f'<img src="{logo_url}" alt="CrowdFund Event" style="max-height:40px;margin-bottom:8px;display:block;margin-left:auto;margin-right:auto;"/>'
        if logo_url
        else ""
    ) + '<span style="font-size:20px;font-weight:800;color:#ffffff;letter-spacing:0.5px;">CrowdFund Event</span>'
    return f"""\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>{title}</title>
</head>
<body style="margin:0;padding:0;background:{_BG};font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;color:{_TEXT};-webkit-font-smoothing:antialiased;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{_BG};">
<tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">
  <!-- Header -->
  <tr>
    <td style="background:{_PRIMARY};padding:28px 32px;text-align:center;">
      {header_content}
    </td>
  </tr>
  <!-- Body -->
  <tr>
    <td style="padding:32px 32px 24px;">
      {body_html}
    </td>
  </tr>
  <!-- Footer -->
  <tr>
    <td style="padding:16px 32px 28px;border-top:1px solid {_BORDER};text-align:center;">
      <p style="margin:0;font-size:12px;color:{_TEXT_SECONDARY};">
        {footer_text}<br/>
        Please do not reply to this message.
      </p>
    </td>
  </tr>
</table>
</td></tr>
</table>
</body>
</html>"""


def _heading(text: str) -> str:
    return f'<h1 style="margin:0 0 8px;font-size:22px;font-weight:800;color:{_PRIMARY};">{text}</h1>'


def _subheading(text: str) -> str:
    return f'<p style="margin:0 0 20px;font-size:14px;color:{_TEXT_SECONDARY};">{text}</p>'


def _info_box(html: str, *, color: str = _ACCENT) -> str:
    bg = _ACCENT_LIGHT if color == _ACCENT else "#fff3e0" if color == "#ff9800" else "#fce4ec" if color == "#e53935" else _ACCENT_LIGHT
    return (
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">'
        f'<tr><td style="background:{bg};border-left:4px solid {color};border-radius:8px;padding:16px 18px;">'
        f'{html}'
        f'</td></tr></table>'
    )


def _detail_row(label: str, value: str) -> str:
    return (
        f'<tr>'
        f'<td style="padding:6px 0;font-size:13px;color:{_TEXT_SECONDARY};width:140px;vertical-align:top;">{label}</td>'
        f'<td style="padding:6px 0;font-size:13px;font-weight:600;color:{_TEXT};">{value}</td>'
        f'</tr>'
    )


def _detail_table(rows: list[tuple[str, str]]) -> str:
    inner = "".join(_detail_row(l, v) for l, v in rows)
    return f'<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:12px 0;">{inner}</table>'


def _cents_to_dollars(cents: int) -> str:
    return f"${cents / 100:,.2f}"


def _badge(text: str, *, color: str = _ACCENT) -> str:
    return (
        f'<span style="display:inline-block;background:{color};color:#ffffff;'
        f'font-size:11px;font-weight:700;padding:3px 10px;border-radius:12px;'
        f'letter-spacing:0.3px;">{text}</span>'
    )


# ═══════════════════════════════════════════════════════════
# 1. Event Cancelled (no refund — registrants / ticket buyers)
# ═══════════════════════════════════════════════════════════

async def event_cancelled_template(
    event_title: str,
    reason: str,
    event_date: str | None = None,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "event_cancelled", {
        "event_title": event_title, "reason": reason or "", "event_date": event_date or "",
    })
    if db_html:
        return db_html
    date_row = f"<p style='margin:4px 0;font-size:13px;color:{_TEXT_SECONDARY};'>Event date: {event_date}</p>" if event_date else ""
    body = f"""\
{_heading("Event Cancelled")}
{_subheading("We're sorry to inform you that the following event has been cancelled.")}
{_info_box(f'''
  <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:{_PRIMARY};">{event_title}</p>
  {date_row}
''', color="#e53935")}
<p style="font-size:14px;font-weight:600;margin:16px 0 6px;">Reason for cancellation:</p>
<p style="font-size:14px;color:{_TEXT};margin:0 0 16px;line-height:1.5;">{reason or 'No reason provided.'}</p>
<p style="font-size:13px;color:{_TEXT_SECONDARY};margin:0;">
  If you had a ticket, no further action is needed. Any applicable refunds will be processed separately.
</p>"""
    return _wrap("Event Cancelled", body)


# ═══════════════════════════════════════════════════════════
# 2. Ticket Purchased (receipt email)
# ═══════════════════════════════════════════════════════════

async def ticket_purchased_template(
    event_title: str,
    tier_name: str,
    ticket_code: str,
    receipt_number: str,
    amount_cents: int,
    quantity: int = 1,
    event_date: str | None = None,
    discount_cents: int = 0,
    commission_cents: int = 0,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "ticket_purchased", {
        "event_title": event_title, "tier_name": tier_name, "ticket_code": ticket_code,
        "receipt_number": receipt_number, "amount_cents": str(amount_cents),
        "quantity": str(quantity),
    })
    if db_html:
        return db_html
    is_free = amount_cents == 0
    amount_str = "FREE" if is_free else _cents_to_dollars(amount_cents)
    total_str = "FREE" if is_free else _cents_to_dollars(amount_cents * quantity)

    rows: list[tuple[str, str]] = [
        ("Event", event_title),
        ("Tier", tier_name),
    ]
    if event_date:
        rows.append(("Event Date", event_date))
    rows.append(("Quantity", str(quantity)))
    if quantity > 1:
        rows.append(("Price per Ticket", amount_str))
    rows.append(("Total Paid", total_str))
    if discount_cents > 0:
        rows.append(("Discount Saved", _cents_to_dollars(discount_cents * quantity)))
    if commission_cents > 0:
        rows.append(("Platform Fee", _cents_to_dollars(commission_cents * quantity)))
    rows.append(("Receipt #", receipt_number))
    rows.append(("Ticket Code", ticket_code))

    badge_html = _badge("PURCHASED") if not is_free else _badge("FREE TICKET")

    body = f"""\
{_heading("Ticket Confirmed!")}
{_subheading("Your ticket purchase was successful.")}
{badge_html}
{_detail_table(rows)}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    <strong>Bring your QR code.</strong> Open your ticket in the app to display the QR code for entry.
  </p>
''')}
<p style="font-size:12px;color:{_TEXT_SECONDARY};margin:16px 0 0;">
  You can view your full receipt and QR code in the app under "My Tickets".
</p>"""
    return _wrap("Ticket Purchased", body)


# ═══════════════════════════════════════════════════════════
# 3. Unpledge Refund
# ═══════════════════════════════════════════════════════════

async def unpledge_refund_template(
    event_title: str,
    refunded_cents: int,
    pledges_count: int = 1,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "unpledge_refund", {
        "event_title": event_title, "refunded_cents": str(refunded_cents),
    })
    if db_html:
        return db_html
    body = f"""\
{_heading("Pledge Refunded")}
{_subheading("Your pledge has been successfully refunded.")}
{_detail_table([
    ("Event", event_title),
    ("Pledges Refunded", str(pledges_count)),
    ("Amount Refunded", _cents_to_dollars(refunded_cents)),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    The refund has been processed. It may take a few business days to appear in your account.
  </p>
''')}"""
    return _wrap("Pledge Refunded", body)


# ═══════════════════════════════════════════════════════════
# 4. Unregister Refund
# ═══════════════════════════════════════════════════════════

async def unregister_refund_template(
    event_title: str,
    refunded_cents: int,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "unregister_refund", {
        "event_title": event_title, "refunded_cents": str(refunded_cents),
    })
    if db_html:
        return db_html
    body = f"""\
{_heading("Unregistered & Refunded")}
{_subheading("You have been unregistered from the event and your pledge has been refunded.")}
{_detail_table([
    ("Event", event_title),
    ("Amount Refunded", _cents_to_dollars(refunded_cents)),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    The refund has been processed. It may take a few business days to appear in your account.
  </p>
''')}"""
    return _wrap("Unregistered & Refunded", body)


# ═══════════════════════════════════════════════════════════
# 5. Event Cancelled + Pledge Refund (combined)
# ═══════════════════════════════════════════════════════════

async def cancellation_refund_template(
    event_title: str,
    reason: str,
    refunded_cents: int,
    event_date: str | None = None,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "cancellation_refund", {
        "event_title": event_title, "reason": reason or "",
        "refunded_cents": str(refunded_cents),
    })
    if db_html:
        return db_html
    date_row = f"<p style='margin:4px 0;font-size:13px;color:{_TEXT_SECONDARY};'>Event date: {event_date}</p>" if event_date else ""
    body = f"""\
{_heading("Event Cancelled — Refund Issued")}
{_subheading("The event has been cancelled and your pledge has been refunded.")}
{_info_box(f'''
  <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:{_PRIMARY};">{event_title}</p>
  {date_row}
''', color="#e53935")}
<p style="font-size:14px;font-weight:600;margin:16px 0 6px;">Reason:</p>
<p style="font-size:14px;color:{_TEXT};margin:0 0 16px;line-height:1.5;">{reason or 'No reason provided.'}</p>
{_detail_table([
    ("Refund Amount", _cents_to_dollars(refunded_cents)),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    The refund has been processed. It may take a few business days to appear in your account.
  </p>
''')}"""
    return _wrap("Event Cancelled — Refund", body)


# ═══════════════════════════════════════════════════════════
# 6. Waitlisted Ticket Rejected
# ═══════════════════════════════════════════════════════════

async def waitlist_ticket_rejected_template(
    event_title: str,
    tier_name: str,
    amount_cents: int,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "waitlist_ticket_rejected", {
        "event_title": event_title, "tier_name": tier_name,
    })
    if db_html:
        return db_html
    body = f"""\
{_heading("Ticket Waitlist — Not Approved")}
{_subheading("Unfortunately, your waitlisted ticket was not approved by the organizer.")}
{_detail_table([
    ("Event", event_title),
    ("Tier", tier_name),
    ("Amount", _cents_to_dollars(amount_cents) if amount_cents > 0 else "FREE"),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    If you were charged, a refund will be issued. It may take a few business days to appear in your account.
  </p>
''', color="#ff9800")}
<p style="font-size:13px;color:{_TEXT_SECONDARY};margin:16px 0 0;">
  You can browse other events in the app.
</p>"""
    return _wrap("Ticket Not Approved", body)


# ═══════════════════════════════════════════════════════════
# 7. Ticket Refund Approved
# ═══════════════════════════════════════════════════════════

async def ticket_refund_approved_template(
    event_title: str,
    tier_name: str,
    amount_cents: int,
    receipt_number: str | None = None,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "ticket_refund_approved", {
        "event_title": event_title, "tier_name": tier_name,
    })
    if db_html:
        return db_html
    rows: list[tuple[str, str]] = [
        ("Event", event_title),
        ("Tier", tier_name),
        ("Refund Amount", _cents_to_dollars(amount_cents) if amount_cents > 0 else "FREE"),
    ]
    if receipt_number:
        rows.append(("Receipt #", receipt_number))

    body = f"""\
{_heading("Ticket Refund Approved")}
{_subheading("Your ticket refund request has been approved by the organizer.")}
{_badge("REFUNDED")}
{_detail_table(rows)}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    The refund has been processed. It may take a few business days to appear in your account.
  </p>
''')}"""
    return _wrap("Ticket Refund Approved", body)


# ═══════════════════════════════════════════════════════════
# 8. Waitlisted Ticket Approved
# ═══════════════════════════════════════════════════════════

async def waitlist_ticket_approved_template(
    event_title: str,
    tier_name: str,
    amount_cents: int,
    ticket_code: str | None = None,
    event_date: str | None = None,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "waitlist_ticket_approved", {
        "event_title": event_title, "tier_name": tier_name,
    })
    if db_html:
        return db_html
    rows: list[tuple[str, str]] = [
        ("Event", event_title),
        ("Tier", tier_name),
    ]
    if event_date:
        rows.append(("Event Date", event_date))
    rows.append(("Amount Paid", _cents_to_dollars(amount_cents) if amount_cents > 0 else "FREE"))
    if ticket_code:
        rows.append(("Ticket Code", ticket_code))

    body = f"""\
{_heading("You're In!")}
{_subheading("Great news — your waitlisted ticket has been approved by the organizer.")}
{_badge("APPROVED")}
{_detail_table(rows)}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    <strong>Bring your QR code.</strong> Open your ticket in the app to display the QR code for entry.
  </p>
''')}"""
    return _wrap("Ticket Approved", body)


# ═══════════════════════════════════════════════════════════
# 9. Sponsor Bid Approved
# ═══════════════════════════════════════════════════════════

async def sponsor_bid_approved_template(
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "sponsor_bid_approved", {
        "event_title": event_title, "category_name": category_name,
    })
    if db_html:
        return db_html
    body = f"""\
{_heading("Sponsorship Bid Accepted!")}
{_subheading("The event organizer has accepted your sponsorship bid.")}
{_badge("ACCEPTED")}
{_detail_table([
    ("Event", event_title),
    ("Category", category_name),
    ("Bid Amount", _cents_to_dollars(bid_amount_cents)),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    Please proceed to complete your payment in the app to secure your sponsorship spot.
  </p>
''')}"""
    return _wrap("Bid Accepted", body)


# ═══════════════════════════════════════════════════════════
# 10. Sponsor Bid Rejected
# ═══════════════════════════════════════════════════════════

async def sponsor_bid_rejected_template(
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "sponsor_bid_rejected", {
        "event_title": event_title, "category_name": category_name,
    })
    if db_html:
        return db_html
    body = f"""\
{_heading("Sponsorship Bid Not Accepted")}
{_subheading("Unfortunately, the organizer did not accept your sponsorship bid.")}
{_detail_table([
    ("Event", event_title),
    ("Category", category_name),
    ("Bid Amount", _cents_to_dollars(bid_amount_cents)),
])}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    You can submit a new bid for this or other sponsorship categories.
  </p>
''', color="#ff9800")}
<p style="font-size:13px;color:{_TEXT_SECONDARY};margin:16px 0 0;">
  Browse other sponsorship opportunities in the app.
</p>"""
    return _wrap("Bid Not Accepted", body)


# ═══════════════════════════════════════════════════════════
# 11. Sponsor Payment Refunded
# ═══════════════════════════════════════════════════════════

async def sponsor_refund_template(
    event_title: str,
    category_name: str,
    refunded_cents: int,
    receipt_number: str | None = None,
    db: AsyncSession | None = None,
) -> str:
    db_html = await _try_db_template(db, "sponsor_refund", {
        "event_title": event_title, "category_name": category_name,
    })
    if db_html:
        return db_html
    rows: list[tuple[str, str]] = [
        ("Event", event_title),
        ("Category", category_name),
        ("Refund Amount", _cents_to_dollars(refunded_cents)),
    ]
    if receipt_number:
        rows.append(("Receipt #", receipt_number))

    body = f"""\
{_heading("Sponsorship Refunded")}
{_subheading("Your sponsorship payment has been refunded by the organizer.")}
{_badge("REFUNDED")}
{_detail_table(rows)}
{_info_box(f'''
  <p style="margin:0;font-size:13px;color:{_TEXT};">
    The refund has been processed. It may take a few business days to appear in your account.
  </p>
''')}"""
    return _wrap("Sponsorship Refunded", body)
