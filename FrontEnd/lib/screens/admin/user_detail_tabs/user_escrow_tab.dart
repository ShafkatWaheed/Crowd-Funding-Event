import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserEscrowTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;

  const UserEscrowTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
  });

  @override
  State<UserEscrowTab> createState() => _UserEscrowTabState();
}

class _UserEscrowTabState extends State<UserEscrowTab> {
  String _escrowSearch = '';
  final _escrowSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _escrowSearchCtrl.dispose();
    super.dispose();
  }

  List<AdminUserEscrow> get _allEscrows => widget.detail.escrows ?? [];

  @override
  Widget build(BuildContext context) {
    final allEscrows = _allEscrows;
    final filtered = allEscrows.where((esc) {
      if (_escrowSearch.isEmpty) return true;
      final q = _escrowSearch.toLowerCase();
      return (esc.eventId?.toString().contains(q) ?? false) ||
          (esc.eventTitle?.toLowerCase().contains(q) ?? false) ||
          esc.status.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _escrowSearchCtrl,
            hint: 'Search by event name, organizer, or status...',
            currentValue: _escrowSearch,
            onChanged: (v) => setState(() => _escrowSearch = v),
          ),
        ),
        countStrip(context, filtered.length, allEscrows.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AdminEmptyState(
                      icon: Icons.account_balance_wallet,
                      message: 'No escrows'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _escrowCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _escrowCard(AdminUserEscrow e) {
    final eventId = e.eventId ?? 0;
    final eventTitle = e.eventTitle ?? 'Event #$eventId';
    final isFrozen = e.status == 'frozen';
    final sColor = isFrozen
        ? AppTheme.errorOf(context)
        : e.status == 'fully_released'
            ? AppTheme.successOf(context)
            : e.status == 'partially_released'
                ? context.fundingAccent
                : AppTheme.textSecondaryOf(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, size: 20, color: sColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                      Text('Event #$eventId',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                statusBadge(context,
                    e.status.toUpperCase().replaceAll('_', ' ')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                userDetailEscrowStat(context, 'Held', e.totalHeldCents,
                    AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 16),
                userDetailEscrowStat(context, 'Released',
                    e.totalReleasedCents, AppTheme.successOf(context)),
                const SizedBox(width: 16),
                userDetailEscrowStat(context, 'Remaining',
                    e.remainingCents, context.fundingAccent),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                userDetailStageDot(context, 'S1',
                    e.stage1ReleasedAt != null, context.feedAccent),
                userDetailStageLine(context,
                    e.stage1ReleasedAt != null && e.stage2ReleasedAt != null),
                userDetailStageDot(context, 'S2',
                    e.stage2ReleasedAt != null, context.fundingAccent),
                userDetailStageLine(context,
                    e.stage2ReleasedAt != null && e.stage3ReleasedAt != null),
                userDetailStageDot(context, 'S3',
                    e.stage3ReleasedAt != null, AppTheme.successOf(context)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (e.stage1ReleasedAt == null)
                  userDetailEscrowBtn('Release S1', Icons.looks_one,
                      context.feedAccent,
                      () => confirmAction(context, 'Release Stage 1',
                          'Release Stage 1 escrow?',
                          () => escrowAction(context, eventId, 'release',
                              stage: 1,
                              onRefresh: widget.onRefresh,
                              onSnack: widget.onSnack))),
                if (e.stage1ReleasedAt != null && e.stage2ReleasedAt == null)
                  userDetailEscrowBtn('Release S2', Icons.looks_two,
                      context.fundingAccent,
                      () => confirmAction(context, 'Release Stage 2',
                          'Release Stage 2 escrow?',
                          () => escrowAction(context, eventId, 'release',
                              stage: 2,
                              onRefresh: widget.onRefresh,
                              onSnack: widget.onSnack))),
                if (e.stage2ReleasedAt != null && e.stage3ReleasedAt == null)
                  userDetailEscrowBtn('Release S3', Icons.looks_3,
                      AppTheme.successOf(context),
                      () => confirmAction(context, 'Release Stage 3',
                          'Release Stage 3 escrow?',
                          () => escrowAction(context, eventId, 'release',
                              stage: 3,
                              onRefresh: widget.onRefresh,
                              onSnack: widget.onSnack))),
                if (!isFrozen)
                  userDetailEscrowBtn('Freeze', Icons.ac_unit,
                      AppTheme.errorOf(context),
                      () => confirmAction(context, 'Freeze Escrow',
                          'Freeze this escrow?',
                          () => escrowAction(context, eventId, 'freeze',
                              onRefresh: widget.onRefresh,
                              onSnack: widget.onSnack)))
                else
                  userDetailEscrowBtn('Unfreeze', Icons.wb_sunny,
                      context.ticketAccent,
                      () => confirmAction(context, 'Unfreeze Escrow',
                          'Unfreeze this escrow?',
                          () => escrowAction(context, eventId, 'unfreeze',
                              onRefresh: widget.onRefresh,
                              onSnack: widget.onSnack))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
