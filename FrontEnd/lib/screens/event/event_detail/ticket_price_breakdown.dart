import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/ticket.dart';
import '../../../providers/ticket_provider.dart';

class TicketPriceBreakdown extends StatefulWidget {
  final int eventId;
  final int tierId;
  final int basePriceCents;

  const TicketPriceBreakdown({
    super.key,
    required this.eventId,
    required this.tierId,
    required this.basePriceCents,
  });

  @override
  State<TicketPriceBreakdown> createState() => _TicketPriceBreakdownState();
}

class _TicketPriceBreakdownState extends State<TicketPriceBreakdown> {
  TicketPricePreview? _preview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final ticketRepo = context.read<TicketProvider>();
      final data = await ticketRepo.getTicketPrice(widget.eventId, widget.tierId);
      if (mounted) {
        setState(() {
          _preview = data;
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

    final totalDiscount = _preview!.totalDiscountCents;
    if (totalDiscount == 0) return const SizedBox.shrink();

    final tierPrice = _preview!.tierPriceCents;
    final commonDisc = _preview!.commonDiscountCents;
    final selectiveDisc = _preview!.selectiveDiscountCents;
    final pledgeDisc = _preview!.pledgeDiscountCents;
    final eventDisc = _preview!.eventDiscountCents;
    final milestoneDisc = _preview!.milestoneDiscountCents;
    final earlyBirdDisc = _preview!.earlyBirdDiscountCents;
    final finalPrice = _preview!.finalPriceCents;
    final discountCapped = _preview!.discountCapped;
    final maxDiscountPct = _preview!.maxDiscountPercent;

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
