import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../admin_shared.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../providers/admin_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import '../../../widgets/admin/admin_search_bar.dart';
import '../../../widgets/admin/admin_warning_badge.dart';


class AdminEventsTab extends StatefulWidget {
  const AdminEventsTab({
    super.key,
    required this.events,
    required this.eventsTotal,
    this.stats,
    required this.onSnack,
    required this.onEventsChanged,
    this.onLoadMore,
    this.eventsLoadingMore = false,
    this.initialEventFilterIndex,
  });

  final List<AdminEventItem> events;
  final int eventsTotal;
  final AdminStats? stats;
  final void Function(String) onSnack;
  final Future<void> Function() onEventsChanged;
  final Future<void> Function()? onLoadMore;
  final bool eventsLoadingMore;
  /// When set, used as initial filter instead of auto-select (e.g. from overview action card).
  final int? initialEventFilterIndex;

  @override
  State<AdminEventsTab> createState() => _AdminEventsTabState();
}

class _AdminEventsTabState extends State<AdminEventsTab> {
  String _eventSearch = '';
  int _eventFilterIndex = -1; // auto-detect on load
  final _eventsScrollCtrl = ScrollController();

  List<AdminEventItem> get _pendingApproval =>
      widget.events.where((e) => e.status == 'pending_approval').toList();
  List<AdminEventItem> get _underReviewEvents =>
      widget.events.where((e) => e.status == 'under_review').toList();
  List<AdminEventItem> get _draftEvents =>
      widget.events.where((e) => e.status == 'draft').toList();
  List<AdminEventItem> get _pendingCancellations =>
      widget.events.where((e) => e.pendingCancellation != null).toList();
  List<AdminEventItem> get _pendingExtensions =>
      widget.events.where((e) => e.pendingExtension != null).toList();

  List<AdminEventItem> get _currentEventList {
    switch (_eventFilterIndex) {
      case 0:
        return _pendingApproval;
      case 1:
        return _underReviewEvents;
      case 2:
        return _draftEvents;
      case 3:
        return _pendingCancellations;
      case 4:
        return _pendingExtensions;
      default:
        return _pendingApproval;
    }
  }

  List<AdminEventItem> get _filteredEvents {
    if (_eventSearch.isEmpty) return _currentEventList;
    return _currentEventList.where((e) {
      final title = e.title.toLowerCase();
      return title.contains(_eventSearch);
    }).toList();
  }

  int _autoSelectEventFilter() {
    if (_pendingApproval.isNotEmpty) return 0;
    if (_underReviewEvents.isNotEmpty) return 1;
    if (_draftEvents.isNotEmpty) return 2;
    if (_pendingCancellations.isNotEmpty) return 3;
    if (_pendingExtensions.isNotEmpty) return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _eventFilterIndex =
        widget.initialEventFilterIndex ?? _autoSelectEventFilter();
    _eventsScrollCtrl.addListener(_onScroll);
  }


  @override
  void dispose() {
    _eventsScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_eventsScrollCtrl.position.pixels >=
        _eventsScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreEvents();
    }
  }

  Future<void> _loadMoreEvents() async {
    if (widget.eventsLoadingMore ||
        widget.events.length >= widget.eventsTotal) { return; }
    await widget.onLoadMore?.call();
  }

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(int eventId, String targetStatus, String actionLabel) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolve: $actionLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moving event to ${targetStatus.replaceAll('_', ' ')}',
              style: TextStyle(color: AppTheme.textSecondaryOf(ctx)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes to organizer (optional)',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEvent(int id, bool approve) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.approveEvent(
        id,
        ApproveEventRequest(
          approved: approve,
          reason: !approve ? 'Rejected by admin' : null,
        ),
      );
      widget.onEventsChanged();
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final eventRepo = context.read<EventProvider>();
      await eventRepo.decideExtension(eventId, action);
      widget.onEventsChanged();
      widget.onSnack('Extension ${action}d');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.decideCancellation(eventId, action);
      widget.onEventsChanged();
      widget.onSnack('Cancellation ${action}d');
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
      widget.onEventsChanged();
      widget.onSnack('Event moved to ${targetStatus.replaceAll('_', ' ')}');
    } catch (e) {
      widget.onSnack('Action failed: ${ApiError.extractMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('Waiting Approval', _pendingApproval.length),
      ('Under Review', _underReviewEvents.length),
      ('Drafts', _draftEvents.length),
      ('Cancellations', _pendingCancellations.length),
      ('Extensions', _pendingExtensions.length),
    ];

    return RefreshIndicator(
      onRefresh: widget.onEventsChanged,
      child: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: List.generate(filters.length, (i) {
                final (label, count) = filters[i];
                final selected = _eventFilterIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$label ($count)'),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _eventFilterIndex = i;
                      _eventSearch = '';
                    }),
                  ),
                );
              }),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdminSearchBar(
              hint: 'Search events by title...',
              onChanged: (q) => setState(() => _eventSearch = q),
              resultCount:
                  _eventSearch.isNotEmpty ? _filteredEvents.length : null,
              totalCount:
                  _eventSearch.isNotEmpty ? _currentEventList.length : null,
            ),
          ),
          // List
          Expanded(
            child: _filteredEvents.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 300,
                      child: AdminEmptyState(
                        icon: Icons.check_circle,
                        message: 'No events in this category',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _eventsScrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length +
                        (widget.eventsLoadingMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _filteredEvents.length) {
                        return const Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                Center(child: CircularProgressIndicator()));
                      }
                      return _buildEventCard(_filteredEvents[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(AdminEventItem e) {
    switch (_eventFilterIndex) {
      case 0:
        return _approvalCard(e);
      case 1:
        return _underReviewCard(e);
      case 2:
        return _draftCard(e);
      case 3:
        return _cancellationCard(e);
      case 4:
        return _extensionCard(e);
      default:
        return _approvalCard(e);
    }
  }

  Widget _policyOverrideButton(AdminEventItem e) {
    return IconButton(
      icon: const Icon(Icons.tune, size: 18),
      tooltip: 'Policy Overrides',
      onPressed: () => _showPolicyOverridesDialog(e.id),
    );
  }

  void _showPolicyOverridesDialog(int eventId) {
    final ctrls = {
      'admin_override_waitlist_max_size': TextEditingController(),
      'admin_override_event_max_images': TextEditingController(),
      'admin_override_max_posts_per_day': TextEditingController(),
      'admin_override_max_co_organizers': TextEditingController(),
      'admin_override_refund_deadline_percent': TextEditingController(),
    };
    bool loading = true;
    Map<String, dynamic>? current;

    void loadCurrent(StateSetter setDialogState) async {
      try {
        final eventRepo = context.read<EventProvider>();
        await eventRepo.getEvent(eventId);
        setDialogState(() {
          // Admin override fields are not on the Event model;
          // controllers start empty (user fills in overrides).
          current = {};
          loading = false;
        });
      } catch (_) {
        setDialogState(() => loading = false);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loading && current == null) {
            loadCurrent(setDialogState);
          }
          final labels = {
            'admin_override_waitlist_max_size': 'Waitlist max size',
            'admin_override_event_max_images': 'Max images',
            'admin_override_max_posts_per_day': 'Max posts/day',
            'admin_override_max_co_organizers': 'Max co-organizers',
            'admin_override_refund_deadline_percent': 'Refund deadline %',
          };
          return AlertDialog(
            title: Text('Policy Overrides (Event #$eventId)'),
            content: loading
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Leave empty to use organizer/platform default.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 12),
                        ...ctrls.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: labels[entry.key] ?? entry.key,
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => entry.value.clear(),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            )),
                      ],
                    ),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        final overrides = SetPolicyOverridesRequest(
                          waitlistMaxSize: int.tryParse(
                              ctrls['admin_override_waitlist_max_size']!
                                  .text
                                  .trim()),
                          eventMaxImages: int.tryParse(
                              ctrls['admin_override_event_max_images']!
                                  .text
                                  .trim()),
                          maxPostsPerDay: int.tryParse(
                              ctrls['admin_override_max_posts_per_day']!
                                  .text
                                  .trim()),
                          maxCoOrganizers: int.tryParse(
                              ctrls['admin_override_max_co_organizers']!
                                  .text
                                  .trim()),
                          refundDeadlinePercent: int.tryParse(
                              ctrls['admin_override_refund_deadline_percent']!
                                  .text
                                  .trim()),
                        );
                        try {
                          final admin = context.read<AdminProvider>();
                          await admin.setPolicyOverrides(eventId, overrides);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          widget.onSnack('Policy overrides saved');
                        } catch (e) {
                          widget.onSnack('Failed to save overrides');
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      for (final c in ctrls.values) {
        c.dispose();
      }
    });
  }

  Widget _approvalCard(AdminEventItem e) {
    final warnings = getWarnings(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            context.push('/events/${e.id}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _policyOverrideButton(e),
                  if (warnings.isNotEmpty)
                    AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  statusChip(context, 'PENDING APPROVAL',
                      AppTheme.accentOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e.organizerId} • ${formatDate(e.createdAt)}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context)),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                AdminWarningList(warnings: warnings),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approveEvent(e.id, true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        'Reject Event',
                        'Are you sure you want to reject "${e.title}"? It will be moved back to draft.',
                        () => _approveEvent(e.id, false),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorOf(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _underReviewCard(AdminEventItem e) {
    final warnings = getWarnings(e);
    final reviewLog = e.reviewLog;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      color: AppTheme.warningSurfaceOf(context),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            context.push('/events/${e.id}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _policyOverrideButton(e),
                  if (warnings.isNotEmpty)
                    AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  statusChip(
                      context, 'UNDER REVIEW', AppTheme.warningOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e.organizerId}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context)),
              ),
              // Review History
              if (reviewLog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Review History',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                ...reviewLog.map((entry) {
                  final actor =
                      entry.actor == 'system' ? '[sys]' : '[admin]';
                  final ts = entry.timestamp ?? '';
                  final msg = entry.message ?? '';
                  final formatted = formatIsoDate(ts);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$actor ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: entry.actor == 'system'
                                ? AppTheme.warningOf(context)
                                : AppTheme.accentOf(context),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatted,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondaryOf(context)),
                              ),
                              Text(msg.toString(),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Warnings',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                AdminWarningList(warnings: warnings),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showResolveDialog(e.id, 'approved', 'Approve'),
                      icon: const Icon(Icons.check, size: 18),
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
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('→ Draft'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showResolveDialog(
                              e.id, 'cancelled', 'Cancel'),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorOf(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftCard(AdminEventItem e) {
    final warnings = getWarnings(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            context.push('/events/${e.id}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _policyOverrideButton(e),
                  if (warnings.isNotEmpty)
                    AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  statusChip(
                      context, 'DRAFT', AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e.organizerId} • Capacity: ${e.maxCapacity ?? '?'}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context)),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                AdminWarningList(warnings: warnings),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancellationCard(AdminEventItem e) {
    final cancel = e.pendingCancellation;
    final reason = cancel?.reason ?? 'No reason given';
    final pct = cancel?.pledgePercent;
    final contextLabel = pct != null
        ? '$pct% funded — cancellation requires approval'
        : 'Cancellation requires admin approval';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      color: AppTheme.errorSurfaceOf(context),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            context.push('/events/${e.id}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _policyOverrideButton(e),
                  statusChip(
                      context, 'CANCELLATION', AppTheme.errorOf(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                contextLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorOf(context)),
              ),
              const SizedBox(height: 6),
              Text('Reason: $reason', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmAction(
                        'Approve Cancellation',
                        'Are you sure you want to approve the cancellation of "${e.title}"?',
                        () => _decideCancellation(e.id, 'approve'),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve Cancel'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.errorOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _decideCancellation(e.id, 'reject'),
                      icon: const Icon(Icons.shield, size: 18),
                      label: const Text('Keep Event'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extensionCard(AdminEventItem e) {
    final ext = e.pendingExtension;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () =>
            context.push('/events/${e.id}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _policyOverrideButton(e),
                  statusChip(
                      context, 'EXTENSION', AppTheme.warningOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Status: ${e.status}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context)),
              ),
              if (ext != null) ...[
                const SizedBox(height: 6),
                if (ext.fundingEndAt != null)
                  Text(
                    'New funding deadline: ${formatIsoDate(ext.fundingEndAt)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if (ext.fundingGoalCents != null)
                  Text(
                    'New funding goal: \$${(ext.fundingGoalCents! / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _decideExtension(e.id, 'approve'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        'Reject Extension',
                        'Are you sure you want to reject this extension request?',
                        () => _decideExtension(e.id, 'reject'),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorOf(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
