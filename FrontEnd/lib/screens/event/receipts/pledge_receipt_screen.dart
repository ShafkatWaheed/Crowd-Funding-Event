import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/app_icons.dart';
import '../../../config/theme.dart';
import '../../../models/funding.dart';
import '../../../models/receipt.dart';
import '../../../utils/date_time_utils.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/pledge_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/loading_switcher.dart';
import '../../../widgets/shimmer_loaders.dart';

class PledgeReceiptScreen extends StatefulWidget {
  final int eventId;
  final int pledgeId;

  const PledgeReceiptScreen({
    super.key,
    required this.eventId,
    required this.pledgeId,
  });

  @override
  State<PledgeReceiptScreen> createState() => _PledgeReceiptScreenState();
}

class _PledgeReceiptScreenState extends State<PledgeReceiptScreen> {
  bool _loading = true;
  String? _error;
  PledgeReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<PledgeProvider>();
      final data = await repo.getPledgeReceipt(widget.eventId, widget.pledgeId);
      if (mounted) setState(() { _receipt = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiError.extractMessage(e); _loading = false; });
    }
  }

  String _formatCents(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(_receipt != null && _receipt!.isGuest
            ? 'Donation Receipt'
            : 'Pledge Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LoadingSwitcher(
        loading: _loading,
        loadingChild: const Center(child: ShimmerReceiptCard()),
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _receipt != null
                ? _buildReceipt()
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildReceipt() {
    final r = _receipt!;
    final receiptNumber = r.receiptNumber ?? '';
    final eventTitle = r.eventTitle;
    final amountCents = r.amountCents;
    final reservedSpots = r.reservedSpots;
    final platformCutCents = r.platformCutCents;
    final netToOrganizerCents = r.netToOrganizerCents;
    final commissionPct = r.fundingCommissionPercent;
    final taxCents = r.taxCents;
    final taxRate = r.taxRate;
    final status = r.status;
    final isGuest = r.isGuest;
    final isDonation = isGuest;
    final typeLabel = isDonation ? 'Donation' : 'Pledge';
    final createdAt = r.createdAt.toLocal();

    final isDark = AppTheme.isDark(context);
    final pledgeStatus = PledgeStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => PledgeStatus.pledged,
    );
    final headerColor = isDonation
        ? AppIcons.donationColor(isDark: isDark)
        : AppIcons.pledgeStatusColor(pledgeStatus, isDark: isDark);
    final headerBg = Color.lerp(headerColor, Colors.black, isDark ? 0.15 : 0.45)!;

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
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isDonation ? AppIcons.donationIcon : AppIcons.pledgeStatusIcon(pledgeStatus),
                        size: 40,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 6)],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$typeLabel Confirmed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receiptNumber,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 4)],
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
                      if (r.backerName != null) ...[
                        _sectionLabel(isDonation ? 'DONOR' : 'BACKER'),
                        const SizedBox(height: 6),
                        Text(r.backerName!,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryOf(context))),
                        const SizedBox(height: 20),
                      ],

                      _sectionLabel('EVENT'),
                      const SizedBox(height: 6),
                      Text(eventTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: 20),

                      _sectionLabel(isDonation ? 'DONATION DETAILS' : 'PLEDGE DETAILS'),
                      const SizedBox(height: 8),
                      _detailRow('Amount', _formatCents(amountCents)),
                      _detailRow('Status', isDonation ? 'Donation' : (status[0].toUpperCase() + status.substring(1))),
                      if (reservedSpots > 0)
                        _detailRow('Reserved Spots', '$reservedSpots'),
                      _detailRow('Date', AppDateFormat.fullDateTime(createdAt)),
                      const SizedBox(height: 20),

                      _sectionLabel('FEE BREAKDOWN'),
                      const SizedBox(height: 8),
                      if (r.subtotalCents > 0 && taxCents > 0) ...[
                        _priceRow('Subtotal', _formatCents(r.subtotalCents)),
                        const SizedBox(height: 6),
                      ],
                      _priceRow('$typeLabel Amount', _formatCents(amountCents)),
                      const SizedBox(height: 6),
                      _priceRow('Platform Fee ($commissionPct%)',
                          _formatCents(platformCutCents), subtle: true),
                      if (taxCents > 0) ...[
                        const SizedBox(height: 6),
                        _priceRow(
                          'Tax${taxRate > 0 ? ' (${taxRate.toStringAsFixed(1)}%)' : ''}',
                          _formatCents(taxCents),
                          subtle: true,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Divider(color: AppTheme.dividerOf(context)),
                      _priceRow('Net to Organizer',
                          _formatCents(netToOrganizerCents), isBold: true),
                      const SizedBox(height: 20),

                      if (isDonation) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.photoAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.photoAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 20, color: context.photoAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This is a guest donation and is non-refundable. No ticket spots are reserved.',
                                  style: TextStyle(fontSize: 12, color: context.photoAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (reservedSpots > 0) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.ticketAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.ticketAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_seat_rounded, size: 20, color: context.ticketAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$reservedSpots ticket spot(s) reserved. These will be consumed first when you buy tickets.',
                                  style: TextStyle(fontSize: 12, color: context.ticketAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: receiptNumber));
                            AppToast.success(context, 'Receipt number copied');
                          },
                          icon: Icon(Icons.copy_rounded, size: 18, color: headerBg),
                          label: Text('Copy Receipt Number',
                              style: TextStyle(color: headerBg)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: headerBg.withValues(alpha: 0.4)),
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
                            backgroundColor: headerBg,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Done',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
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
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: subtle ? AppTheme.textSecondaryOf(context) : AppTheme.textPrimaryOf(context))),
      ],
    );
  }
}
