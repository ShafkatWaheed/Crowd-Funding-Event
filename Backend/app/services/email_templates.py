"""
HTML email templates for transactional notifications.

All templates return a styled HTML string (inline CSS, mobile-friendly,
Uber-inspired black / white / green accent design).
"""

from __future__ import annotations

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


def _wrap(title: str, body_html: str) -> str:
    """Wrap body content in the standard email shell."""
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
      <span style="font-size:20px;font-weight:800;color:#ffffff;letter-spacing:0.5px;">CrowdFund Event</span>
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
        You received this email because of your activity on CrowdFund Event.<br/>
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

def event_cancelled_template(
    event_title: str,
    reason: str,
    event_date: str | None = None,
) -> str:
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

def ticket_purchased_template(
    event_title: str,
    tier_name: str,
    ticket_code: str,
    receipt_number: str,
    amount_cents: int,
    quantity: int = 1,
    event_date: str | None = None,
    discount_cents: int = 0,
    commission_cents: int = 0,
) -> str:
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

def unpledge_refund_template(
    event_title: str,
    refunded_cents: int,
    pledges_count: int = 1,
) -> str:
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

def unregister_refund_template(
    event_title: str,
    refunded_cents: int,
) -> str:
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

def cancellation_refund_template(
    event_title: str,
    reason: str,
    refunded_cents: int,
    event_date: str | None = None,
) -> str:
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

def waitlist_ticket_rejected_template(
    event_title: str,
    tier_name: str,
    amount_cents: int,
) -> str:
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
