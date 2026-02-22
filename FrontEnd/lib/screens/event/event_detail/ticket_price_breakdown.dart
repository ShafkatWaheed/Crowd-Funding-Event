import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
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
    final milestoneDisc = _preview!['milestone_discount_cents'] ?? 0;
    final earlyBirdDisc = _preview!['early_bird_discount_cents'] ?? 0;
    final finalPrice = _preview!['final_price_cents'] ?? 0;
    final discountCapped = _preview!['discount_capped'] ?? false;
    final maxDiscountPct = _preview!['max_discount_percent'] ?? 100;

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: AppSpacing.sm),
      child: Container(
        padding: AppSpacing.paddingSm,
        decoration: BoxDecoration(
          color: context.ticketSurface,
          borderRadius: AppRadius.sm,
          border: Border.all(color: context.ticketAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Price Breakdown',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.ticketAccent)),
            const SizedBox(height: 6),
            _breakdownRow('Base price', _cents(tierPrice), isBold: false),
            if (commonDisc > 0)
              _breakdownRow('Common discount', '- ${_cents(commonDisc)}', color: context.bidAccepted),
            if (selectiveDisc > 0)
              _breakdownRow('Selective discount', '- ${_cents(selectiveDisc)}', color: context.bidAccepted),
            if (pledgeDisc > 0)
              _breakdownRow('Pledge discount', '- ${_cents(pledgeDisc)}', color: context.bidAccepted),
            if (eventDisc > 0)
              _breakdownRow('Event discount', '- ${_cents(eventDisc)}', color: context.bidAccepted),
            if (milestoneDisc > 0)
              _breakdownRow('Milestone discount', '- ${_cents(milestoneDisc)}', color: context.fundingAccent),
            if (earlyBirdDisc > 0)
              _breakdownRow('Early bird discount', '- ${_cents(earlyBirdDisc)}', color: context.scheduleAccent),
            if (discountCapped == true && maxDiscountPct < 100)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Discount capped at $maxDiscountPct% (organizer limit)',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            const Divider(height: 10),
            _breakdownRow(
              'You pay',
              finalPrice == 0 ? 'FREE' : _cents(finalPrice),
              isBold: true,
              color: finalPrice == 0 ? context.bidAccepted : context.ticketAccent,
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
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: color ?? AppTheme.textSecondaryOf(context))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }
}
