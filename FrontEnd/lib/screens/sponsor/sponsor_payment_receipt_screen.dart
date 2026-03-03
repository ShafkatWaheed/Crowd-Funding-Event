import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../utils/date_time_utils.dart';
import '../../repositories/base_repository.dart';
import '../../providers/sponsor_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

class SponsorPaymentReceiptScreen extends StatefulWidget {
  final int paymentId;

  const SponsorPaymentReceiptScreen({super.key, required this.paymentId});

  @override
  State<SponsorPaymentReceiptScreen> createState() =>
      _SponsorPaymentReceiptScreenState();
}

class _SponsorPaymentReceiptScreenState
    extends State<SponsorPaymentReceiptScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.getSponsorPaymentReceipt(widget.paymentId);
      if (mounted) setState(() { _receipt = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiError.extractMessage(e); _loading = false; });
    }
  }

  String _formatCents(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final isRefund = _receipt?['type'] == 'refund';
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(isRefund ? 'Refund Receipt' : 'Payment Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: ShimmerReceiptCard())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _load();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildReceipt(),
    );
  }

  Widget _buildReceipt() {
    final r = _receipt!;
    final receiptNumber = r['receipt_number'] ?? '';
    final isRefund = r['type'] == 'refund';
    final amountCents = (r['amount_cents'] ?? 0) as int;
    final platformCutCents = (r['platform_cut_cents'] ?? 0) as int;
    final netToOrganizerCents = (r['net_to_organizer_cents'] ?? 0) as int;
    final status = r['status'] ?? '';
    final categoryName = r['category_name'] ?? '';
    final eventTitle = r['event_title'] ?? '';
    final sponsorName = r['sponsor_name'];
    final createdAt = r['created_at'] != null
        ? DateTime.parse(r['created_at']).toLocal()
        : null;
    final eventStartTime = r['event_start_time'] != null
        ? DateTime.parse(r['event_start_time']).toLocal()
        : null;
    final venueName = r['venue_name'];
    final venueCity = r['venue_city'];

    final taxCents = (r['tax_cents'] ?? 0) as int;
    final taxRate = (r['tax_rate'] ?? 0.0) as num;
    final headerColor = isRefund ? AppTheme.errorColor : context.sponsorAccent;
    final commissionPct = amountCents > 0
        ? ((platformCutCents / amountCents) * 100).round()
        : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          headerColor,
                          headerColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isRefund
                              ? Icons.undo_rounded
                              : Icons.payment_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isRefund ? 'Refund Processed' : 'Payment Confirmed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receiptNumber,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sponsorName != null) ...[
                          _sectionLabel('SPONSOR'),
                          const SizedBox(height: 6),
                          Text(sponsorName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryOf(context))),
                          const SizedBox(height: 20),
                        ],

                        _sectionLabel('EVENT'),
                        const SizedBox(height: 6),
                        Text(eventTitle,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryOf(context))),
                        if (eventStartTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            AppDateFormat.eventCard(eventStartTime),
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                        if (venueName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$venueName${venueCity != null ? ', $venueCity' : ''}',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                        const SizedBox(height: 20),

                        _sectionLabel('SPONSORSHIP DETAILS'),
                        const SizedBox(height: 8),
                        _detailRow('Category', categoryName),
                        _detailRow(isRefund ? 'Refund Amount' : 'Amount',
                            _formatCents(amountCents)),
                        _detailRow('Status',
                            status[0].toUpperCase() + status.substring(1)),
                        if (createdAt != null)
                          _detailRow('Date',
                              AppDateFormat.fullDateTime(createdAt)),
                        const SizedBox(height: 20),

                        _sectionLabel('FEE BREAKDOWN'),
                        const SizedBox(height: 8),
                        _priceRow(
                          isRefund ? 'Refund Amount' : 'Sponsorship Amount',
                          isRefund
                              ? '-${_formatCents(amountCents)}'
                              : _formatCents(amountCents),
                        ),
                        const SizedBox(height: 6),
                        _priceRow(
                          'Platform Fee ($commissionPct%)',
                          isRefund
                              ? '-${_formatCents(platformCutCents)}'
                              : _formatCents(platformCutCents),
                          subtle: true,
                        ),
                        if (taxCents > 0) ...[
                          const SizedBox(height: 6),
                          _priceRow(
                            'Tax${taxRate > 0 ? ' (${taxRate.toStringAsFixed(1)}%)' : ''}',
                            isRefund
                                ? '-${_formatCents(taxCents)}'
                                : _formatCents(taxCents),
                            subtle: true,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Divider(color: AppTheme.dividerOf(context)),
                        _priceRow(
                          isRefund ? 'Net Refund' : 'Net to Organizer',
                          isRefund
                              ? '-${_formatCents(netToOrganizerCents)}'
                              : _formatCents(netToOrganizerCents),
                          isBold: true,
                        ),
                        const SizedBox(height: 20),

                        if (isRefund)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 20, color: AppTheme.errorColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This sponsorship has been refunded. The amount will be returned to your original payment method.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.errorColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isRefund)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.sponsorAccent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: context.sponsorAccent
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    size: 20, color: context.sponsorAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Your sponsorship for "$categoryName" is confirmed. A sponsor ticket has been issued for event entry.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.sponsorAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: receiptNumber));
                              AppToast.success(
                                  context, 'Receipt number copied');
                            },
                            icon: Icon(Icons.copy_rounded,
                                size: 18, color: headerColor),
                            label: Text('Copy Receipt Number',
                                style: TextStyle(color: headerColor)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: headerColor.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Done',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.textSecondaryOf(context)));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {bool subtle = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: subtle
                    ? AppTheme.textSecondaryOf(context)
                    : AppTheme.textPrimaryOf(context))),
      ],
    );
  }
}
