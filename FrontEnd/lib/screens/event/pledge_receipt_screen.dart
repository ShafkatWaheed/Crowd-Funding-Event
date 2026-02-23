import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

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
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getPledgeReceipt(widget.eventId, widget.pledgeId);
      if (mounted) setState(() { _receipt = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  String _formatCents(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(_receipt != null && _receipt!['is_guest'] == true
            ? 'Donation Receipt'
            : 'Pledge Receipt'),
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
              : _buildReceipt(),
    );
  }

  Widget _buildReceipt() {
    final r = _receipt!;
    final receiptNumber = r['receipt_number'] ?? '';
    final eventTitle = r['event_title'] ?? '';
    final amountCents = (r['amount_cents'] ?? 0) as int;
    final reservedSpots = (r['reserved_spots'] ?? 0) as int;
    final platformCutCents = (r['platform_cut_cents'] ?? 0) as int;
    final netToOrganizerCents = (r['net_to_organizer_cents'] ?? 0) as int;
    final commissionPct = (r['funding_commission_percent'] ?? 0) as int;
    final status = r['status'] ?? 'pledged';
    final isGuest = r['is_guest'] == true;
    final isDonation = isGuest;
    final typeLabel = isDonation ? 'Donation' : 'Pledge';
    final createdAt = r['created_at'] != null
        ? DateTime.parse(r['created_at']).toLocal()
        : null;

    final headerColor = isDonation ? context.photoAccent : context.sponsorAccent;

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
                    gradient: LinearGradient(
                      colors: isDonation
                          ? [context.photoAccent, context.photoAccent.withValues(alpha: 0.8)]
                          : [context.sponsorAccent, context.sponsorAccent.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(isDonation ? Icons.card_giftcard_rounded : Icons.volunteer_activism_rounded,
                          size: 40, color: Colors.white),
                      const SizedBox(height: 10),
                      Text('$typeLabel Confirmed',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(receiptNumber,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r['backer_name'] != null) ...[
                        _sectionLabel(isDonation ? 'DONOR' : 'BACKER'),
                        const SizedBox(height: 6),
                        Text(r['backer_name'],
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
                      if (createdAt != null)
                        _detailRow('Date', DateFormat('MMM d, yyyy h:mm a').format(createdAt)),
                      const SizedBox(height: 20),

                      _sectionLabel('FEE BREAKDOWN'),
                      const SizedBox(height: 8),
                      _priceRow('$typeLabel Amount', _formatCents(amountCents)),
                      const SizedBox(height: 6),
                      _priceRow('Platform Fee ($commissionPct%)',
                          _formatCents(platformCutCents), subtle: true),
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
                          icon: Icon(Icons.copy_rounded, size: 18, color: headerColor),
                          label: Text('Copy Receipt Number',
                              style: TextStyle(color: headerColor)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: headerColor.withValues(alpha: 0.4)),
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
