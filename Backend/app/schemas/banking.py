"""Banking-related response schemas."""

from pydantic import BaseModel


class BankingOverviewResponse(BaseModel):
    platform_account_configured: bool = False
    platform_account_institution: str | None = None
    platform_account_transit: str | None = None
    platform_account_last_four: str | None = None
    fund_escrow_total_held_cents: int = 0
    fund_escrow_total_released_cents: int = 0
    fund_escrow_active_count: int = 0
    ticket_escrow_total_held_cents: int = 0
    ticket_escrow_total_released_cents: int = 0
    ticket_escrow_active_count: int = 0
    sponsor_escrow_total_held_cents: int = 0
    sponsor_escrow_total_released_cents: int = 0
    sponsor_escrow_active_count: int = 0
    commission_total_cents: int = 0
    commission_period_cents: int = 0
    commission_by_source: dict = {}
    tax_collected_total_cents: int = 0
    tax_collected_period_cents: int = 0
    payout_pending_count: int = 0
    payout_pending_total_cents: int = 0
    transaction_total_count: int = 0
    transaction_settled_count: int = 0
    transaction_pending_count: int = 0
    transaction_failed_count: int = 0
    disputes_open_count: int = 0
    disputes_total_amount_cents: int = 0
    last_reconciliation_status: str | None = None
    last_reconciliation_delta_cents: int = 0
    mock_mode_active: bool = False
    stripe_enabled: bool = False
    stripe_connect_enabled: bool = False
