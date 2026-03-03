import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../providers/ticket_provider.dart';
import '../../../widgets/app_toast.dart';

class EventDiscountDropdown extends StatefulWidget {
  final int eventId;
  const EventDiscountDropdown({super.key, required this.eventId});

  @override
  State<EventDiscountDropdown> createState() => _EventDiscountDropdownState();
}

class _EventDiscountDropdownState extends State<EventDiscountDropdown> {
  List<Map<String, dynamic>> _allStrategies = [];
  List<Map<String, dynamic>> _attached = [];
  bool _loading = true;
  String _search = '';

  TicketProvider get _ticketRepo => context.read<TicketProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final all = await _ticketRepo.getDiscountStrategies();
      if (!mounted) return;
      final attached = await _ticketRepo.getEventDiscountStrategies(widget.eventId);
      if (!mounted) return;
      _allStrategies = all.cast<Map<String, dynamic>>();
      _attached = attached.cast<Map<String, dynamic>>();
      _loading = false;
      if (mounted) setState(() {});
    } catch (_) {
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  Set<int> get _attachedIds => _attached.map((d) => d['id'] as int).toSet();

  Future<void> _attach(int id, {required bool autoApply}) async {
    try {
      await _ticketRepo.attachDiscountStrategy(widget.eventId, id, autoApply: autoApply);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to attach');
      }
    }
  }

  Future<void> _detach(int id) async {
    try {
      await _ticketRepo.detachDiscountStrategy(widget.eventId, id);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to detach');
      }
    }
  }

  String _label(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount_rounded, color: context.discountAccent, size: 20),
              AppSpacing.hSm,
              Text('Discounts', style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (_loading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textSecondaryOf(context))),
            ],
          ),
          const SizedBox(height: 10),
          // Attached discounts
          if (_attached.isNotEmpty) ...[
            ..._attached.map((d) {
              final autoApply = d['auto_apply'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.discountAccent.withValues(alpha:0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.discountAccent.withValues(alpha:0.4), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label(d),
                                style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? AppTheme.successSurfaceOf(context)
                                    : AppTheme.warningSurfaceOf(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply ? 'Auto' : 'Claimable',
                                style: TextStyle(
                                  color: autoApply ? AppTheme.successColor : context.fundingAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _detach(d['id'] as int),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
          // Search
          TextField(
            style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryOf(context), size: 20),
              filled: true,
              fillColor: AppTheme.inputFillOf(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: AppRadius.sm, borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: 6),
          ..._buildAvailableList(),
        ],
      ),
    );
  }

  List<Widget> _buildAvailableList() {
    final available = _allStrategies.where((d) {
      final id = d['id'] as int;
      if (_attachedIds.contains(id)) return false;
      if (_search.isEmpty) return true;
      return _label(d).toLowerCase().contains(_search);
    }).toList();

    if (available.isEmpty && _search.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.inputFillOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_label(d), style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)),
              ),
              const SizedBox(width: 6),
              AddButton(
                label: 'Add + Apply',
                color: AppTheme.successColor,
                onTap: () => _attach(d['id'] as int, autoApply: true),
              ),
              const SizedBox(width: 6),
              AddButton(
                label: 'Add',
                color: context.discountAccent,
                onTap: () => _attach(d['id'] as int, autoApply: false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const AddButton({super.key, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha:0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
