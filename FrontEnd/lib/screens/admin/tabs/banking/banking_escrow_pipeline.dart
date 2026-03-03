import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../repositories/base_repository.dart';
import '../../admin_shared.dart';

class BankingEscrowPipelineSection extends StatelessWidget {
  final List<Map<String, dynamic>> escrowRows;
  final bool pipelineLoading;
  final String pipelineTypeFilter;
  final ValueChanged<String> onTypeFilterChanged;
  final VoidCallback onRefresh;
  final int? selectedPipelineEventId;
  final Map<String, dynamic>? selectedEventEscrows;
  final ValueChanged<int> onLoadEventDetail;
  final VoidCallback onClearSelection;
  final void Function(String) onSnack;
  final Future<void> Function(int eventId) onReloadEventDetail;
  final VoidCallback onReloadPipeline;

  const BankingEscrowPipelineSection({
    super.key,
    required this.escrowRows,
    required this.pipelineLoading,
    required this.pipelineTypeFilter,
    required this.onTypeFilterChanged,
    required this.onRefresh,
    required this.selectedPipelineEventId,
    required this.selectedEventEscrows,
    required this.onLoadEventDetail,
    required this.onClearSelection,
    required this.onSnack,
    required this.onReloadEventDetail,
    required this.onReloadPipeline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Escrow Pipeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
            IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh, iconSize: 20),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(label: const Text('All'), selected: pipelineTypeFilter == 'all',
            selectedColor: AppTheme.accentOf(context).withValues(alpha:0.2),
            onSelected: (_) => onTypeFilterChanged('all')),
          ChoiceChip(label: const Text('Fund'), selected: pipelineTypeFilter == 'fund',
            selectedColor: context.fundingAccent.withValues(alpha:0.2),
            onSelected: (_) => onTypeFilterChanged('fund')),
          ChoiceChip(label: const Text('Ticket'), selected: pipelineTypeFilter == 'ticket',
            selectedColor: context.ticketAccent.withValues(alpha:0.2),
            onSelected: (_) => onTypeFilterChanged('ticket')),
          ChoiceChip(label: const Text('Sponsor'), selected: pipelineTypeFilter == 'sponsor',
            selectedColor: context.sponsorAccent.withValues(alpha:0.2),
            onSelected: (_) => onTypeFilterChanged('sponsor')),
        ]),
        const SizedBox(height: 8),
        if (pipelineLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (pipelineTypeFilter == 'all' || pipelineTypeFilter == 'fund')
            ...escrowRows.where((e) => e['_type'] == 'fund').map((e) => _pipelineRow(context, e)),
          if (pipelineTypeFilter == 'all' || pipelineTypeFilter == 'ticket')
            ...escrowRows.where((e) => e['_type'] == 'ticket').map((e) => _pipelineRow(context, e)),
          if (pipelineTypeFilter == 'all' || pipelineTypeFilter == 'sponsor')
            ...escrowRows.where((e) => e['_type'] == 'sponsor').map((e) => _pipelineRow(context, e)),
        ],
        if (selectedEventEscrows != null && selectedPipelineEventId != null) ...[
          const SizedBox(height: 12),
          _buildEventEscrowDetail(context, selectedPipelineEventId!, selectedEventEscrows!),
        ],
      ],
    );
  }

  Widget _pipelineRow(BuildContext context, Map<String, dynamic> e) {
    final type = e['_type'] as String;
    final color = type == 'fund' ? context.fundingAccent : type == 'ticket' ? context.ticketAccent : context.sponsorAccent;
    final statusStr = e['status'] ?? 'holding';
    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha:0.2), child: Text(type[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        title: Text(e['event_title'] ?? 'Event #${e['event_id']}', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context), fontSize: 14)),
        subtitle: Row(children: [
          _stageDot(context, e['stage1_released_at']),
          _stageDot(context, e['stage2_released_at']),
          _stageDot(context, e['stage3_released_at']),
          const SizedBox(width: 8),
          Text('${centsToStr(e['total_held_cents'] ?? 0)} held', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ]),
        trailing: Chip(
          label: Text(statusStr, style: const TextStyle(fontSize: 11)),
          backgroundColor: _escrowStatusChipColor(statusStr),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => onLoadEventDetail(e['event_id']),
      ),
    );
  }

  Widget _stageDot(BuildContext context, dynamic releasedAt) {
    final released = releasedAt != null;
    return Container(
      width: 12, height: 12,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: released ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
      ),
    );
  }

  Color _escrowStatusChipColor(String status) {
    switch (status) {
      case 'fully_released': return AppTheme.successColor.withValues(alpha:0.2);
      case 'partially_released': return AppTheme.warningColor.withValues(alpha:0.2);
      case 'frozen': return AppTheme.errorColor.withValues(alpha:0.2);
      case 'refunded': return Colors.purple.withValues(alpha:0.2);
      default: return AppTheme.accentColor.withValues(alpha:0.15);
    }
  }

  Widget _buildEventEscrowDetail(BuildContext context, int eventId, Map<String, dynamic> data) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Event #$eventId — All Escrows', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClearSelection),
            ]),
            const SizedBox(height: 8),
            if (data['fund'] != null) _EscrowDetailColumn(label: 'Fund', esc: data['fund'] as Map<String, dynamic>, type: 'fund', eventId: eventId, onSnack: onSnack, onReloadEventDetail: onReloadEventDetail, onReloadPipeline: onReloadPipeline),
            if (data['ticket'] != null) _EscrowDetailColumn(label: 'Ticket', esc: data['ticket'] as Map<String, dynamic>, type: 'ticket', eventId: eventId, onSnack: onSnack, onReloadEventDetail: onReloadEventDetail, onReloadPipeline: onReloadPipeline),
            if (data['sponsor'] != null) _EscrowDetailColumn(label: 'Sponsor', esc: data['sponsor'] as Map<String, dynamic>, type: 'sponsor', eventId: eventId, onSnack: onSnack, onReloadEventDetail: onReloadEventDetail, onReloadPipeline: onReloadPipeline),
            if (data['fund'] == null && data['ticket'] == null && data['sponsor'] == null)
              Text('No escrow records for this event.', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }
}

class _EscrowDetailColumn extends StatelessWidget {
  final String label;
  final Map<String, dynamic> esc;
  final String type;
  final int eventId;
  final void Function(String) onSnack;
  final Future<void> Function(int eventId) onReloadEventDetail;
  final VoidCallback onReloadPipeline;

  const _EscrowDetailColumn({
    required this.label,
    required this.esc,
    required this.type,
    required this.eventId,
    required this.onSnack,
    required this.onReloadEventDetail,
    required this.onReloadPipeline,
  });

  @override
  Widget build(BuildContext context) {
    final color = type == 'fund' ? context.fundingAccent : type == 'ticket' ? context.ticketAccent : context.sponsorAccent;
    final stages = [
      {'n': 1, 'cents': esc['stage1_released_cents'] ?? 0, 'at': esc['stage1_released_at'], 'auto': esc['stage1_auto_release'] ?? true},
      {'n': 2, 'cents': esc['stage2_released_cents'] ?? 0, 'at': esc['stage2_released_at'], 'auto': esc['stage2_auto_release'] ?? true},
      {'n': 3, 'cents': esc['stage3_released_cents'] ?? 0, 'at': esc['stage3_released_at'], 'auto': esc['stage3_auto_release'] ?? true},
    ];
    final frozen = esc['status'] == 'frozen';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label — ${esc['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          Text('Held: ${centsToStr(esc['total_held_cents'] ?? 0)} | Released: ${centsToStr(esc['total_released_cents'] ?? 0)} | Remaining: ${centsToStr(esc['remaining_cents'] ?? 0)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 4),
          ...stages.map((st) {
            final released = st['at'] != null;
            final autoRelease = st['auto'] as bool;
            final stageNum = st['n'] as int;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(released ? Icons.check_circle : Icons.radio_button_unchecked, color: released ? AppTheme.successColor : AppTheme.textSecondaryOf(context), size: 16),
                const SizedBox(width: 6),
                Text('Stage $stageNum: ${centsToStr(st['cents'] as int)}', style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                if (!released) ...[
                  const Spacer(),
                  Tooltip(
                    message: autoRelease ? 'Auto-release ON' : 'Auto-release OFF (manual only)',
                    child: SizedBox(
                      height: 28,
                      child: Switch(
                        value: autoRelease,
                        activeTrackColor: color,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) async {
                          try {
                            await context.read<AdminProvider>().toggleAutoRelease(
                              eventId, type,
                              stage1: stageNum == 1 ? val : null,
                              stage2: stageNum == 2 ? val : null,
                              stage3: stageNum == 3 ? val : null,
                            );
                            await onReloadEventDetail(eventId);
                            onSnack('Stage $stageNum auto-release ${val ? 'enabled' : 'disabled'}');
                          } catch (e) {
                            onSnack('Toggle failed: ${ApiError.extractMessage(e)}');
                          }
                        },
                      ),
                    ),
                  ),
                  if (!frozen)
                    TextButton(
                      onPressed: () async {
                        try {
                          await context.read<AdminProvider>().releaseEscrowStage(eventId, type, stageNum);
                          await onReloadEventDetail(eventId);
                          onReloadPipeline();
                          onSnack('$label Stage $stageNum released');
                        } catch (e) {
                          onSnack('Release failed: ${ApiError.extractMessage(e)}');
                        }
                      },
                      child: const Text('Release', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ]),
            );
          }),
          const SizedBox(height: 4),
          Row(children: [
            if (!frozen)
              TextButton.icon(
                icon: const Icon(Icons.ac_unit, size: 14),
                label: const Text('Freeze', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await context.read<AdminProvider>().freezeEscrow(eventId, type);
                  await onReloadEventDetail(eventId);
                  onReloadPipeline();
                },
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Unfreeze', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await context.read<AdminProvider>().unfreezeEscrow(eventId, type);
                  await onReloadEventDetail(eventId);
                  onReloadPipeline();
                },
              ),
          ]),
        ],
      ),
    );
  }
}
