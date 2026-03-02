import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../repositories/admin_repository.dart';
import '../../../repositories/base_repository.dart';
import '../../../repositories/event_repository.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserEventsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> detail;
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

  List<Map<String, dynamic>> get _allEvents =>
      (widget.detail['events'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

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
            .where((e) => (e['title']?.toString() ?? '')
                .toLowerCase()
                .contains(query))
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

  Widget _readOnlyExpandableEventCard(Map<String, dynamic> e) {
    final id = e['id'] as int;
    final title = e['title'] ?? 'Event #$id';
    final status = e['status']?.toString() ?? '';
    final ticketCount = e['user_ticket_count'] as int? ?? 0;
    final pledgeCount = e['user_pledge_count'] as int? ?? 0;
    final pledgeTotal = e['user_pledge_total_cents'] as int? ?? 0;
    final reservedSpots = e['user_reserved_spots'] as int? ?? 0;
    final donationCount = e['user_donation_count'] as int? ?? 0;
    final donationTotal = e['user_donation_total_cents'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(eventStatusIcon(status),
            color: eventStatusColor(context, status)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statusBadge(context, status),
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
                  context.push('/events/$id', extra: {'readOnly': true}),
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
    List<Map<String, dynamic>> filtered;
    if (_eventStatusFilter == 'all') {
      filtered = allEvents;
    } else if (_eventStatusFilter == 'pending_cancellation') {
      filtered = allEvents
          .where((e) => e['pending_cancellation'] != null)
          .toList();
    } else if (_eventStatusFilter == 'pending_extension') {
      filtered = allEvents
          .where((e) => e['pending_extension'] != null)
          .toList();
    } else {
      filtered = allEvents
          .where((e) => e['status'] == _eventStatusFilter)
          .toList();
    }

    final query = _eventsSearch.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((e) => (e['title']?.toString() ?? '')
              .toLowerCase()
              .contains(query))
          .toList();
    }

    final statusCounts = <String, int>{};
    for (final e in allEvents) {
      final s = e['status']?.toString() ?? '';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    final cancelCount = allEvents
        .where((e) => e['pending_cancellation'] != null)
        .length;
    final extCount = allEvents
        .where((e) => e['pending_extension'] != null)
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

  Widget _expandableEventCard(Map<String, dynamic> e) {
    final id = e['id'] as int;
    final title = e['title'] ?? 'Event #$id';
    final status = e['status']?.toString() ?? '';
    final warnings =
        (e['validation_warnings'] as List<dynamic>?)?.cast<String>() ??
            [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(eventStatusIcon(status),
            color: eventStatusColor(context, status)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            statusBadge(context, status),
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

  Widget _eventPreviewSection(Map<String, dynamic> e) {
    final description = e['description'] ?? '';
    final genre = e['genre'] ?? '';
    final capacity = e['max_capacity'];
    final regType = e['registration_type'] ?? '';
    final regCount = e['registration_count'] ?? 0;
    final fundingGoal = e['funding_goal_cents'];
    final minPledge = e['min_pledge_cents'] ?? 0;
    final ticketStrategy = e['ticket_strategy_name'];
    final venueName = e['venue_name'];
    final venueAddress = e['venue_address'];
    final startTime = e['start_time'];
    final endTime = e['end_time'];
    final fundingEnd = e['funding_end_at'];
    final hasSchedule = e['has_schedule'] == true;
    final communityRules = e['community_rules'] == true;
    final ticketTiersCount = e['ticket_tiers_count'] ?? 0;
    final sponsorCatsCount = e['sponsorship_categories_count'] ?? 0;
    final milestonesCount = e['milestones_count'] ?? 0;
    final reviewNotes = e['review_notes'] ?? '';
    final reviewLog =
        (e['review_log'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

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
          if (description.isNotEmpty) ...[
            Text(description,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (genre.isNotEmpty)
                infoChip(context, Icons.category, genre),
              if (regType.isNotEmpty)
                infoChip(context, Icons.how_to_reg,
                    '${formatStatus(regType)} ($regCount)'),
              if (capacity != null)
                infoChip(context, Icons.people, 'Cap: $capacity'),
              if (communityRules)
                infoChip(context, Icons.groups, 'Community'),
              if (hasSchedule)
                infoChip(context, Icons.schedule, 'Has Schedule'),
            ],
          ),
          const SizedBox(height: 10),
          if (venueName != null)
            detailRow(context, 'Venue', venueAddress ?? venueName),
          if (startTime != null)
            detailRow(
                context, 'Start', formatIsoDateShort(startTime)),
          if (endTime != null)
            detailRow(context, 'End', formatIsoDateShort(endTime)),
          if (fundingEnd != null)
            detailRow(context, 'Funding Ends',
                formatIsoDateShort(fundingEnd)),
          if (fundingGoal != null)
            detailRow(context, 'Funding Goal',
                '\$${(fundingGoal / 100).toStringAsFixed(2)}'),
          if (minPledge > 0)
            detailRow(context, 'Min Pledge',
                '\$${(minPledge / 100).toStringAsFixed(2)}'),
          if (ticketStrategy != null)
            detailRow(context, 'Ticket Strategy', ticketStrategy),
          detailRow(context, 'Ticket Tiers', '$ticketTiersCount'),
          detailRow(
              context, 'Sponsor Categories', '$sponsorCatsCount'),
          detailRow(context, 'Milestones', '$milestonesCount'),
          if (reviewNotes.isNotEmpty) ...[
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
                  Text(reviewNotes,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          if (reviewLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Review History',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentOf(context))),
            const SizedBox(height: 4),
            ...reviewLog.take(5).map((entry) => Padding(
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
                          '${entry['action'] ?? ''} – ${formatIsoDateShort(entry['timestamp'])} ${entry['notes'] != null ? '• ${entry['notes']}' : ''}',
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

  Map<String, dynamic>? _findEscrowForEvent(int eventId) {
    final escrows =
        (widget.detail['escrows'] as List<dynamic>?) ?? [];
    for (final esc in escrows) {
      if (esc is Map<String, dynamic> && esc['event_id'] == eventId) {
        return esc;
      }
    }
    return null;
  }

  Widget _inlineEscrowSection(Map<String, dynamic> esc) {
    final eventId = esc['event_id'] ?? 0;
    final totalHeld = (esc['total_held_cents'] ?? 0) as int;
    final totalReleased = (esc['total_released_cents'] ?? 0) as int;
    final remaining = (esc['remaining_cents'] ?? 0) as int;
    final status = esc['status'] ?? 'holding';
    final s1 = esc['stage1_released_at'];
    final s2 = esc['stage2_released_at'];
    final s3 = esc['stage3_released_at'];
    final isFrozen = status == 'frozen';
    final sColor = isFrozen
        ? AppTheme.errorOf(context)
        : status == 'fully_released'
            ? AppTheme.successOf(context)
            : status == 'partially_released'
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
                  status.toString().toUpperCase().replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              userDetailEscrowStat(context, 'Held', totalHeld,
                  AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 16),
              userDetailEscrowStat(context, 'Released',
                  totalReleased, AppTheme.successOf(context)),
              const SizedBox(width: 16),
              userDetailEscrowStat(context, 'Remaining', remaining,
                  context.fundingAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              userDetailStageDot(
                  context, 'S1', s1 != null, context.feedAccent),
              userDetailStageLine(context, s1 != null && s2 != null),
              userDetailStageDot(context, 'S2', s2 != null,
                  context.fundingAccent),
              userDetailStageLine(context, s2 != null && s3 != null),
              userDetailStageDot(context, 'S3', s3 != null,
                  AppTheme.successOf(context)),
            ],
          ),
          const SizedBox(height: 10),
          _escrowActionButtons(eventId, esc),
        ],
      ),
    );
  }

  Widget _escrowActionButtons(
      int eventId, Map<String, dynamic> esc) {
    final s1 = esc['stage1_released_at'];
    final s2 = esc['stage2_released_at'];
    final s3 = esc['stage3_released_at'];
    final isFrozen = esc['status'] == 'frozen';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (s1 == null)
          userDetailEscrowBtn(
              'Release S1', Icons.looks_one, context.feedAccent,
              () => confirmAction(
                  context,
                  'Release Stage 1',
                  'Release Stage 1 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 1,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (s1 != null && s2 == null)
          userDetailEscrowBtn('Release S2', Icons.looks_two,
              context.fundingAccent,
              () => confirmAction(
                  context,
                  'Release Stage 2',
                  'Release Stage 2 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 2,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (s2 != null && s3 == null)
          userDetailEscrowBtn('Release S3', Icons.looks_3,
              AppTheme.successOf(context),
              () => confirmAction(
                  context,
                  'Release Stage 3',
                  'Release Stage 3 escrow?',
                  () => escrowAction(context, eventId, 'release',
                      stage: 3,
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
        if (!isFrozen)
          userDetailEscrowBtn(
              'Freeze', Icons.ac_unit, AppTheme.errorOf(context),
              () => confirmAction(
                  context,
                  'Freeze Escrow',
                  'Freeze this escrow?',
                  () => escrowAction(context, eventId, 'freeze',
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack)))
        else
          userDetailEscrowBtn(
              'Unfreeze', Icons.wb_sunny, context.ticketAccent,
              () => confirmAction(
                  context,
                  'Unfreeze Escrow',
                  'Unfreeze this escrow?',
                  () => escrowAction(context, eventId, 'unfreeze',
                      onRefresh: widget.onRefresh,
                      onSnack: widget.onSnack))),
      ],
    );
  }

  Widget _eventActionButtons(Map<String, dynamic> e) {
    final id = e['id'] as int;
    final status = e['status']?.toString() ?? '';
    final pendingCancel = e['pending_cancellation'];
    final pendingExt = e['pending_extension'];
    final esc = _findEscrowForEvent(id);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context
                    .push('/events/$id', extra: {'readOnly': true}),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Event'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/events/$id/edit'),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Event'),
              ),
            ),
          ],
        ),
        if (status == 'pending_approval') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _approveEvent(id, true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => confirmAction(
                    context,
                    'Reject Event',
                    'Are you sure you want to reject this event?',
                    () => _approveEvent(id, false),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
        if (status == 'under_review') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _showResolveDialog(id, 'approved', 'Approve'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showResolveDialog(id, 'draft', '→ Draft'),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('→ Draft'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResolveDialog(
                      id, 'cancelled', 'Cancel'),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
        if (pendingCancel != null) ...[
          const SizedBox(height: 8),
          _pendingCancellationSection(id, pendingCancel),
        ],
        if (pendingExt != null) ...[
          const SizedBox(height: 8),
          _pendingExtensionSection(id, pendingExt),
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
            color:
                AppTheme.errorOf(context).withValues(alpha: 0.2)),
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
                      backgroundColor:
                          AppTheme.errorOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _decideCancellation(id, 'reject'),
                  icon: const Icon(Icons.shield, size: 16),
                  label: const Text('Keep'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          AppTheme.successOf(context)),
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
            color:
                AppTheme.accentOf(context).withValues(alpha: 0.2)),
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
                'New start: ${formatIsoDateShort(pendingExt['start_time'])}',
                style: const TextStyle(fontSize: 12)),
          if (pendingExt['end_time'] != null)
            Text(
                'New end: ${formatIsoDateShort(pendingExt['end_time'])}',
                style: const TextStyle(fontSize: 12)),
          if (pendingExt['funding_end_at'] != null)
            Text(
                'New funding end: ${formatIsoDateShort(pendingExt['funding_end_at'])}',
                style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _decideExtension(id, 'approve'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTheme.successOf(context)),
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
                      foregroundColor:
                          AppTheme.errorOf(context)),
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
      final admin = context.read<AdminRepository>();
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

  Future<void> _decideCancellation(
      int eventId, String action) async {
    try {
      final admin = context.read<AdminRepository>();
      await admin.decideCancellation(eventId, action);
      widget.onRefresh();
      widget.onSnack('Cancellation ${action}d');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _decideExtension(
      int eventId, String action) async {
    try {
      final eventRepo = context.read<EventRepository>();
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
      final admin = context.read<AdminRepository>();
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
