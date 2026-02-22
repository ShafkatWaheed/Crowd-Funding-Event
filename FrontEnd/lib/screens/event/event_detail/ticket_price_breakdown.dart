import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../services/api_service.dart';

class TicketPriceBreakdown extends StatefulWidget {
  final int eventId;
  final int tierId;
  final int basePriceCents;

  const TicketPriceBreakdown({
    required this.eventId,
    required this.tierId,
    required this.basePriceCents,
  });

  @override
  State<TicketPriceBreakdown> createState() => _TicketPriceBreakdownState();
}

class _TicketPriceBreakdownState extends State<TicketPriceBreakdown> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.get(
        '/events/${widget.eventId}/ticket-price',
        queryParameters: {'ticket_tier_id': widget.tierId},
      );
      if (mounted) {
        setState(() {
          _preview = resp.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _cents(int c) => '\$${(c / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(left: 28, top: 6),
        child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null || _preview == null) return const SizedBox.shrink();

    final totalDiscount = _preview!['total_discount_cents'] ?? 0;
    if (totalDiscount == 0) return const SizedBox.shrink();

    final tierPrice = _preview!['tier_price_cents'] ?? 0;
    final commonDisc = _preview!['common_discount_cents'] ?? 0;
    final selectiveDisc = _preview!['selective_discount_cents'] ?? 0;
    final pledgeDisc = _preview!['pledge_discount_cents'] ?? 0;
    final eventDisc = _preview!['event_discount_cents'] ?? 0;
    final finalPrice = _preview!['final_price_cents'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: AppSpacing.sm),
      child: Container(
        padding: AppSpacing.paddingSm,
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: AppRadius.sm,
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Price Breakdown',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.teal.shade800)),
            const SizedBox(height: 6),
            _breakdownRow('Base price', _cents(tierPrice), isBold: false),
            if (commonDisc > 0)
              _breakdownRow('Common discount', '- ${_cents(commonDisc)}', color: Colors.green.shade700),
            if (selectiveDisc > 0)
              _breakdownRow('Selective discount', '- ${_cents(selectiveDisc)}', color: Colors.green.shade700),
            if (pledgeDisc > 0)
              _breakdownRow('Pledge discount', '- ${_cents(pledgeDisc)}', color: Colors.green.shade700),
            if (eventDisc > 0)
              _breakdownRow('Event discount', '- ${_cents(eventDisc)}', color: Colors.green.shade700),
            const Divider(height: 10),
            _breakdownRow(
              'You pay',
              finalPrice == 0 ? 'FREE' : _cents(finalPrice),
              isBold: true,
              color: finalPrice == 0 ? Colors.green.shade700 : Colors.teal.shade900,
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: color ?? Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? Colors.grey.shade700)),
        ],
      ),
    );
  }
}
