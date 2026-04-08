import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/ticket.dart';
import '../../../providers/ticket_provider.dart';
import '../../../widgets/app_toast.dart';
import '../create_event/create_event_actions.dart' show confirmDelete;

class EditTier {
  int? id;
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0.00');
  final descCtrl = TextEditingController();
  EditTier({this.id});
}

class EditTicketsSection extends StatefulWidget {
  final int eventId;
  const EditTicketsSection({super.key, required this.eventId});

  @override
  State<EditTicketsSection> createState() => _EditTicketsSectionState();
}

class _EditTicketsSectionState extends State<EditTicketsSection> {
  bool _expanded = false;
  bool _loaded = false;
  List<EditTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    try {
      final ticketRepo = context.read<TicketProvider>();
      final list = await ticketRepo.getTicketTiers(widget.eventId);
      if (mounted) {
        setState(() {
          _tiers = list.map((j) {
            final t = EditTier(id: j.id);
            t.nameCtrl.text = j.name;
            t.priceCtrl.text =
                (j.priceCents / 100).toStringAsFixed(2);
            t.descCtrl.text = ''; // TicketTier model lacks description
            return t;
          }).toList();
          _loaded = true;
          if (_tiers.isNotEmpty) _expanded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _saveTier(EditTier t) async {
    final name = t.nameCtrl.text.trim();
    if (name.isEmpty) return;
    final priceCents =
        ((double.tryParse(t.priceCtrl.text.trim()) ?? 0) * 100).toInt();
    final ticketRepo = context.read<TicketProvider>();
    try {
      if (t.id != null) {
        await ticketRepo.updateTicketTier(widget.eventId, t.id!, UpdateTicketTierRequest(
          name: name,
          priceCents: priceCents,
          description: t.descCtrl.text.trim().isNotEmpty ? t.descCtrl.text.trim() : null,
        ));
        if (mounted) AppToast.success(context, 'Tier updated');
      } else {
        final resp = await ticketRepo.createTicketTier(widget.eventId, CreateTicketTierRequest(
          name: name,
          priceCents: priceCents,
          displayOrder: _tiers.indexOf(t),
          description: t.descCtrl.text.trim().isNotEmpty ? t.descCtrl.text.trim() : null,
        ));
        t.id = resp.id;
        if (mounted) AppToast.success(context, 'Tier created');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to save tier');
      }
    }
  }

  Future<void> _deleteTier(int idx) async {
    if (!await confirmDelete(context, 'ticket tier')) return;
    final t = _tiers[idx];
    if (t.id != null) {
      try {
        final ticketRepo = context.read<TicketProvider>();
        await ticketRepo.deleteTicketTier(widget.eventId, t.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e,
              fallback: 'Failed to delete tier');
        }
        return;
      }
    }
    setState(() => _tiers.removeAt(idx));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _expanded
                  ? context.feedAccent.withValues(alpha: 0.08)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _expanded
                    ? context.feedAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_rounded,
                    size: 18,
                    color: _expanded
                        ? context.feedAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Ticket Tiers',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (_tiers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          context.feedAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_tiers.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.feedAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondaryOf(context)),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_loaded)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ))
                else ...[
                  ...List.generate(
                      _tiers.length,
                      (i) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: _buildTierCard(i),
                          )),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _tiers.add(EditTier())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Tier'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: context.feedAccent),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildTierCard(int index) {
    final t = _tiers[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.feedAccent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: context.feedAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.id != null ? 'Tier #${t.id}' : 'New Tier',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.save, size: 18,
                    color: context.feedAccent),
                onPressed: () => _saveTier(t),
                tooltip: 'Save',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteTier(index),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: t.nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tier Name *',
                    hintText: 'e.g. VIP, General',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: t.priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Price (\$) *',
                    prefixText: '\$ ',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: t.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What this tier includes',
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
