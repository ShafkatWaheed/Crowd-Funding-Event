import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/discount.dart';
import '../../../providers/ticket_provider.dart';

class CustomerDiscountsSection extends StatefulWidget {
  final int eventId;
  final VoidCallback? onDiscountsChanged;
  const CustomerDiscountsSection({super.key, required this.eventId, this.onDiscountsChanged});

  @override
  State<CustomerDiscountsSection> createState() => _CustomerDiscountsSectionState();
}

class _CustomerDiscountsSectionState extends State<CustomerDiscountsSection> {
  List<UserDiscount> _discounts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<TicketProvider>().getMyDiscounts(widget.eventId);
      if (mounted) {
        setState(() {
          _discounts = result.availableDiscounts;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _describe(UserDiscount d) {
    final type = d.discountType;
    final val = d.value;
    switch (type) {
      case 'ticket_percent':
        return '$val% off ticket price';
      case 'pledge_percent':
        return '$val% pledge discount';
      case 'fixed_cents':
        return '\$${(val / 100).toStringAsFixed(2)} flat discount';
      default:
        return '$val';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.vXl,
        Row(
          children: [
            Icon(Icons.local_offer_rounded, size: AppIconSize.md, color: context.sponsorAccent),
            AppSpacing.hSm,
            Expanded(
              child: Text('Your Discounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () async {
                await context.push('/events/${widget.eventId}/discounts');
                await _load();
                widget.onDiscountsChanged?.call();
              },
              icon: const Icon(Icons.search, size: AppIconSize.sm),
              label: const Text('Browse', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: context.sponsorAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        AppSpacing.vSm,
        if (_discounts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: context.sponsorSurface,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    'No discounts applied yet. Tap Browse to see available discounts you can claim.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
              ],
            ),
          )
        else
          ..._discounts.map((d) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.sponsorSurface,
                  borderRadius: AppRadius.md,
                ),
                child: Row(
                  children: [
                    Icon(Icons.discount_rounded, size: AppIconSize.sm, color: context.sponsorAccent),
                    AppSpacing.hSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.discountType.replaceAll('_', ' '),
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                          Text(_describe(d),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 8),
      ],
    );
  }
}
