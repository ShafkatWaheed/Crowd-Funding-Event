import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/receipt.dart';
import '../../../models/ticket.dart';
import '../../../utils/date_time_utils.dart';
import '../../../providers/ticket_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/loading_switcher.dart';
import '../../../widgets/shimmer_loaders.dart';

/// Beautiful ticket receipt screen.
/// Pass [eventId] + [saleId] to load via event route,
/// or [saleId] alone to load via /me/tickets/{saleId}/receipt.
///
/// When [showBuyAgain] is true, a "Buy Another Ticket" button is shown at the
/// bottom of the receipt. The [onBuyAgain] callback is invoked when tapped.
class TicketReceiptScreen extends StatefulWidget {
  final int? eventId;
  final int saleId;
  final bool showBuyAgain;
  final VoidCallback? onBuyAgain;
  final bool isOrganizer;
  final TicketSale? offlineTicket;

  const TicketReceiptScreen({
    super.key,
    this.eventId,
    required this.saleId,
    this.showBuyAgain = false,
    this.onBuyAgain,
    this.isOrganizer = false,
    this.offlineTicket,
  });

  @override
  State<TicketReceiptScreen> createState() => _TicketReceiptScreenState();
}

class _TicketReceiptScreenState extends State<TicketReceiptScreen> {
  TicketReceipt? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isOffline => widget.offlineTicket != null;

  Future<void> _load() async {
    // Build receipt from cached offline ticket (no API needed)
    if (widget.offlineTicket != null) {
      final t = widget.offlineTicket!;
      setState(() {
        _receipt = TicketReceipt(
          saleId: t.id,
          eventId: t.eventId,
          userId: t.userId,
          receiptNumber: t.receiptNumber ?? '',
          ticketCode: t.ticketCode,
          status: t.status,
          tierName: t.tierName ?? '',
          eventTitle: t.eventTitle ?? 'Event #${t.eventId}',
          amountPaidCents: t.amountPaidCents,
          discountAppliedCents: t.discountAppliedCents,
          tierPriceCents: t.amountPaidCents + t.discountAppliedCents,
          purchasedAt: t.createdAt,
          scannedAt: t.scannedAt,
          encryptedQrPayload: t.encryptedQrPayload,
        );
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<TicketProvider>();
      final data = widget.eventId != null
          ? await repo.getTicketReceipt(widget.eventId!, widget.saleId)
          : await repo.getMyTicketReceipt(widget.saleId);
      if (mounted) setState(() { _receipt = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiError.extractMessage(e, fallback: 'Failed to load receipt');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Receipt'),
      ),
      body: LoadingSwitcher(
        loading: _loading,
        loadingChild: const Center(child: ShimmerReceiptCard()),
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            : _receipt != null
                ? _buildReceipt()
                : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _requestRefund() async {
    final r = _receipt!;
    final receiptNumber = r.receiptNumber;
    final amountCents = r.amountPaidCents;
    final amountStr = '\$${(amountCents / 100).toStringAsFixed(2)}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Refund'),
        content: Text(
          'Request a refund for ticket $receiptNumber ($amountStr)?\n\n'
          'The organizer will review your request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Request Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = context.read<TicketProvider>();
      await repo.requestTicketRefund(widget.eventId!, widget.saleId);
      if (mounted) {
        AppToast.success(context, 'Refund request sent to organizer');
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Refund request failed');
      }
    }
  }

  Widget _buildReceipt() {
    final r = _receipt!;
    final receiptNumber = r.receiptNumber;
    final ticketCode = r.ticketCode;
    final status = r.status;
    final saleId = r.saleId;
    final userId = r.userId;
    final attendeeName = r.attendeeName ?? 'Unknown';
    final eventTitle = r.eventTitle;
    final eventStartTime = r.eventStartTime?.toLocal();
    final eventEndTime = r.eventEndTime?.toLocal();
    final organizerName = r.organizerName;
    final organizerEmail = r.organizerEmail;
    final organizerPhone = r.organizerPhone;
    final venueName = r.venueName;
    final venueAddress = r.venueAddress;
    final tierName = r.tierName;
    final tierPriceCents = r.tierPriceCents;
    final amountPaidCents = r.amountPaidCents;
    final discountCents = r.discountAppliedCents;
    final commissionCents = r.commissionCents;
    final purchasedAt = r.purchasedAt.toLocal();
    final scannedAt = r.scannedAt?.toLocal();
    final extraPerks = r.extraPerks;

    final isFree = amountPaidCents == 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
        children: [
          // ── Receipt Card ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text('Purchase Receipt',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(receiptNumber,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(context, status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Dashed divider ──
                Container(
                  width: double.infinity,
                  height: 1,
                  color: AppTheme.dividerOf(context),
                ),

                // ── Body ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event info
                      _sectionLabel('EVENT'),
                      const SizedBox(height: 8),
                      Text(eventTitle,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      if (eventStartTime != null) ...[
                        const SizedBox(height: 6),
                        _iconRow(context, Icons.calendar_today_rounded,
                            AppDateFormat.fullDateTime(eventStartTime)),
                      ],
                      if (eventEndTime != null) ...[
                        const SizedBox(height: 4),
                        _iconRow(context, Icons.schedule_rounded,
                            'Ends ${AppDateFormat.fullDateTime(eventEndTime)}'),
                      ],
                      if (venueName != null) ...[
                        const SizedBox(height: 4),
                        _iconRow(context, Icons.location_on_outlined, venueName),
                      ],
                      if (venueAddress != null) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(venueAddress,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Organizer
                      if (organizerName != null) ...[
                        _sectionLabel('ORGANIZER'),
                        const SizedBox(height: 8),
                        _detailRow(context, 'Name', organizerName),
                        if (organizerEmail != null && organizerEmail.isNotEmpty)
                          _detailRow(context, 'Email', organizerEmail),
                        if (organizerPhone != null && organizerPhone.isNotEmpty)
                          _detailRow(context, 'Phone', organizerPhone),
                        const SizedBox(height: 20),
                      ],

                      // Attendee
                      _sectionLabel('ATTENDEE'),
                      const SizedBox(height: 8),
                      _detailRow(context, 'Name', attendeeName),

                      const SizedBox(height: 20),

                      // Ticket info
                      _sectionLabel('TICKET'),
                      const SizedBox(height: 8),
                      _detailRow(context, 'Tier', tierName),
                      _detailRow(context, 'Ticket Code', ticketCode, copyable: !widget.isOrganizer),
                      _detailRow(context, 'Purchased', AppDateFormat.fullDateTime(purchasedAt)),
                      if (scannedAt != null)
                        _detailRow(context, 'Scanned', AppDateFormat.fullDateTime(scannedAt)),
                      if (extraPerks != null && extraPerks.toString().isNotEmpty)
                        _detailRow(context, 'Extra Perks', extraPerks.toString()),

                      if (!widget.isOrganizer) ...[
                        const SizedBox(height: 20),

                        // QR Code
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardOf(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.dividerOf(context)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: r.encryptedQrPayload ?? jsonEncode({
                                    'receipt_number': receiptNumber,
                                    'event_id': r.eventId,
                                    'user_id': userId,
                                    'sale_id': saleId,
                                    'ticket_code': ticketCode,
                                  }),
                                  version: QrVersions.auto,
                                  size: 160,
                                  gapless: true,
                                  eyeStyle: QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  dataModuleStyle: QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Scan for entry',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryOf(context),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Payment breakdown
                      _sectionLabel('PAYMENT'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _priceRow(context, 'Ticket Price',
                                _formatCents(tierPriceCents)),
                            if (discountCents > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(context, 'Discount',
                                  '-${_formatCents(discountCents)}',
                                  valueColor: AppTheme.successColor),
                            ],
                            if (commissionCents > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(context, 'Platform Fee',
                                  _formatCents(commissionCents),
                                  valueColor: AppTheme.textSecondaryOf(context)),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              height: 1,
                              color: AppTheme.dividerOf(context),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Paid',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppTheme.textPrimaryOf(context))),
                                Text(
                                  isFree
                                      ? 'FREE'
                                      : _formatCents(amountPaidCents),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.5,
                                    color: isFree
                                        ? AppTheme.successColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 16, color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This receipt is generated automatically upon ticket purchase. '
                          'Keep your ticket code safe for event entry.',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Offline indicator ──
          if (_isOffline) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing cached receipt — you are offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Request Refund link (customer-only, purchased + unscanned, online only) ──
          if (!_isOffline &&
              !widget.isOrganizer &&
              status == 'purchased' &&
              scannedAt == null &&
              widget.eventId != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _requestRefund,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondaryOf(context),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Request Refund'),
              ),
            ),
          ],

          // ── Buy Another Ticket button ──
          if (widget.showBuyAgain) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.onBuyAgain != null) {
                    Navigator.of(context).pop();
                    widget.onBuyAgain!();
                  }
                },
                icon: const Icon(Icons.confirmation_number_rounded),
                label: const Text('Buy Another Ticket',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.ticketAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }

  // ── Helpers ──

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentColor,
            letterSpacing: 1.2));
  }

  Widget _iconRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
        ),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context))),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                AppToast.info(context, 'Copied to clipboard');
              },
              child: Icon(Icons.copy_rounded, size: 15, color: AppTheme.textSecondaryOf(context)),
            ),
        ],
      ),
    );
  }

  Widget _priceRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimaryOf(context))),
      ],
    );
  }

  String _formatCents(int cents) =>
      '\$${(cents / 100).toStringAsFixed(2)}';

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'purchased':
        return AppTheme.successColor;
      case 'waitlisted':
        return AppTheme.warningColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondaryOf(context);
    }
  }
}
