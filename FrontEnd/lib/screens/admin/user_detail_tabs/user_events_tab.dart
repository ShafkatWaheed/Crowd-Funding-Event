import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../providers/admin_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserEventsTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;
  final bool isOrganizer;

  const UserEventsTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
    this.isOrganizer = false,
  });

  @override
  State<UserEventsTab> createState() => _UserEventsTabState();
}

class _UserEventsTabState extends State<UserEventsTab> {
  String _eventsSearch = '';
  final _eventsSearchCtrl = TextEditingController();
  String _eventStatusFilter = 'all';

  static const _eventStatusFilters = [
    ('all', 'All'),
    ('pending_approval', 'Waiting Approval'),
    ('under_review', 'Under Review'),
    ('pending_cancellation', 'Cancellations'),
    ('pending_extension', 'Extensions'),
    ('draft', 'Drafts'),
    ('approved', 'Approved'),
    ('funding', 'Funding'),
    ('ticket_selling', 'Ticket Selling'),
  ];

  static const _alwaysVisibleFilters = {
    'under_review',
    'pending_cancellation',
    'pending_approval',
    'pending_extension',
  };

  @override
  void dispose() {
    _eventsSearchCtrl.dispose();
    super.dispose();
  }

  List<AdminUserEvent> get _allEvents => widget.detail.events ?? [];

  @override
  Widget build(BuildContext context) {
    return widget.isOrganizer
        ? _buildOrganizerView(context)
        : _buildCustomerView(context);
  }

  // =========================================================================
  // CUSTOMER VIEW
  // =========================================================================

  Widget _buildCustomerView(BuildContext context) {
    final events = _allEvents;
    final query = _eventsSearch.toLowerCase();
    final filtered = query.isEmpty
        ? events
        : events
            .where((e) => e.title.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _eventsSearchCtrl,
            hint: 'Search events...',
            currentValue: _eventsSearch,
            onChanged: (v) => setState(() => _eventsSearch = v),
          ),
        ),
        countStrip(context, filtered.length, events.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AdminEmptyState(
                      icon: Icons.event, message: 'No events'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _readOnlyExpandableEventCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _readOnlyExpandableEventCard(AdminUserEvent e) {
    final ticketCount = e.userTicketCount ?? 0;
    final pledgeCount = e.userPledgeCount ?? 0;
    final pledgeTotal = e.userPledgeTotalCents ?? 0;
    final reservedSpots = e.userReservedSpots ?? 0;
    final donationCount = e.userDonationCount ?? 0;
    final donationTotal = e.userDonationTotalCents ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(eventStatusIcon(e.status),
            color: eventStatusColor(context, e.status)),
        title: Text(e.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statusBadge(context, e.status),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (ticketCount > 0)
                  infoChip(context, Icons.confirmation_number,
                      '$ticketCount ticket${ticketCount == 1 ? '' : 's'}'),
                if (pledgeCount > 0)
                  infoChip(context, Icons.volunteer_activism,
                      '$pledgeCount pledge${pledgeCount == 1 ? '' : 's'} (\$${(pledgeTotal / 100).toStringAsFixed(2)})'),
                if (reservedSpots > 0)
                  infoChip(context, Icons.event_seat,
                      '$reservedSpots spot${reservedSpots == 1 ? '' : 's'} reserved'),
                if (donationCount > 0)
                  infoChip(context, Icons.card_giftcard,
                      '$donationCount donation${donationCount == 1 ? '' : 's'} (\$${(donationTotal / 100).toStringAsFixed(2)})'),
                if (ticketCount == 0 &&
                    pledgeCount == 0 &&
                    reservedSpots == 0 &&
                    donationCount == 0)
                  infoChip(
                      context, Icons.info_outline, 'Registered only'),
              ],
            ),
          ],
        ),
        children: [
          _eventPreviewSection(e),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('/events/${e.id}', extra: {'readOnly': true}),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View Event'),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ORGANIZER VIEW
  // =========================================================================

  Widget _buildOrganizerView(BuildContext context) {
    final allEvents = _allEvents;
    List<AdminUserEvent> filtered;
    if (_eventStatusFilter == 'all') {
      filtered = allEvents;
    } else if (_eventStatusFilter == 'pending_cancellation') {
      filtered = allEvents
          .where((e) => e.pendingCancellation != null)
          .toList();
    } else if (_eventStatusFilter == 'pending_extension') {
      filtered = allEvents
          .where((e) => e.pendingExtension != null)
          .toList();
    } else {
      filtered = allEvents
          .where((e) => e.status == _eventStatusFilter)
          .toList();
    }

    final query = _eventsSearch.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((e) => e.title.toLowerCase().contains(query))
          .toList();
    }

    final statusCounts = <String, int>{};
    for (final e in allEvents) {
      statusCounts[e.status] = (statusCounts[e.status] ?? 0) + 1;
    }
    final cancelCount = allEvents
        .where((e) => e.pendingCancellation != null)
        .length;
    final extCount = allEvents
        .where((e) => e.pendingExtension != null)
        .length;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: _eventStatusFilters.map((entry) {
              final (value, label) = entry;
              int count;
              if (value == 'all') {
                count = allEvents.length;
              } else if (value == 'pending_cancellation') {
                count = cancelCount;
              } else if (value == 'pending_extension') {
                count = extCount;
              } else {
                count = statusCounts[value] ?? 0;
              }
              if (count == 0 &&
                  value != 'all' &&
                  !_alwaysVisibleFilters.contains(value)) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$label ($count)'),
                  selected: _eventStatusFilter == value,
                  onSelected: (_) =>
                      setState(() => _eventStatusFilter = value),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: UserDetailSearchField(
            controller: _eventsSearchCtrl,
            hint: 'Search events...',
            currentValue: _eventsSearch,
            onChanged: (v) => setState(() => _eventsSearch = v),
          ),
        ),
        countStrip(context, filtered.length, allEvents.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AdminEmptyState(
                      icon: Icons.event, message: 'No events'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _expandableEventCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _expandableEventCard(AdminUserEvent e) {
    final warnings = e.validationWarnings;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(eventStatusIcon(e.status),
            color: eventStatusColor(context, e.status)),
        title: Text(e.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            statusBadge(context, e.status),
            if (warnings.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.warning_amber,
                  size: 16, color: AppTheme.warningOf(context)),
              const SizedBox(width: 2),
              Text('${warnings.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warningOf(context),
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        children: [
          _eventPreviewSection(e),
          const SizedBox(height: 12),
          if (warnings.isNotEmpty) ...[
            _warningsSection(warnings),
            const SizedBox(height: 12),
          ],
          _eventActionButtons(e),
        ],
      ),
    );
  }

  // =========================================================================
  // SHARED EVENT PREVIEW
  // =========================================================================

  Widget _eventPreviewSection(AdminUserEvent e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: AppRadius.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.description != null && e.description!.isNotEmpty) ...[
            Text(e.description!,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (e.genre != null && e.genre!.isNotEmpty)
                infoChip(context, Icons.category, e.genre!),
              if (e.registrationType != null && e.registrationType!.isNotEmpty)
                infoChip(context, Icons.how_to_reg,
                    '${formatStatus(e.registrationType!)} (${e.registrationCount})'),
              if (e.maxCapacity != null)
                infoChip(context, Icons.people, 'Cap: ${e.maxCapacity}'),
              if (e.communityRules)
                infoChip(context, Icons.groups, 'Community'),
              if (e.hasSchedule)
                infoChip(context, Icons.schedule, 'Has Schedule'),
            ],
          ),
          const SizedBox(height: 10),
          if (e.venueName != null)
            detailRow(context, 'Venue', e.venueAddress ?? e.venueName!),
          if (e.startTime != null)
            detailRow(context, 'Start', formatIsoDateShort(e.startTime)),
          if (e.endTime != null)
            detailRow(context, 'End', formatIsoDateShort(e.endTime)),
          if (e.fundingEndAt != null)
            detailRow(context, 'Funding Ends',
                formatIsoDateShort(e.fundingEndAt)),
          if (e.fundingGoalCents != null)
            detailRow(context, 'Funding Goal',
                '\$${(e.fundingGoalCents! / 100).toStringAsFixed(2)}'),
          if (e.minPledgeCents > 0)
            detailRow(context, 'Min Pledge',
                '\$${(e.minPledgeCents / 100).toStringAsFixed(2)}'),
          if (e.ticketStrategyName != null)
            detailRow(context, 'Ticket Strategy', e.ticketStrategyName!),
          detailRow(context, 'Ticket Tiers', '${e.ticketTiersCount}'),
          detailRow(
              context, 'Sponsor Categories', '${e.sponsorshipCategoriesCount}'),
          detailRow(context, 'Milestones', '${e.milestonesCount}'),
          if (e.reviewNotes != null && e.reviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningOf(context)
                    .withValues(alpha: 0.08),
                borderRadius: AppRadius.sm,
                border: Border.all(
                    color: AppTheme.warningOf(context)
                        .withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review Notes',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warningOf(context))),
                  const SizedBox(height: 4),
                  Text(e.reviewNotes!,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          if (e.reviewLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Review History',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentOf(context))),
            const SizedBox(height: 4),
            ...e.reviewLog.take(5).map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle,
                          size: 6,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entry['action'] ?? ''} – ${formatIsoDateShort(entry['timestamp']?.toString())} ${entry['notes'] != null ? '• ${entry['notes']}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // ORGANIZER-ONLY SECTIONS
  // =========================================================================

  Widget _warningsSection(List<String> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warningOf(context).withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(
            color:
                AppTheme.warningOf(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber,
                  size: 16, color: AppTheme.warningOf(context)),
              const SizedBox(width: 6),
              Text('Validation Warnings',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: AppTheme.warningOf(context))),
                    Expanded(
                        child: Text(w,
                            style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  AdminUserEscrow? _findEscrowForEvent(int eventId) {
    final escrows = widget.detail.escrows ?? [];
    for (final esc in escrows) {
      if (esc.eventId == eventId) return esc;
    }
    return null;
  }

  Widget _inlineEscrowSection(AdminUserEscrow esc) {
    final eventId = esc.eventId ?? 0;
    final isFrozen = esc.status == 'frozen';
    final sColor = isFrozen
        ? AppTheme.errorOf(context)
        : esc.status == 'fully_released'
            ? AppTheme.successOf(context)
            : esc.status == 'partially_released'
                ? context.fundingAccent
                : AppTheme.textSecondaryOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: AppRadius.sm,
        border: Border.all(color: sColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  size: 16, color: sColor),
              const SizedBox(width: 6),
              Text('Escrow',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sColor)),
              const Spacer(),
              statusBadge(context,
                  esc.status.toUpperCase().replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              userDetailEscrowStat(context, 'Held', esc.totalHeldCents,
                  AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 16),
              userDetailEscrowStat(context, 'Released',
                  esc.totalReleasedCents, AppTheme.successOf(context)),
              const SizedBox(width: 16),
              userDetailEscrowStat(context, 'Remaining',
                  esc.remainingCents, context.fundingAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              userDetailStageDot(
                  context, 'S1', esc.stage1ReleasedAt != null, context.feedAccent),
              userDetailStageLine(context,
                  esc.stage1ReleasedAt != null && esc.stage2ReleasedAt != null),
              userDetailStageDot(context, 'S2',
                  esc.stage2ReleasedAt != null, context.fundingAccent),
              userDetailStageLine(context,
                  esc.stage2ReleasedAt != null && esc.stage3ReleasedAt != null),
              userDetailStageDot(context, 'S3',
                  esc.stage3ReleasedAt != null, AppTheme.successOf(context)),
            ],
          ),
          const SizedBox(height: 10),
          _escrowActionButtons(eventId, esc),
        ],
      ),
    );
  }

  Widget _escrowActionButtons(int eventId, AdminUserEscrow esc) {
    final isFrozen = esc.status == 'frozen';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (esc.stage1ReleasedAt == null)
          userDetailEscrowBtn(
              'Release S1', Icons.looks_one, context.feedAccent,
              () => confirmAction(context, 'Release Stage 1',
                  'Release Stage 1 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 1,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (esc.stage1ReleasedAt != null && esc.stage2ReleasedAt == null)
          userDetailEscrowBtn('Release S2', Icons.looks_two,
              context.fundingAccent,
              () => confirmAction(context, 'Release Stage 2',
                  'Release Stage 2 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 2,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (esc.stage2ReleasedAt != null && esc.stage3ReleasedAt == null)
          userDetailEscrowBtn('Release S3', Icons.looks_3,
              AppTheme.successOf(context),
              () => confirmAction(context, 'Release Stage 3',
                  'Release Stage 3 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 3,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (!isFrozen)
          userDetailEscrowBtn(
              'Freeze', Icons.ac_unit, AppTheme.errorOf(context),
              () => confirmAction(context, 'Freeze Escrow',
                  'Freeze this escrow?',
                  () => escrowAction(context, eventId, 'freeze',
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack)))
        else
          userDetailEscrowBtn(
              'Unfreeze', Icons.wb_sunny, context.ticketAccent,
              () => confirmAction(context, 'Unfreeze Escrow',
                  'Unfreeze this escrow?',
                  () => escrowAction(context, eventId, 'unfreeze',
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
      ],
    );
  }

  Widget _eventActionButtons(AdminUserEvent e) {
    final esc = _findEscrowForEvent(e.id);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context
                    .push('/events/${e.id}', extra: {'readOnly': true}),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Event'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/events/${e.id}/edit'),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Event'),
              ),
            ),
          ],
        ),
        if (e.status == 'pending_approval') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _approveEvent(e.id, true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => confirmAction(
                    context,
                    'Reject Event',
                    'Are you sure you want to reject this event?',
                    () => _approveEvent(e.id, false),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
        if (e.status == 'under_review') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _showResolveDialog(e.id, 'approved', 'Approve'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showResolveDialog(e.id, 'draft', '→ Draft'),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('→ Draft'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showResolveDialog(e.id, 'cancelled', 'Cancel'),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
        if (e.pendingCancellation != null) ...[
          const SizedBox(height: 8),
          _pendingCancellationSection(e.id, e.pendingCancellation!),
        ],
        if (e.pendingExtension != null) ...[
          const SizedBox(height: 8),
          _pendingExtensionSection(e.id, e.pendingExtension!),
        ],
        const SizedBox(height: 8),
        if (esc != null)
          _inlineEscrowSection(esc)
        else
          Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  size: 14,
                  color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text('No escrow',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
            ],
          ),
      ],
    );
  }

  Widget _pendingCancellationSection(
      int id, Map<String, dynamic> pendingCancel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.errorOf(context).withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(
            color: AppTheme.errorOf(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Cancellation',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorOf(context))),
          if (pendingCancel['reason'] != null)
            Text('Reason: ${pendingCancel['reason']}',
                style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => confirmAction(
                    context,
                    'Approve Cancellation',
                    'Are you sure you want to cancel this event?',
                    () => _decideCancellation(id, 'approve'),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.errorOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _decideCancellation(id, 'reject'),
                  icon: const Icon(Icons.shield, size: 16),
                  label: const Text('Keep'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successOf(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingExtensionSection(
      int id, Map<String, dynamic> pendingExt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accentOf(context).withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(
            color: AppTheme.accentOf(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Extension',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentOf(context))),
          if (pendingExt['start_time'] != null)
            Text(
                'New start: ${formatIsoDateShort(pendingExt['start_time']?.toString())}',
                style: const TextStyle(fontSize: 12)),
          if (pendingExt['end_time'] != null)
            Text(
                'New end: ${formatIsoDateShort(pendingExt['end_time']?.toString())}',
                style: const TextStyle(fontSize: 12)),
          if (pendingExt['funding_end_at'] != null)
            Text(
                'New funding end: ${formatIsoDateShort(pendingExt['funding_end_at']?.toString())}',
                style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _decideExtension(id, 'approve'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => confirmAction(
                    context,
                    'Reject Extension',
                    'Reject this extension request?',
                    () => _decideExtension(id, 'reject'),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIONS
  // =========================================================================

  Future<void> _approveEvent(int id, bool approve) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.approveEvent(id, {
        'approved': approve,
        if (!approve) 'reason': 'Rejected by admin',
      });
      widget.onRefresh();
      widget.onSnack(approve ? 'Event approved' : 'Event rejected');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.decideCancellation(eventId, action);
      widget.onRefresh();
      widget.onSnack('Cancellation ${action}d');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final eventRepo = context.read<EventProvider>();
      await eventRepo.decideExtension(eventId, action);
      widget.onRefresh();
      widget.onSnack('Extension ${action}d');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _resolveReview(int eventId, String targetStatus,
      {String? notes}) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.resolveReview(eventId,
          targetStatus: targetStatus, notes: notes);
      widget.onRefresh();
      widget.onSnack('Review resolved');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  void _showResolveDialog(
      int eventId, String targetStatus, String actionLabel) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolve: $actionLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Move this event to "$targetStatus"?'),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes for organizer (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resolveReview(eventId, targetStatus,
                  notes: notesCtrl.text.trim());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
