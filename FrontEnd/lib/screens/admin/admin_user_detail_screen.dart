import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/admin_empty_state.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  TabController? _tabCtrl;

  // Search state
  String _ticketsSearch = '';
  String _pledgesSearch = '';
  String _ticketSalesSearch = '';
  String _pledgesReceivedSearch = '';
  Timer? _searchDebounce;
  final _ticketsSearchCtrl = TextEditingController();
  final _pledgesSearchCtrl = TextEditingController();
  final _ticketSalesSearchCtrl = TextEditingController();
  final _pledgesReceivedSearchCtrl = TextEditingController();

  // Status filter chips
  String _ticketStatusFilter = 'all';
  String _pledgeStatusFilter = 'all';
  String _ticketSalesStatusFilter = 'all';
  String _pledgesReceivedStatusFilter = 'all';

  // Organizer events status filter
  String _eventStatusFilter = 'all';

  // Events search (both customer & organizer)
  String _eventsSearch = '';
  final _eventsSearchCtrl = TextEditingController();

  // Escrow search
  String _escrowSearch = '';
  final _escrowSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl?.dispose();
    _ticketsSearchCtrl.dispose();
    _pledgesSearchCtrl.dispose();
    _ticketSalesSearchCtrl.dispose();
    _pledgesReceivedSearchCtrl.dispose();
    _eventsSearchCtrl.dispose();
    _escrowSearchCtrl.dispose();
    super.dispose();
  }

  int _tabCountForRole(String role) {
    switch (role) {
      case 'organizer': return 7;
      case 'customer': return 3;
      case 'sponsor': return 3;
      default: return 1;
    }
  }

  List<String> _tabLabelsForRole(String role) {
    if (_detail != null && role == 'customer') {
      final tickets = _detail!['tickets'] as List<dynamic>? ?? [];
      final pledges = _detail!['pledges'] as List<dynamic>? ?? [];
      final donations = pledges.where((p) => p['is_guest'] == true).length;
      final regularPledges = pledges.length - donations;
      return [
        'Tickets (${tickets.length})',
        'Pledges ($regularPledges)${donations > 0 ? ' · Donations ($donations)' : ''}',
        'Events',
      ];
    }
    switch (role) {
      case 'customer': return ['Tickets', 'Pledges', 'Events'];
      case 'organizer': return ['Events', 'Tickets Sold', 'Pledges Received', 'Sponsors', 'Discounts', 'Sponsor Bids', 'Escrow'];
      case 'sponsor': return ['Sponsorships', 'Tickets', 'Pledges'];
      default: return ['Info'];
    }
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.adminGetUserDetail(widget.userId);
      if (mounted) {
        final role = data['role'] as String? ?? 'customer';
        _tabCtrl?.dispose();
        _tabCtrl = TabController(length: _tabCountForRole(role), vsync: this);
        setState(() { _detail = data; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = ApiService.extractError(e); _loading = false; });
      }
    }
  }

  void _debouncedSearch(void Function(String) setter, String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => setter(value));
    });
  }

  bool _matchesTicket(Map<String, dynamic> t, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    return (t['event_title']?.toString().toLowerCase().contains(lower) ?? false) ||
        (t['tier_name']?.toString().toLowerCase().contains(lower) ?? false) ||
        (t['amount_paid_cents']?.toString().contains(lower) ?? false) ||
        (t['status']?.toString().toLowerCase().contains(lower) ?? false) ||
        (t['attendee_display_name']?.toString().toLowerCase().contains(lower) ?? false);
  }

  bool _matchesPledge(Map<String, dynamic> p, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    return (p['event_title']?.toString().toLowerCase().contains(lower) ?? false) ||
        (p['user_display_name']?.toString().toLowerCase().contains(lower) ?? false) ||
        (p['amount_cents']?.toString().contains(lower) ?? false) ||
        (p['status']?.toString().toLowerCase().contains(lower) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Detail')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final d = _detail!;
    final role = d['role'] as String? ?? 'customer';
    final name = d['display_name'] ?? d['email'] ?? 'User #${widget.userId}';
    final email = d['email'] ?? '';
    final initial = (name.toString().isNotEmpty ? name.toString() : email.toString())
        .substring(0, 1)
        .toUpperCase();
    final tabLabels = _tabLabelsForRole(role);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _roleColor(role).withValues(alpha: 0.15),
              child: Text(initial, style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _roleColor(role),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name.toString(), style: const TextStyle(fontSize: 16)),
                  Text(
                    '$email  ·  ${role.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: _tabCtrl != null
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: tabLabels.length > 3,
                tabs: tabLabels.map((l) => Tab(text: l)).toList(),
              )
            : null,
      ),
      body: _tabCtrl == null
          ? Center(child: AdminEmptyState(icon: Icons.person, message: 'No data'))
          : TabBarView(
              controller: _tabCtrl,
              children: _buildTabViews(role),
            ),
    );
  }

  List<Widget> _buildTabViews(String role) {
    switch (role) {
      case 'customer': return _customerTabs();
      case 'organizer': return _organizerTabs();
      case 'sponsor': return _sponsorTabs();
      default: return [Center(child: AdminEmptyState(icon: Icons.person, message: 'No role-specific data'))];
    }
  }

  // ===========================================================================
  // CUSTOMER TABS
  // ===========================================================================

  List<Widget> _customerTabs() {
    final tickets = (_detail!['tickets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final pledges = (_detail!['pledges'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final events = (_detail!['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return [
      _ticketTab(tickets, _ticketsSearch, _ticketsSearchCtrl,
          (v) => _ticketsSearch = v, _ticketStatusFilter,
          (v) => setState(() => _ticketStatusFilter = v), isCustomer: true),
      _pledgeTab(pledges, _pledgesSearch, _pledgesSearchCtrl,
          (v) => _pledgesSearch = v, _pledgeStatusFilter,
          (v) => setState(() => _pledgeStatusFilter = v), isCustomer: true),
      _customerEventsTab(events),
    ];
  }

  Widget _customerEventsTab(List<Map<String, dynamic>> events) {
    final query = _eventsSearch.toLowerCase();
    final filtered = query.isEmpty
        ? events
        : events.where((e) => (e['title']?.toString() ?? '').toLowerCase().contains(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _searchField(_eventsSearchCtrl, 'Search events...', _eventsSearch, (v) => _eventsSearch = v),
        ),
        _countStrip(filtered.length, events.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: AdminEmptyState(icon: Icons.event, message: 'No events'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _readOnlyExpandableEventCard(filtered[i]),
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
        leading: Icon(_eventStatusIcon(status), color: _eventStatusColor(status)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusBadge(status),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (ticketCount > 0)
                  _infoChip(Icons.confirmation_number, '$ticketCount ticket${ticketCount == 1 ? '' : 's'}'),
                if (pledgeCount > 0)
                  _infoChip(Icons.volunteer_activism, '$pledgeCount pledge${pledgeCount == 1 ? '' : 's'} (\$${(pledgeTotal / 100).toStringAsFixed(2)})'),
                if (reservedSpots > 0)
                  _infoChip(Icons.event_seat, '$reservedSpots spot${reservedSpots == 1 ? '' : 's'} reserved'),
                if (donationCount > 0)
                  _infoChip(Icons.card_giftcard, '$donationCount donation${donationCount == 1 ? '' : 's'} (\$${(donationTotal / 100).toStringAsFixed(2)})'),
                if (ticketCount == 0 && pledgeCount == 0 && reservedSpots == 0 && donationCount == 0)
                  _infoChip(Icons.info_outline, 'Registered only'),
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
              onPressed: () => context.push('/events/$id', extra: {'readOnly': true}),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View Event'),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ORGANIZER TABS
  // ===========================================================================

  List<Widget> _organizerTabs() {
    final events = (_detail!['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final ticketSales = (_detail!['ticket_sales'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final pledges = (_detail!['pledges'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final sponsors = (_detail!['sponsors'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final discounts = (_detail!['discounts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final sponsorBids = (_detail!['sponsor_bids'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final escrows = (_detail!['escrows'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return [
      _organizerEventsTab(events),
      _ticketTab(ticketSales, _ticketSalesSearch, _ticketSalesSearchCtrl,
          (v) => _ticketSalesSearch = v, _ticketSalesStatusFilter,
          (v) => setState(() => _ticketSalesStatusFilter = v), isOrganizerSales: true),
      _pledgeTab(pledges, _pledgesReceivedSearch, _pledgesReceivedSearchCtrl,
          (v) => _pledgesReceivedSearch = v, _pledgesReceivedStatusFilter,
          (v) => setState(() => _pledgesReceivedStatusFilter = v), isOrganizerPledges: true),
      _listTab(sponsors, _sponsorTile, Icons.business, 'No sponsors'),
      _listTab(discounts, _discountTile, Icons.discount, 'No discounts'),
      _sponsorBidsTab(sponsorBids),
      _escrowTab(escrows),
    ];
  }

  // ===========================================================================
  // SPONSOR TABS
  // ===========================================================================

  List<Widget> _sponsorTabs() {
    final sponsorships = (_detail!['sponsorships'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final tickets = (_detail!['tickets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final pledges = (_detail!['pledges'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return [
      _listTab(sponsorships, _sponsorshipTile, Icons.business_center, 'No sponsorships'),
      _ticketTab(tickets, _ticketsSearch, _ticketsSearchCtrl,
          (v) => _ticketsSearch = v, _ticketStatusFilter,
          (v) => setState(() => _ticketStatusFilter = v), isCustomer: true),
      _pledgeTab(pledges, _pledgesSearch, _pledgesSearchCtrl,
          (v) => _pledgesSearch = v, _pledgeStatusFilter,
          (v) => setState(() => _pledgeStatusFilter = v), isCustomer: true),
    ];
  }

  // ===========================================================================
  // ORGANIZER EVENTS TAB (enriched with status filter + expandable cards)
  // ===========================================================================

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
    'under_review', 'pending_cancellation', 'pending_approval', 'pending_extension',
  };

  Widget _organizerEventsTab(List<Map<String, dynamic>> allEvents) {
    List<Map<String, dynamic>> filtered;
    if (_eventStatusFilter == 'all') {
      filtered = allEvents;
    } else if (_eventStatusFilter == 'pending_cancellation') {
      filtered = allEvents.where((e) => e['pending_cancellation'] != null).toList();
    } else if (_eventStatusFilter == 'pending_extension') {
      filtered = allEvents.where((e) => e['pending_extension'] != null).toList();
    } else {
      filtered = allEvents.where((e) => e['status'] == _eventStatusFilter).toList();
    }

    final query = _eventsSearch.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((e) => (e['title']?.toString() ?? '').toLowerCase().contains(query)).toList();
    }

    final statusCounts = <String, int>{};
    for (final e in allEvents) {
      final s = e['status']?.toString() ?? '';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    final cancelCount = allEvents.where((e) => e['pending_cancellation'] != null).length;
    final extCount = allEvents.where((e) => e['pending_extension'] != null).length;

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
              if (count == 0 && value != 'all' && !_alwaysVisibleFilters.contains(value)) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$label ($count)'),
                  selected: _eventStatusFilter == value,
                  onSelected: (_) => setState(() => _eventStatusFilter = value),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _searchField(_eventsSearchCtrl, 'Search events...', _eventsSearch, (v) => _eventsSearch = v),
        ),
        _countStrip(filtered.length, allEvents.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: AdminEmptyState(icon: Icons.event, message: 'No events'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _expandableEventCard(filtered[i]),
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
    final warnings = (e['validation_warnings'] as List<dynamic>?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(_eventStatusIcon(status), color: _eventStatusColor(status)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            _statusBadge(status),
            if (warnings.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.warning_amber, size: 16, color: AppTheme.warningOf(context)),
              const SizedBox(width: 2),
              Text('${warnings.length}', style: TextStyle(
                fontSize: 11, color: AppTheme.warningOf(context), fontWeight: FontWeight.w600)),
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
    final reviewLog = (e['review_log'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(description, style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (genre.isNotEmpty) _infoChip(Icons.category, genre),
              if (regType.isNotEmpty) _infoChip(Icons.how_to_reg, '${_formatStatus(regType)} ($regCount)'),
              if (capacity != null) _infoChip(Icons.people, 'Cap: $capacity'),
              if (communityRules) _infoChip(Icons.groups, 'Community'),
              if (hasSchedule) _infoChip(Icons.schedule, 'Has Schedule'),
            ],
          ),
          const SizedBox(height: 10),
          if (venueName != null) _detailRow('Venue', venueAddress ?? venueName),
          if (startTime != null) _detailRow('Start', _formatIsoDate(startTime)),
          if (endTime != null) _detailRow('End', _formatIsoDate(endTime)),
          if (fundingEnd != null) _detailRow('Funding Ends', _formatIsoDate(fundingEnd)),
          if (fundingGoal != null) _detailRow('Funding Goal', '\$${(fundingGoal / 100).toStringAsFixed(2)}'),
          if (minPledge > 0) _detailRow('Min Pledge', '\$${(minPledge / 100).toStringAsFixed(2)}'),
          if (ticketStrategy != null) _detailRow('Ticket Strategy', ticketStrategy),
          _detailRow('Ticket Tiers', '$ticketTiersCount'),
          _detailRow('Sponsor Categories', '$sponsorCatsCount'),
          _detailRow('Milestones', '$milestonesCount'),
          if (reviewNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningOf(context).withValues(alpha: 0.08),
                borderRadius: AppRadius.sm,
                border: Border.all(color: AppTheme.warningOf(context).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review Notes', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.warningOf(context))),
                  const SizedBox(height: 4),
                  Text(reviewNotes, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          if (reviewLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Review History', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentOf(context))),
            const SizedBox(height: 4),
            ...reviewLog.take(5).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${entry['action'] ?? ''} – ${_formatIsoDate(entry['timestamp'])} ${entry['notes'] != null ? '• ${entry['notes']}' : ''}',
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

  Widget _warningsSection(List<String> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warningOf(context).withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppTheme.warningOf(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 16, color: AppTheme.warningOf(context)),
              const SizedBox(width: 6),
              Text('Validation Warnings', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warningOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: AppTheme.warningOf(context))),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 12))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findEscrowForEvent(int eventId) {
    final escrows = (_detail?['escrows'] as List<dynamic>?) ?? [];
    for (final esc in escrows) {
      if (esc is Map<String, dynamic> && esc['event_id'] == eventId) return esc;
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
    final statusColor = isFrozen
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.sm,
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text('Escrow', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
              const Spacer(),
              _statusBadge(status.toString().toUpperCase().replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _escrowStat('Held', totalHeld, AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 16),
              _escrowStat('Released', totalReleased, AppTheme.successOf(context)),
              const SizedBox(width: 16),
              _escrowStat('Remaining', remaining, context.fundingAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stageDot('S1', s1 != null, context.feedAccent),
              _stageLine(s1 != null && s2 != null),
              _stageDot('S2', s2 != null, context.fundingAccent),
              _stageLine(s2 != null && s3 != null),
              _stageDot('S3', s3 != null, AppTheme.successOf(context)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s1 == null)
                _escrowBtn('Release S1', Icons.looks_one, context.feedAccent,
                    () => _confirmAction('Release Stage 1', 'Release Stage 1 escrow?',
                        () => _escrowAction(eventId, 'release', stage: 1))),
              if (s1 != null && s2 == null)
                _escrowBtn('Release S2', Icons.looks_two, context.fundingAccent,
                    () => _confirmAction('Release Stage 2', 'Release Stage 2 escrow?',
                        () => _escrowAction(eventId, 'release', stage: 2))),
              if (s2 != null && s3 == null)
                _escrowBtn('Release S3', Icons.looks_3, AppTheme.successOf(context),
                    () => _confirmAction('Release Stage 3', 'Release Stage 3 escrow?',
                        () => _escrowAction(eventId, 'release', stage: 3))),
              if (!isFrozen)
                _escrowBtn('Freeze', Icons.ac_unit, AppTheme.errorOf(context),
                    () => _confirmAction('Freeze Escrow', 'Freeze this escrow?',
                        () => _escrowAction(eventId, 'freeze')))
              else
                _escrowBtn('Unfreeze', Icons.wb_sunny, context.ticketAccent,
                    () => _confirmAction('Unfreeze Escrow', 'Unfreeze this escrow?',
                        () => _escrowAction(eventId, 'unfreeze'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventActionButtons(Map<String, dynamic> e) {
    final id = e['id'] as int;
    final status = e['status']?.toString() ?? '';
    final pendingCancel = e['pending_cancellation'];
    final pendingExt = e['pending_extension'];
    final escrow = _findEscrowForEvent(id);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/events/$id', extra: {'readOnly': true}),
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
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAction(
                    'Reject Event',
                    'Are you sure you want to reject this event?',
                    () => _approveEvent(id, false),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
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
                  onPressed: () => _showResolveDialog(id, 'approved', 'Approve'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResolveDialog(id, 'draft', '→ Draft'),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('→ Draft'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResolveDialog(id, 'cancelled', 'Cancel'),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
                ),
              ),
            ],
          ),
        ],
        if (pendingCancel != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.errorOf(context).withValues(alpha: 0.08),
              borderRadius: AppRadius.sm,
              border: Border.all(color: AppTheme.errorOf(context).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Cancellation', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.errorOf(context))),
                if (pendingCancel['reason'] != null)
                  Text('Reason: ${pendingCancel['reason']}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _confirmAction(
                          'Approve Cancellation',
                          'Are you sure you want to cancel this event?',
                          () => _decideCancellation(id, 'approve'),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.errorOf(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _decideCancellation(id, 'reject'),
                        icon: const Icon(Icons.shield, size: 16),
                        label: const Text('Keep'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.successOf(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (pendingExt != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentOf(context).withValues(alpha: 0.08),
              borderRadius: AppRadius.sm,
              border: Border.all(color: AppTheme.accentOf(context).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Extension', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentOf(context))),
                if (pendingExt['start_time'] != null)
                  Text('New start: ${_formatIsoDate(pendingExt['start_time'])}', style: const TextStyle(fontSize: 12)),
                if (pendingExt['end_time'] != null)
                  Text('New end: ${_formatIsoDate(pendingExt['end_time'])}', style: const TextStyle(fontSize: 12)),
                if (pendingExt['funding_end_at'] != null)
                  Text('New funding end: ${_formatIsoDate(pendingExt['funding_end_at'])}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _decideExtension(id, 'approve'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmAction(
                          'Reject Extension',
                          'Reject this extension request?',
                          () => _decideExtension(id, 'reject'),
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (escrow != null)
          _inlineEscrowSection(escrow)
        else
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 14, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text('No escrow', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
            ],
          ),
      ],
    );
  }

  // ===========================================================================
  // SPONSOR BIDS TAB
  // ===========================================================================

  Widget _sponsorBidsTab(List<Map<String, dynamic>> sponsorBids) {
    if (sponsorBids.isEmpty) {
      return Center(child: AdminEmptyState(icon: Icons.business_center, message: 'No sponsor bids'));
    }
    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sponsorBids.length,
        itemBuilder: (ctx, i) => _sponsorshipTile(sponsorBids[i]),
      ),
    );
  }

  // ===========================================================================
  // ESCROW TAB
  // ===========================================================================

  Widget _escrowTab(List<Map<String, dynamic>> allEscrows) {
    final filtered = allEscrows.where((esc) {
      if (_escrowSearch.isEmpty) return true;
      final q = _escrowSearch.toLowerCase();
      return (esc['event_id']?.toString().contains(q) ?? false) ||
          (esc['status']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _searchField(_escrowSearchCtrl, 'Search by event ID or status...',
              _escrowSearch, (v) => _escrowSearch = v),
        ),
        _countStrip(filtered.length, allEscrows.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: AdminEmptyState(icon: Icons.account_balance_wallet, message: 'No escrows'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
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

  Widget _escrowCard(Map<String, dynamic> e) {
    final eventId = e['event_id'] ?? 0;
    final totalHeld = (e['total_held_cents'] ?? 0) as int;
    final totalReleased = (e['total_released_cents'] ?? 0) as int;
    final remaining = (e['remaining_cents'] ?? 0) as int;
    final status = e['status'] ?? 'holding';
    final s1 = e['stage1_released_at'];
    final s2 = e['stage2_released_at'];
    final s3 = e['stage3_released_at'];
    final isFrozen = status == 'frozen';
    final statusColor = isFrozen
        ? AppTheme.errorOf(context)
        : status == 'fully_released'
            ? AppTheme.successOf(context)
            : status == 'partially_released'
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
                Icon(Icons.account_balance, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text('Event #$eventId',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                _statusBadge(status.toString().toUpperCase().replaceAll('_', ' ')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _escrowStat('Held', totalHeld, AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 16),
                _escrowStat('Released', totalReleased, AppTheme.successOf(context)),
                const SizedBox(width: 16),
                _escrowStat('Remaining', remaining, context.fundingAccent),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stageDot('S1', s1 != null, context.feedAccent),
                _stageLine(s1 != null && s2 != null),
                _stageDot('S2', s2 != null, context.fundingAccent),
                _stageLine(s2 != null && s3 != null),
                _stageDot('S3', s3 != null, AppTheme.successOf(context)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s1 == null)
                  _escrowBtn('Release S1', Icons.looks_one, context.feedAccent,
                      () => _confirmAction('Release Stage 1', 'Release Stage 1 escrow?',
                          () => _escrowAction(eventId, 'release', stage: 1))),
                if (s1 != null && s2 == null)
                  _escrowBtn('Release S2', Icons.looks_two, context.fundingAccent,
                      () => _confirmAction('Release Stage 2', 'Release Stage 2 escrow?',
                          () => _escrowAction(eventId, 'release', stage: 2))),
                if (s2 != null && s3 == null)
                  _escrowBtn('Release S3', Icons.looks_3, AppTheme.successOf(context),
                      () => _confirmAction('Release Stage 3', 'Release Stage 3 escrow?',
                          () => _escrowAction(eventId, 'release', stage: 3))),
                if (!isFrozen)
                  _escrowBtn('Freeze', Icons.ac_unit, AppTheme.errorOf(context),
                      () => _confirmAction('Freeze Escrow', 'Freeze this escrow?',
                          () => _escrowAction(eventId, 'freeze')))
                else
                  _escrowBtn('Unfreeze', Icons.wb_sunny, context.ticketAccent,
                      () => _confirmAction('Unfreeze Escrow', 'Unfreeze this escrow?',
                          () => _escrowAction(eventId, 'unfreeze'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _escrowStat(String label, int cents, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        Text('\$${(cents / 100).toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _stageDot(String label, bool done, Color color) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? color : AppTheme.dividerOf(context),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, color: context.onDarkSurface, size: 16)
                : Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: done ? color : AppTheme.textSecondaryOf(context))),
      ],
    );
  }

  Widget _stageLine(bool active) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.successOf(context) : AppTheme.dividerOf(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _escrowBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  // ===========================================================================
  // REUSABLE TAB BUILDERS
  // ===========================================================================

  static const _refundTicketStatuses = {'refund_requested', 'refund_processing', 'refunded', 'refund_failed'};
  static const _refundPledgeStatuses = {'refund_processing', 'refunded', 'refund_failed'};

  Widget _ticketTab(
    List<Map<String, dynamic>> allTickets,
    String searchQuery,
    TextEditingController searchCtrl,
    void Function(String) onSearchChanged,
    String statusFilter,
    void Function(String) onStatusChanged, {
    bool isCustomer = false,
    bool isOrganizerSales = false,
  }) {
    final statuses = _extractStatuses(allTickets, 'status');
    statuses.addAll(_refundTicketStatuses);
    var filtered = allTickets.where((t) => _matchesTicket(t, searchQuery)).toList();
    if (statusFilter != 'all') {
      filtered = filtered.where((t) => t['status'] == statusFilter).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _searchField(searchCtrl,
              isOrganizerSales ? 'Search by event, attendee, tier...' : 'Search by event, tier, status...',
              searchQuery, onSearchChanged),
        ),
        _statusChipsWithExtras(
          statuses: statuses,
          selected: statusFilter,
          onChanged: onStatusChanged,
          refundStatuses: _refundTicketStatuses,
          allItems: allTickets,
        ),
        _countStrip(filtered.length, allTickets.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: AdminEmptyState(icon: Icons.confirmation_number, message: 'No tickets'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _ticketCard(filtered[i], isCustomer: isCustomer, isOrganizerSales: isOrganizerSales),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pledgeTab(
    List<Map<String, dynamic>> allPledges,
    String searchQuery,
    TextEditingController searchCtrl,
    void Function(String) onSearchChanged,
    String statusFilter,
    void Function(String) onStatusChanged, {
    bool isCustomer = false,
    bool isOrganizerPledges = false,
  }) {
    final statuses = _extractStatuses(allPledges, 'status');
    statuses.addAll(_refundPledgeStatuses);
    var filtered = allPledges.where((p) => _matchesPledge(p, searchQuery)).toList();
    if (statusFilter == '_donation') {
      filtered = filtered.where((p) => p['is_guest'] == true).toList();
    } else if (statusFilter != 'all') {
      filtered = filtered.where((p) => p['status'] == statusFilter).toList();
    }

    final donationCount = allPledges.where((p) => p['is_guest'] == true).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _searchField(searchCtrl, 'Search by event, user, amount...',
              searchQuery, onSearchChanged),
        ),
        _statusChipsWithExtras(
          statuses: statuses,
          selected: statusFilter,
          onChanged: onStatusChanged,
          refundStatuses: _refundPledgeStatuses,
          allItems: allPledges,
          extras: [
            if (donationCount > 0)
              _ExtraChip('_donation', 'Donations ($donationCount)', Icons.card_giftcard),
          ],
        ),
        _countStrip(filtered.length, allPledges.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: AdminEmptyState(icon: Icons.volunteer_activism, message: 'No pledges'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _pledgeCard(filtered[i], isCustomer: isCustomer, isOrganizerPledges: isOrganizerPledges),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _listTab<T>(
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) builder,
    IconData emptyIcon,
    String emptyMsg,
  ) {
    if (items.isEmpty) {
      return Center(child: AdminEmptyState(icon: emptyIcon, message: emptyMsg));
    }
    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => builder(items[i]),
      ),
    );
  }

  // ===========================================================================
  // SHARED WIDGETS
  // ===========================================================================

  Set<String> _extractStatuses(List<Map<String, dynamic>> items, String key) {
    final statuses = <String>{};
    for (final item in items) {
      final s = item[key]?.toString();
      if (s != null && s.isNotEmpty) statuses.add(s);
    }
    return statuses;
  }

  Widget _searchField(TextEditingController ctrl, String hint, String currentValue, void Function(String) onChanged) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: currentValue.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  ctrl.clear();
                  setState(() => onChanged(''));
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: AppTheme.dividerOf(context)),
        ),
      ),
      onChanged: (v) => _debouncedSearch(onChanged, v),
    );
  }

  Widget _statusChipsWithExtras({
    required Set<String> statuses,
    required String selected,
    required void Function(String) onChanged,
    Set<String> refundStatuses = const {},
    List<Map<String, dynamic>> allItems = const [],
    List<_ExtraChip> extras = const [],
  }) {
    final regular = statuses.where((s) => !refundStatuses.contains(s)).toList();
    final refund = statuses.where((s) => refundStatuses.contains(s)).toList();

    int _countFor(String status) => allItems.where((i) => i['status'] == status).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == 'all',
              onSelected: (_) => onChanged('all'),
            ),
          ),
          ...regular.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_formatStatus(s)),
              selected: selected == s,
              onSelected: (_) => onChanged(s),
            ),
          )),
          if (refund.isNotEmpty) ...[
            Container(
              width: 1, height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppTheme.dividerOf(context),
            ),
            ...refund.map((s) {
              final count = _countFor(s);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(Icons.money_off, size: 16, color: selected == s ? null : AppTheme.errorOf(context)),
                  label: Text('${_formatStatus(s)}${count > 0 ? ' ($count)' : ''}'),
                  selected: selected == s,
                  onSelected: (_) => onChanged(s),
                ),
              );
            }),
          ],
          if (extras.isNotEmpty) ...[
            Container(
              width: 1, height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppTheme.dividerOf(context),
            ),
            ...extras.map((e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(e.icon, size: 16),
                label: Text(e.label),
                selected: selected == e.key,
                onSelected: (_) => onChanged(selected == e.key ? 'all' : e.key),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _countStrip(int filtered, int total) {
    if (filtered == total) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(
        '$filtered of $total results',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
      ),
    );
  }

  String _formatStatus(String s) {
    return s.replaceAll('_', ' ').split(' ').map((w) =>
        w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppTheme.errorOf(context);
      case 'organizer': return AppTheme.accentOf(context);
      case 'sponsor': return context.sponsorAccent;
      case 'customer': return AppTheme.primaryOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  // ===========================================================================
  // CARD BUILDERS
  // ===========================================================================

  Widget _ticketCard(Map<String, dynamic> t, {bool isCustomer = false, bool isOrganizerSales = false}) {
    final eventId = t['event_id'] as int;
    final ticketId = t['id'] as int;
    final status = t['status'] as String? ?? '';
    final canApproveRefund = status == 'refund_requested';
    final isRefundRelated = _refundTicketStatuses.contains(status);
    final amountCents = t['amount_paid_cents'] as int? ?? 0;
    final subtitle = isOrganizerSales
        ? '${t['attendee_display_name'] ?? 'User'} · ${t['tier_name'] ?? 'Ticket'} · \$${(amountCents / 100).toStringAsFixed(2)}'
        : '${t['tier_name'] ?? 'Ticket'} · \$${(amountCents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isRefundRelated
            ? Icon(Icons.money_off, color: AppTheme.errorOf(context), size: 20)
            : null,
        title: Text(t['event_title'] ?? 'Event #$eventId',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusBadge(status),
            if (isCustomer && canApproveRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.check_circle, color: AppTheme.successOf(context)),
                tooltip: 'Approve refund',
                onPressed: () => _approveTicketRefund(eventId, ticketId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pledgeCard(Map<String, dynamic> p, {bool isCustomer = false, bool isOrganizerPledges = false}) {
    final eventId = p['event_id'] as int;
    final fundingId = p['id'] as int;
    final status = p['status'] as String? ?? '';
    final canRefund = status == 'pledged';
    final amountCents = p['amount_cents'] as int? ?? 0;
    final name = p['user_display_name'] ?? 'User';
    final isGuest = p['is_guest'] == true;
    final spots = p['reserved_spots'] as int? ?? 0;

    final subtitleParts = <String>[name, '\$${(amountCents / 100).toStringAsFixed(2)}'];
    if (spots > 0) subtitleParts.add('$spots spot${spots == 1 ? '' : 's'}');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isGuest
            ? Icon(Icons.card_giftcard, color: AppTheme.warningOf(context), size: 20)
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(p['event_title'] ?? 'Event #$eventId',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (isGuest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningOf(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Donation', style: TextStyle(fontSize: 11, color: AppTheme.warningOf(context), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusBadge(status),
            if ((isCustomer || isOrganizerPledges) && canRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.money_off, color: AppTheme.errorOf(context)),
                tooltip: 'Refund',
                onPressed: () => _refundPledge(eventId, fundingId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'purchased': return AppTheme.successOf(context);
      case 'refund_requested': return AppTheme.warningOf(context);
      case 'refunded': return AppTheme.errorOf(context);
      case 'waitlisted': return AppTheme.accentOf(context);
      case 'pledged': return AppTheme.successOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  Widget _sponsorTile(Map<String, dynamic> s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(s['company_name'] ?? 'Sponsor', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${s['contact_name'] ?? ''} · \$${((s['total_amount_cents'] ?? 0) / 100).toStringAsFixed(2)}'),
      ),
    );
  }

  Widget _discountTile(Map<String, dynamic> d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(d['event_title'] ?? 'Event', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${d['user_display_name'] ?? 'User'} · ${d['discount_type']} ${d['value']}'),
      ),
    );
  }

  Widget _sponsorshipTile(Map<String, dynamic> sp) {
    final eventId = sp['event_id'] as int;
    final bids = sp['bids'] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(sp['event_title'] ?? 'Event #$eventId',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        children: bids.cast<Map<String, dynamic>>().map((b) {
          final bidId = b['bid_id'] as int;
          final catId = b['category_id'] as int;
          final canRefund = b['can_refund'] == true;
          return ListTile(
            title: Text('${b['category_name'] ?? 'Category'} · \$${((b['amount_cents'] ?? 0) / 100).toStringAsFixed(2)}'),
            subtitle: Text(b['status']?.toString() ?? ''),
            trailing: canRefund
                ? IconButton(
                    icon: Icon(Icons.money_off, color: AppTheme.errorOf(context)),
                    tooltip: 'Refund',
                    onPressed: () => _refundSponsorBid(eventId, catId, bidId),
                  )
                : _statusBadge(b['status']?.toString() ?? ''),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================

  Future<void> _approveTicketRefund(int eventId, int ticketId) async {
    try {
      await context.read<ApiService>().approveTicketRefund(eventId, ticketId);
      _loadDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refund approved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${ApiService.extractError(e)}')));
      }
    }
  }

  Future<void> _refundPledge(int eventId, int fundingId) async {
    try {
      await context.read<ApiService>().adminRefundPledge(eventId, fundingId);
      _loadDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pledge refunded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${ApiService.extractError(e)}')));
      }
    }
  }

  Future<void> _refundSponsorBid(int eventId, int catId, int bidId) async {
    try {
      await context.read<ApiService>().adminRefundSponsorBid(eventId, catId, bidId);
      _loadDetail();
      _snack('Sponsor bid refunded');
    } catch (e) {
      _snack('Failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _approveEvent(int id, bool approve) async {
    try {
      final api = context.read<ApiService>();
      await api.adminApproveEvent(id, {
        'approved': approve,
        if (!approve) 'reason': 'Rejected by admin',
      });
      _loadDetail();
      _snack(approve ? 'Event approved' : 'Event rejected');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/events/$eventId/cancellation/approve', data: {'action': action});
      _loadDetail();
      _snack('Cancellation ${action}d');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideExtension(eventId, action);
      _loadDetail();
      _snack('Extension ${action}d');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _resolveReview(int eventId, String targetStatus, {String? notes}) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/admin/events/$eventId/resolve-review', data: {
        'target_status': targetStatus,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      _loadDetail();
      _snack('Review resolved');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _escrowAction(int eventId, String action, {int? stage}) async {
    try {
      final api = context.read<ApiService>();
      final path = stage != null
          ? '/admin/escrows/$eventId/release/$stage'
          : '/admin/escrows/$eventId/$action';
      await api.dio.post(path);
      _loadDetail();
      _snack('Escrow action completed');
    } catch (e) {
      _snack('Escrow action failed: ${ApiService.extractError(e)}');
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resolveReview(eventId, targetStatus, notes: notesCtrl.text.trim());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  IconData _eventStatusIcon(String status) {
    switch (status) {
      case 'draft': return Icons.edit_note;
      case 'pending_approval': return Icons.hourglass_top;
      case 'approved': return Icons.check_circle_outline;
      case 'under_review': return Icons.search;
      case 'funding': return Icons.attach_money;
      case 'ticket_selling': return Icons.confirmation_number;
      case 'live': return Icons.play_circle;
      case 'completed': return Icons.done_all;
      case 'cancelled': return Icons.cancel;
      default: return Icons.event;
    }
  }

  Color _eventStatusColor(String status) {
    switch (status) {
      case 'draft': return AppTheme.textSecondaryOf(context);
      case 'pending_approval': return AppTheme.accentOf(context);
      case 'approved': return AppTheme.successOf(context);
      case 'under_review': return AppTheme.warningOf(context);
      case 'funding': return context.fundingAccent;
      case 'ticket_selling': return context.ticketAccent;
      case 'live': return AppTheme.successOf(context);
      case 'completed': return AppTheme.successOf(context);
      case 'cancelled': return AppTheme.errorOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  String _formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _ExtraChip {
  final String key;
  final String label;
  final IconData icon;
  const _ExtraChip(this.key, this.label, this.icon);
}
