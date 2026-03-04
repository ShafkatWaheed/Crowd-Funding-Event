import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/discount.dart';
import '../../../widgets/create_discount_btn.dart';

class DiscountSection extends StatefulWidget {
  final List<DiscountStrategy> discounts;
  final bool discountsLoading;
  final String? discountsError;
  final VoidCallback onReloadDiscounts;
  final Map<int, bool> selectedDiscounts;
  final void Function(int id, bool autoApply) onAddDiscount;
  final ValueChanged<int> onRemoveDiscount;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const DiscountSection({
    super.key,
    required this.discounts,
    required this.discountsLoading,
    required this.discountsError,
    required this.onReloadDiscounts,
    required this.selectedDiscounts,
    required this.onAddDiscount,
    required this.onRemoveDiscount,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  State<DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends State<DiscountSection> {
  String _discountSearch = '';

  String _discountLabel(DiscountStrategy d) {
    final typeLabel = d.discountType == 'ticket_percent' ? '% ticket' : '% pledge';
    return '${d.name} · ${d.value}$typeLabel · ${d.target}';
  }

  List<Widget> _buildAvailableDiscountList() {
    final available = widget.discounts.where((d) {
      if (widget.selectedDiscounts.containsKey(d.id)) return false;
      if (_discountSearch.isEmpty) return true;
      return _discountLabel(d).toLowerCase().contains(_discountSearch);
    }).toList();
    if (available.isEmpty && _discountSearch.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: context.sponsorSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_discountLabel(d),
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              CreateDiscountBtn(
                label: 'Add + Apply',
                color: AppTheme.successColor,
                onTap: () => widget.onAddDiscount(d.id, true),
              ),
              const SizedBox(width: 6),
              CreateDiscountBtn(
                label: 'Add',
                color: context.sponsorAccent,
                onTap: () => widget.onAddDiscount(d.id, false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sponsorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: context.sponsorAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount_rounded,
                  size: 18, color: context.sponsorAccent),
              const SizedBox(width: 8),
              Text('Discounts (Optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          if (widget.discountsLoading)
            widget.buildLoadingChip('Loading discounts…')
          else if (widget.discountsError != null)
            widget.buildErrorRetry(widget.discountsError!, widget.onReloadDiscounts),
          const SizedBox(height: 8),
          if (widget.selectedDiscounts.isNotEmpty) ...[
            ...widget.selectedDiscounts.entries.map((entry) {
              final d = widget.discounts.firstWhere(
                (s) => s.id == entry.key,
                orElse: () => DiscountStrategy(
                  id: entry.key, organizerId: 0, name: '?',
                  discountType: '', value: 0, target: '',
                  createdAt: DateTime(2000), updatedAt: DateTime(2000),
                ),
              );
              final autoApply = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.sponsorAccent
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: context.sponsorAccent
                                  .withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  _discountLabel(d),
                                  style:
                                      const TextStyle(
                                          fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? AppTheme.successSurfaceOf(context)
                                    : AppTheme.warningSurfaceOf(context),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply
                                    ? 'Auto'
                                    : 'Claimable',
                                style: TextStyle(
                                  color: autoApply
                                      ? AppTheme.successColor
                                      : context.fundingAccent,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => widget.onRemoveDiscount(entry.key),
                      child: Icon(Icons.close,
                          size: 16,
                          color: AppTheme.textSecondaryOf(
                              context)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context)),
              prefixIcon: Icon(Icons.search,
                  color: AppTheme.textSecondaryOf(context),
                  size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppTheme.dividerOf(context)),
              ),
            ),
            onChanged: (v) => setState(
                () => _discountSearch = v.toLowerCase()),
          ),
          ..._buildAvailableDiscountList(),
        ],
      ),
    );
  }
}
