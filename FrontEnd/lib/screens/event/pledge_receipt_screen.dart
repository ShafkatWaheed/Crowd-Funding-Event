import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

/// Pledge receipt screen showing pledge details, commission, and reserved spots.
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
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        title: const Text('Pledge Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
                          child: const Text('Retry')),
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
    final createdAt = r['created_at'] != null
        ? DateTime.parse(r['created_at']).toLocal()
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.08),
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
                      colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.volunteer_activism_rounded, size: 40, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text('Pledge Confirmed',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                      // Event title
                      _sectionLabel('EVENT'),
                      const SizedBox(height: 6),
                      Text(eventTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),

                      // Pledge details
                      _sectionLabel('PLEDGE DETAILS'),
                      const SizedBox(height: 8),
                      _detailRow('Amount', _formatCents(amountCents)),
                      _detailRow('Status', status[0].toUpperCase() + status.substring(1)),
                      if (reservedSpots > 0)
                        _detailRow('Reserved Spots', '$reservedSpots'),
                      if (createdAt != null)
                        _detailRow('Date', DateFormat('MMM d, yyyy h:mm a').format(createdAt)),
                      const SizedBox(height: 20),

                      // Commission breakdown
                      _sectionLabel('FEE BREAKDOWN'),
                      const SizedBox(height: 8),
                      _priceRow('Pledge Amount', _formatCents(amountCents)),
                      const SizedBox(height: 6),
                      _priceRow('Platform Fee ($commissionPct%)',
                          _formatCents(platformCutCents),
                          valueColor: Colors.grey[500]!),
                      const SizedBox(height: 6),
                      const Divider(),
                      _priceRow('Net to Organizer',
                          _formatCents(netToOrganizerCents),
                          isBold: true),
                      const SizedBox(height: 20),

                      if (reservedSpots > 0) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_seat_rounded, size: 20, color: Colors.teal),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$reservedSpots ticket spot(s) reserved. These will be consumed first when you buy tickets.',
                                  style: const TextStyle(fontSize: 12, color: Colors.teal),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Copy receipt number
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: receiptNumber));
                            AppToast.success(context, 'Receipt number copied');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy Receipt Number'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
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
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.grey[500]));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor)),
      ],
    );
  }
}
