import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../utils/date_time_utils.dart';

import '../../config/theme.dart';
import '../../repositories/ticket_repository.dart';
import '../../repositories/base_repository.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import 'ticket_receipt_screen.dart';

/// Aggregated receipt for a multi-ticket purchase group.
/// Shows purchase summary and individual ticket cards with QR codes.
class PurchaseGroupReceiptScreen extends StatefulWidget {
  final int eventId;
  final String purchaseGroupId;
  final bool showBuyAgain;
  final VoidCallback? onBuyAgain;

  const PurchaseGroupReceiptScreen({
    super.key,
    required this.eventId,
    required this.purchaseGroupId,
    this.showBuyAgain = false,
    this.onBuyAgain,
  });

  @override
  State<PurchaseGroupReceiptScreen> createState() =>
      _PurchaseGroupReceiptScreenState();
}

class _PurchaseGroupReceiptScreenState
    extends State<PurchaseGroupReceiptScreen> {
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<TicketRepository>();
      final data = await repo.getPurchaseGroupReceipt(
          widget.eventId, widget.purchaseGroupId);
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
        title: const Text('Purchase Receipt'),
      ),
      body: _loading
          ? const Center(child: ShimmerReceiptCard())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildReceipt(),
    );
  }

  Widget _buildReceipt() {
    final r = _receipt!;
    final eventTitle = r['event_title'] ?? 'Unknown Event';
    final quantity = (r['quantity'] ?? 1) as int;
    final tierName = r['tier_name'] ?? '';
    final tierPriceCents = (r['tier_price_cents'] ?? 0) as int;
    final totalAmountPaid = (r['total_amount_paid_cents'] ?? 0) as int;
    final totalDiscount = (r['total_discount_applied_cents'] ?? 0) as int;
    final totalCommission = (r['total_commission_cents'] ?? 0) as int;
    final totalTax = (r['total_tax_cents'] ?? 0) as int;
    final taxRate = (r['tax_rate'] ?? 0.0) as num;
    final taxJurisdiction = r['tax_jurisdiction'] as String?;
    final purchasedAt = r['purchased_at'] != null
        ? DateTime.parse(r['purchased_at']).toLocal()
        : null;
    final eventStartTime = r['event_start_time'] != null
        ? DateTime.parse(r['event_start_time']).toLocal()
        : null;
    final eventEndTime = r['event_end_time'] != null
        ? DateTime.parse(r['event_end_time']).toLocal()
        : null;
    final organizerName = r['organizer_name'];
    final organizerEmail = r['organizer_email'];
    final organizerPhone = r['organizer_phone'];
    final venueName = r['venue_name'];
    final venueAddress = r['venue_address'];
    final attendeeName = r['attendee_name'] ?? 'Unknown';
    final tickets = (r['tickets'] as List? ?? []);
    final isFree = totalAmountPaid == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // ── Summary Card ──
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
                // Header
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
                        width: 56, height: 56,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$quantity ticket${quantity == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: double.infinity, height: 1,
                    color: AppTheme.dividerOf(context)),

                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('EVENT'),
                      const SizedBox(height: 8),
                      Text(eventTitle,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context))),
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

                            if (organizerName != null) ...[
                        _sectionLabel('ORGANIZER'),
                        const SizedBox(height: 8),
                        _detailRow(context, 'Name', organizerName),
                        if (organizerEmail != null &&
                            organizerEmail.toString().isNotEmpty)
                          _detailRow(context, 'Email', organizerEmail),
                        if (organizerPhone != null &&
                            organizerPhone.toString().isNotEmpty)
                          _detailRow(context, 'Phone', organizerPhone),
                        const SizedBox(height: 20),
                      ],

                      _sectionLabel('ATTENDEE'),
                      const SizedBox(height: 8),
                      _detailRow(context, 'Name', attendeeName),

                      const SizedBox(height: 20),

                      _sectionLabel('PURCHASE SUMMARY'),
                      const SizedBox(height: 8),
                      _detailRow(context, 'Tier', tierName),
                      _detailRow(context, 'Quantity', '$quantity'),
                      if (purchasedAt != null)
                        _detailRow(context, 'Purchased', AppDateFormat.fullDateTime(purchasedAt)),

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
                            _priceRow(context, 'Ticket Price (each)',
                                _formatCents(tierPriceCents)),
                            const SizedBox(height: 4),
                            _priceRow(context, 'x Quantity', '$quantity'),
                            if (totalDiscount > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(context, 'Total Discount',
                                  '-${_formatCents(totalDiscount)}',
                                  valueColor: AppTheme.successColor),
                            ],
                            if (totalCommission > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(context, 'Platform Fee',
                                  _formatCents(totalCommission),
                                  valueColor: AppTheme.textSecondaryOf(context)),
                            ],
                            if (totalTax > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(
                                context,
                                'Tax${taxRate > 0 ? ' (${taxRate.toStringAsFixed(1)}%)' : ''}${taxJurisdiction != null && taxJurisdiction.isNotEmpty ? ' \u2022 $taxJurisdiction' : ''}',
                                _formatCents(totalTax),
                                valueColor: AppTheme.textSecondaryOf(context),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(height: 1,
                                color: AppTheme.dividerOf(context)),
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
                                      : _formatCents(totalAmountPaid),
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

                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
                          'Each ticket below has a unique QR code for event entry.',
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

          const SizedBox(height: 24),

          // ── Individual Ticket Cards ──
          _sectionLabel('YOUR TICKETS'),
          const SizedBox(height: 12),

          ...tickets.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value as Map<String, dynamic>;
            return _buildTicketCard(context, t, idx + 1, quantity, r);
          }),

          // ── Buy Again button ──
          if (widget.showBuyAgain) ...[
            const SizedBox(height: 8),
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
                label: const Text('Buy More Tickets',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
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
    );
  }

  Widget _buildTicketCard(BuildContext context,
      Map<String, dynamic> ticket, int index, int total,
      Map<String, dynamic> receipt) {
    final ticketCode = ticket['ticket_code'] ?? '';
    final receiptNumber = ticket['receipt_number'] ?? '';
    final status = ticket['status'] ?? '';
    final scannedAt = ticket['scanned_at'];
    final saleId = ticket['sale_id'] as int;
    final isScanned = scannedAt != null;

    // Use encrypted QR payload if available (AES-256-GCM), fall back to plaintext JSON
    final qrData = ticket['encrypted_qr_payload'] ?? jsonEncode({
      'receipt_number': receiptNumber,
      'event_id': widget.eventId,
      'user_id': receipt['user_id'],
      'sale_id': saleId,
      'ticket_code': ticketCode,
    });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: isScanned
            ? Border.all(color: AppTheme.successColor.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isScanned
                  ? AppTheme.successColor.withValues(alpha: 0.05)
                  : AppTheme.surfaceOf(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('$index',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.primaryColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ticket $index of $total',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: AppTheme.textPrimaryOf(context))),
                      Text(receiptNumber,
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(context, status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(context, status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // QR Code section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerOf(context)),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 140,
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
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ticketCode));
                    AppToast.info(context, 'Ticket code copied');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ticketCode,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context),
                              fontFamily: 'monospace')),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded,
                          size: 12, color: AppTheme.textSecondaryOf(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isScanned) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Scanned ${AppDateFormat.isoFull(scannedAt)}',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.successColor),
                  ),
                ],
              ),
            ),
          ],

          // View full receipt link
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TicketReceiptScreen(
                  eventId: widget.eventId,
                  saleId: saleId,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('View Full Receipt',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ),
        ],
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

  Widget _detailRow(BuildContext context, String label, String value) {
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
