import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/admin/admin_empty_state.dart';
import '../../widgets/admin/admin_kpi_card.dart';
import '../../widgets/admin/admin_action_card.dart';
import '../../widgets/admin/admin_search_bar.dart';
import '../../widgets/admin/admin_warning_badge.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const double _wideBreakpoint = 900;
  static const _dateFormat = 'MMM d, yyyy';

  int _selectedSection = 0;

  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _allEvents = [];
  List<dynamic> _settings = [];
  List<dynamic> _escrows = [];
  List<dynamic> _adminTickets = [];
  List<dynamic> _adminPledges = [];
  bool _isLoading = true;

  // Filtered event lists (derived from _allEvents)
  List<dynamic> get _pendingApproval =>
      _allEvents.where((e) => e['status'] == 'pending_approval').toList();
  List<dynamic> get _underReviewEvents =>
      _allEvents.where((e) => e['status'] == 'under_review').toList();
  List<dynamic> get _draftEvents =>
      _allEvents.where((e) => e['status'] == 'draft').toList();
  List<dynamic> get _pendingCancellations =>
      _allEvents.where((e) => e['pending_cancellation'] != null).toList();
  List<dynamic> get _pendingExtensions =>
      _allEvents.where((e) => e['pending_extension'] != null).toList();

  // Search/filter state
  String _eventSearch = '';
  int _eventFilterIndex = -1; // auto-detect on load
  String _financialSubTab = 'tickets';
  String _financialSearch = '';
  String _userSearch = '';
  String _userRoleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !user.isAdmin) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.adminGetStats(),        // 0
        api.adminGetUsers(),        // 1
        api.adminGetEvents(),       // 2
        api.dio.get('/admin/settings'), // 3
        api.dio.get('/admin/escrows'),  // 4
        api.adminGetTickets(),      // 5
        api.adminGetPledges(),      // 6
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<dynamic>;
        _allEvents = results[2] as List<dynamic>;
        _settings = (results[3] as dynamic).data as List<dynamic>;
        _escrows = (results[4] as dynamic).data as List<dynamic>;
        _adminTickets = results[5] as List<dynamic>;
        _adminPledges = results[6] as List<dynamic>;
        if (_eventFilterIndex < 0) {
          _eventFilterIndex = _autoSelectEventFilter();
        }
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  int _autoSelectEventFilter() {
    if (_pendingApproval.isNotEmpty) return 0;
    if (_underReviewEvents.isNotEmpty) return 1;
    if (_draftEvents.isNotEmpty) return 2;
    if (_pendingCancellations.isNotEmpty) return 3;
    if (_pendingExtensions.isNotEmpty) return 4;
    return 0;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final loadingBody = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(4, (_) => const ShimmerListTile()),
      ),
    );

    final body = _isLoading ? loadingBody : _bodyForSection(_selectedSection);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(context),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sectionTitle(_selectedSection)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(context.watch<ThemeProvider>().isDark
                ? Icons.light_mode
                : Icons.dark_mode),
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeProvider>().toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedSection,
        onTap: (i) => setState(() => _selectedSection = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.accentOf(context),
        unselectedItemColor: AppTheme.textSecondaryOf(context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.paid), label: 'Financial'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final email = context.read<AuthProvider>().user?.email ?? '';
    final pendingCount = _pendingApproval.length +
        _underReviewEvents.length +
        _pendingCancellations.length +
        _pendingExtensions.length;

    return SizedBox(
      width: 220,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: AppTheme.accentOf(context),
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                color: context.onDarkSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navItem(0, Icons.dashboard, 'Home'),
                _navItem(1, Icons.event, 'Events',
                    badge: pendingCount > 0 ? pendingCount : null),
                _navItem(2, Icons.paid, 'Financial'),
                _navItem(3, Icons.people, 'Users'),
                _navItem(4, Icons.settings, 'Settings'),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    context.watch<ThemeProvider>().isDark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    size: 20,
                  ),
                  tooltip: 'Toggle theme',
                  onPressed: () => context.read<ThemeProvider>().toggle(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {int? badge}) {
    final selected = _selectedSection == index;
    final accent = AppTheme.accentOf(context);
    return ListTile(
      leading: badge != null
          ? Badge(
              label: Text('$badge', style: const TextStyle(fontSize: 10)),
              child: Icon(icon, color: selected ? accent : null),
            )
          : Icon(icon, color: selected ? accent : null),
      title: Text(label),
      selected: selected,
      selectedTileColor: accent.withValues(alpha: 0.08),
      onTap: () => setState(() => _selectedSection = index),
    );
  }

  String _sectionTitle(int index) {
    switch (index) {
      case 0: return 'Home';
      case 1: return 'Events';
      case 2: return 'Financial';
      case 3: return 'Users';
      case 4: return 'Settings';
      default: return 'Admin';
    }
  }

  Widget _bodyForSection(int index) {
    switch (index) {
      case 0: return _buildOverview();
      case 1: return _buildEventsSection();
      case 2: return _buildFinancialSection();
      case 3: return _buildUsersSection();
      case 4: return _buildSettingsSection();
      default: return _buildOverview();
    }
  }

  // ===========================================================================
  // SECTION 1: HOME / OVERVIEW
  // ===========================================================================

  Widget _buildOverview() {
    if (_stats == null) {
      return const Center(child: Text('Failed to load stats'));
    }

    final ticketComm = (_stats!['total_ticket_commission_cents'] ?? 0) as int;
    final fundingComm = (_stats!['total_funding_commission_cents'] ?? 0) as int;
    final escrowHeld = (_stats!['total_escrow_held_cents'] ?? 0) as int;
    final totalRevenue = ticketComm + fundingComm;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AdminKpiCard(
                      icon: Icons.people,
                      label: 'Total Users',
                      value: '${_stats!['users_total'] ?? 0}',
                      color: AppTheme.primaryOf(context),
                    ),
                    AdminKpiCard(
                      icon: Icons.event_available,
                      label: 'Live Events',
                      value: '${_stats!['events_live'] ?? 0}',
                      color: AppTheme.successOf(context),
                    ),
                    AdminKpiCard(
                      icon: Icons.paid,
                      label: 'Total Revenue',
                      value: '\$${(totalRevenue / 100).toStringAsFixed(2)}',
                      color: AppTheme.accentOf(context),
                    ),
                    AdminKpiCard(
                      icon: Icons.confirmation_number,
                      label: 'Ticket Commission',
                      value: '\$${(ticketComm / 100).toStringAsFixed(2)}',
                      color: context.sponsorAccent,
                    ),
                    AdminKpiCard(
                      icon: Icons.savings,
                      label: 'Funding Commission',
                      value: '\$${(fundingComm / 100).toStringAsFixed(2)}',
                      color: context.ticketAccent,
                    ),
                    AdminKpiCard(
                      icon: Icons.account_balance,
                      label: 'Escrow Held',
                      value: '\$${(escrowHeld / 100).toStringAsFixed(2)}',
                      color: context.fundingAccent,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Action Required Cards
                if (_pendingApproval.isNotEmpty)
                  AdminActionCard(
                    icon: Icons.pending_actions,
                    count: _pendingApproval.length,
                    title: '${_pendingApproval.length} events waiting approval',
                    subtitle: 'Review and approve pending events',
                    color: AppTheme.accentOf(context),
                    onTap: () => setState(() {
                      _selectedSection = 1;
                      _eventFilterIndex = 0;
                    }),
                  ),
                if (_pendingCancellations.isNotEmpty)
                  AdminActionCard(
                    icon: Icons.cancel_outlined,
                    count: _pendingCancellations.length,
                    title: '${_pendingCancellations.length} pending cancellations',
                    subtitle: 'Review cancellation requests',
                    color: AppTheme.errorOf(context),
                    onTap: () => setState(() {
                      _selectedSection = 1;
                      _eventFilterIndex = 3;
                    }),
                  ),
                if (_pendingExtensions.isNotEmpty)
                  AdminActionCard(
                    icon: Icons.schedule,
                    count: _pendingExtensions.length,
                    title: '${_pendingExtensions.length} pending extensions',
                    subtitle: 'Review extension requests',
                    color: AppTheme.warningOf(context),
                    onTap: () => setState(() {
                      _selectedSection = 1;
                      _eventFilterIndex = 4;
                    }),
                  ),
                if (_underReviewEvents.isNotEmpty)
                  AdminActionCard(
                    icon: Icons.warning_amber_rounded,
                    count: _underReviewEvents.length,
                    title: '${_underReviewEvents.length} under review',
                    subtitle: 'Investigate and resolve flagged events',
                    color: AppTheme.warningOf(context),
                    onTap: () => setState(() {
                      _selectedSection = 1;
                      _eventFilterIndex = 1;
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: EVENTS
  // ===========================================================================

  List<dynamic> get _currentEventList {
    switch (_eventFilterIndex) {
      case 0: return _pendingApproval;
      case 1: return _underReviewEvents;
      case 2: return _draftEvents;
      case 3: return _pendingCancellations;
      case 4: return _pendingExtensions;
      default: return _pendingApproval;
    }
  }

  List<dynamic> get _filteredEvents {
    if (_eventSearch.isEmpty) return _currentEventList;
    return _currentEventList.where((e) {
      final title = (e['title'] ?? '').toString().toLowerCase();
      return title.contains(_eventSearch);
    }).toList();
  }

  Widget _buildEventsSection() {
    final filters = [
      ('Waiting Approval', _pendingApproval.length),
      ('Under Review', _underReviewEvents.length),
      ('Drafts', _draftEvents.length),
      ('Cancellations', _pendingCancellations.length),
      ('Extensions', _pendingExtensions.length),
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
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
              resultCount: _eventSearch.isNotEmpty ? _filteredEvents.length : null,
              totalCount: _eventSearch.isNotEmpty ? _currentEventList.length : null,
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (ctx, i) =>
                        _buildEventCard(_filteredEvents[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    switch (_eventFilterIndex) {
      case 0: return _approvalCard(e);
      case 1: return _underReviewCard(e);
      case 2: return _draftCard(e);
      case 3: return _cancellationCard(e);
      case 4: return _extensionCard(e);
      default: return _approvalCard(e);
    }
  }

  Widget _approvalCard(Map<String, dynamic> e) {
    final warnings = _getWarnings(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => context.push('/events/${e['id']}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (warnings.isNotEmpty) AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  _statusChip('PENDING APPROVAL', AppTheme.accentOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e['organizer_id']} • ${_formatDate(e['created_at'])}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
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
                      onPressed: () => _approveEvent(e['id'], true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        'Reject Event',
                        'Are you sure you want to reject "${e['title']}"? It will be moved back to draft.',
                        () => _approveEvent(e['id'], false),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
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

  Widget _underReviewCard(Map<String, dynamic> e) {
    final warnings = _getWarnings(e);
    final reviewLog = (e['review_log'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      color: AppTheme.warningSurfaceOf(context),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => context.push('/events/${e['id']}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (warnings.isNotEmpty) AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  _statusChip('UNDER REVIEW', AppTheme.warningOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e['organizer_id']}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
              ),

              // Review History
              if (reviewLog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Review History', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                )),
                const SizedBox(height: 6),
                ...reviewLog.map((entry) {
                  final actor = entry['actor'] == 'system' ? '[sys]' : '[admin]';
                  final ts = entry['timestamp'] as String? ?? '';
                  final msg = entry['message'] ?? '';
                  final formatted = _formatIsoDate(ts);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$actor ', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: entry['actor'] == 'system'
                              ? AppTheme.warningOf(context)
                              : AppTheme.accentOf(context),
                        )),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatted, style: TextStyle(
                                fontSize: 10, color: AppTheme.textSecondaryOf(context),
                              )),
                              Text(msg.toString(), style: const TextStyle(fontSize: 12)),
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
                Text('Warnings', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                )),
                const SizedBox(height: 4),
                AdminWarningList(warnings: warnings),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showResolveDialog(e['id'], 'approved', 'Approve'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showResolveDialog(e['id'], 'draft', '→ Draft'),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('→ Draft'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showResolveDialog(e['id'], 'cancelled', 'Cancel'),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
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

  Widget _draftCard(Map<String, dynamic> e) {
    final warnings = _getWarnings(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => context.push('/events/${e['id']}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (warnings.isNotEmpty) AdminWarningBadge(count: warnings.length),
                  const SizedBox(width: 8),
                  _statusChip('DRAFT', AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organizer #${e['organizer_id']} • Capacity: ${e['max_capacity'] ?? '?'}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
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

  Widget _cancellationCard(Map<String, dynamic> e) {
    final cancel = e['pending_cancellation'] as Map<String, dynamic>? ?? {};
    final reason = cancel['reason'] ?? 'No reason given';
    final pct = cancel['pledge_percent'];
    final contextLabel = pct != null
        ? '$pct% funded — cancellation requires approval'
        : 'Cancellation requires admin approval';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      color: AppTheme.errorSurfaceOf(context),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => context.push('/events/${e['id']}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _statusChip('CANCELLATION', AppTheme.errorOf(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(contextLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.errorOf(context))),
              const SizedBox(height: 6),
              Text('Reason: $reason', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmAction(
                        'Approve Cancellation',
                        'Are you sure you want to approve the cancellation of "${e['title']}"?',
                        () => _decideCancellation(e['id'], 'approve'),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve Cancel'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.errorOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decideCancellation(e['id'], 'reject'),
                      icon: const Icon(Icons.shield, size: 18),
                      label: const Text('Keep Event'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.successOf(context)),
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

  Widget _extensionCard(Map<String, dynamic> e) {
    final ext = e['pending_extension'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => context.push('/events/${e['id']}', extra: {'readOnly': true}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  _statusChip('EXTENSION', AppTheme.warningOf(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Status: ${e['status']}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
              ),
              if (ext != null) ...[
                const SizedBox(height: 6),
                if (ext['funding_end_at'] != null)
                  Text('New funding deadline: ${_formatIsoDate(ext['funding_end_at'])}',
                      style: const TextStyle(fontSize: 13)),
                if (ext['funding_goal_cents'] != null)
                  Text('New funding goal: \$${((ext['funding_goal_cents'] as int) / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _decideExtension(e['id'], 'approve'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.successOf(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        'Reject Extension',
                        'Are you sure you want to reject this extension request?',
                        () => _decideExtension(e['id'], 'reject'),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorOf(context)),
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

  // ===========================================================================
  // SECTION 3: FINANCIAL
  // ===========================================================================

  Widget _buildFinancialSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'tickets', label: Text('Tickets (${_adminTickets.length})')),
              ButtonSegment(value: 'pledges', label: Text('Pledges (${_adminPledges.length})')),
              ButtonSegment(value: 'escrow', label: Text('Escrow (${_escrows.length})')),
            ],
            selected: {_financialSubTab},
            onSelectionChanged: (s) => setState(() {
              _financialSubTab = s.first;
              _financialSearch = '';
            }),
          ),
        ),
        if (_financialSubTab != 'escrow')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdminSearchBar(
              hint: _financialSubTab == 'tickets'
                  ? 'Search by event, attendee, or tier...'
                  : 'Search by event or user...',
              onChanged: (q) => setState(() => _financialSearch = q),
            ),
          ),
        // Summary strip
        _financialSummary(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _financialSubTab == 'tickets'
                ? _buildTicketsList()
                : _financialSubTab == 'pledges'
                    ? _buildPledgesList()
                    : _buildEscrowList(),
          ),
        ),
      ],
    );
  }

  Widget _financialSummary() {
    if (_financialSubTab == 'tickets') {
      final totalRevenue = _adminTickets.fold<int>(
          0, (sum, t) => sum + ((t['amount_paid_cents'] as int?) ?? 0));
      final refundRequested = _adminTickets.where((t) => t['status'] == 'refund_requested').length;
      return _summaryStrip([
        'Total sold: ${_adminTickets.length}',
        'Refund requested: $refundRequested',
        'Revenue: \$${(totalRevenue / 100).toStringAsFixed(2)}',
      ]);
    } else if (_financialSubTab == 'pledges') {
      final totalAmount = _adminPledges.fold<int>(
          0, (sum, p) => sum + ((p['amount_cents'] as int?) ?? 0));
      final guests = _adminPledges.where((p) => p['is_guest'] == true).length;
      return _summaryStrip([
        'Total pledges: ${_adminPledges.length}',
        'Total: \$${(totalAmount / 100).toStringAsFixed(2)}',
        'Guests: $guests',
      ]);
    } else {
      final totalHeld = _escrows.fold<int>(
          0, (sum, e) => sum + ((e['total_held_cents'] as int?) ?? 0));
      final totalReleased = _escrows.fold<int>(
          0, (sum, e) => sum + ((e['total_released_cents'] as int?) ?? 0));
      final frozenCount = _escrows.where((e) => e['status'] == 'frozen').length;
      return _summaryStrip([
        'Held: \$${(totalHeld / 100).toStringAsFixed(2)}',
        'Released: \$${(totalReleased / 100).toStringAsFixed(2)}',
        'Frozen: $frozenCount',
      ]);
    }
  }

  Widget _summaryStrip(List<String> items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: items.map((item) => Text(
          item,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryOf(context)),
        )).toList(),
      ),
    );
  }

  List<dynamic> get _filteredTickets {
    if (_financialSearch.isEmpty) return _adminTickets;
    return _adminTickets.where((t) {
      final s = _financialSearch;
      return (t['event_title'] ?? '').toString().toLowerCase().contains(s) ||
          (t['attendee_display_name'] ?? '').toString().toLowerCase().contains(s) ||
          (t['tier_name'] ?? '').toString().toLowerCase().contains(s);
    }).toList();
  }

  List<dynamic> get _filteredPledges {
    if (_financialSearch.isEmpty) return _adminPledges;
    return _adminPledges.where((p) {
      final s = _financialSearch;
      return (p['event_title'] ?? '').toString().toLowerCase().contains(s) ||
          (p['user_display_name'] ?? '').toString().toLowerCase().contains(s);
    }).toList();
  }

  Widget _buildTicketsList() {
    final tickets = _filteredTickets;
    if (tickets.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(icon: Icons.confirmation_number, message: 'No tickets found'),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final eventId = t['event_id'] as int;
        final ticketId = t['id'] as int;
        final status = t['status'] as String? ?? '';
        final amountCents = t['amount_paid_cents'] as int? ?? 0;
        final canApproveRefund = status == 'refund_requested';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(t['event_title'] ?? 'Event #$eventId',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${t['attendee_display_name'] ?? 'User #${t['user_id']}'} • ${t['tier_name'] ?? 'Ticket'} • \$${(amountCents / 100).toStringAsFixed(2)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusChip(status.toUpperCase().replaceAll('_', ' '),
                    _statusColor(status)),
                if (canApproveRefund) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.check_circle, color: AppTheme.successOf(context)),
                    tooltip: 'Approve refund',
                    onPressed: () => _confirmAction(
                      'Approve Refund',
                      'Approve refund for this ticket?',
                      () async {
                        await context.read<ApiService>().approveTicketRefund(eventId, ticketId);
                        _loadData();
                        _snack('Refund approved');
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPledgesList() {
    final pledges = _filteredPledges;
    if (pledges.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(icon: Icons.volunteer_activism, message: 'No pledges found'),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: pledges.length,
      itemBuilder: (ctx, i) {
        final p = pledges[i];
        final eventId = p['event_id'] as int;
        final fundingId = p['id'] as int;
        final amountCents = p['amount_cents'] as int? ?? 0;
        final isGuest = p['is_guest'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p['event_title'] ?? 'Event #$eventId',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${p['user_display_name'] ?? (isGuest ? 'Guest' : 'User #${p['user_id']}')} • \$${(amountCents / 100).toStringAsFixed(2)}${isGuest ? ' (donation)' : ''}',
            ),
            trailing: FilledButton.tonal(
              onPressed: () => _confirmAction(
                'Refund Pledge',
                'Are you sure you want to refund this pledge of \$${(amountCents / 100).toStringAsFixed(2)}?',
                () async {
                  await context.read<ApiService>().adminRefundPledge(eventId, fundingId);
                  _loadData();
                  _snack('Pledge refunded');
                },
              ),
              child: const Text('Refund'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEscrowList() {
    if (_escrows.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(
            icon: Icons.account_balance,
            message: 'No escrows yet',
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _escrows.length,
      itemBuilder: (ctx, i) => _escrowCard(_escrows[i]),
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
                _statusChip(status.toUpperCase().replaceAll('_', ' '), statusColor),
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

  // ===========================================================================
  // SECTION 4: USERS
  // ===========================================================================

  List<dynamic> get _filteredUsers {
    var list = _users;
    if (_userRoleFilter != 'all') {
      list = list.where((u) => u['role'] == _userRoleFilter).toList();
    }
    if (_userSearch.isNotEmpty) {
      list = list.where((u) {
        final name = (u['display_name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(_userSearch) || email.contains(_userSearch);
      }).toList();
    }
    return list;
  }

  Widget _buildUsersSection() {
    final roles = ['all', 'customer', 'organizer', 'sponsor', 'admin'];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminSearchBar(
              hint: 'Search by name or email...',
              onChanged: (q) => setState(() => _userSearch = q),
              resultCount: (_userSearch.isNotEmpty || _userRoleFilter != 'all') ? _filteredUsers.length : null,
              totalCount: (_userSearch.isNotEmpty || _userRoleFilter != 'all') ? _users.length : null,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: roles.map((role) {
                final selected = _userRoleFilter == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(role == 'all' ? 'All' : role[0].toUpperCase() + role.substring(1) + 's'),
                    selected: selected,
                    onSelected: (_) => setState(() => _userRoleFilter = role),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _filteredUsers.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 300,
                      child: AdminEmptyState(icon: Icons.people, message: 'No users found'),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (ctx, i) {
                      final user = _filteredUsers[i];
                      final name = user['display_name'] ?? 'No name';
                      final email = user['email'] ?? '';
                      final role = user['role'] ?? 'unknown';
                      final initial = (name != 'No name' ? name : email)
                          .toString()
                          .substring(0, 1)
                          .toUpperCase();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => context.push('/admin/users/${user['id']}'),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.surfaceOf(context),
                            child: Text(initial),
                          ),
                          title: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(email),
                          trailing: _statusChip(
                            role.toString().toUpperCase(),
                            _roleColor(role.toString()),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 5: SETTINGS (grouped)
  // ===========================================================================

  static const _settingsGroups = {
    'Branding': ['platform_name', 'support_email'],
    'Commissions': ['ticket_commission_percent', 'funding_commission_percent', 'sponsor_commission_percent'],
    'Escrow': ['escrow_stage1_percent', 'escrow_stage2_percent', 'escrow_stage3_percent', 'scan_threshold_percent', 'stage3_grace_days'],
    'Events': ['cancel_approval_threshold_percent', 'event_date_grace_days', 'event_date_deadline_days', 'default_refund_deadline_days'],
    'Community Rules': ['community_max_duration_days', 'community_max_ticket_price_cents', 'community_listing_fee_cents', 'community_funding_commission_override', 'new_organizer_deposit_cents'],
    'Rate Limits': ['max_tickets_per_purchase'],
    'Feature Flags': ['feature_milestones_enabled', 'feature_schedule_enabled', 'feature_sponsors_enabled'],
  };

  static const _groupIcons = {
    'Branding': Icons.palette,
    'Commissions': Icons.monetization_on,
    'Escrow': Icons.account_balance_wallet,
    'Events': Icons.event,
    'Community Rules': Icons.groups,
    'Rate Limits': Icons.speed,
    'Feature Flags': Icons.toggle_on_rounded,
  };

  Widget _buildSettingsSection() {
    if (_settings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: AdminEmptyState(icon: Icons.settings, message: 'No settings loaded'),
          ),
        ),
      );
    }

    final settingsMap = {for (var s in _settings) s['key']: s};

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _settingsGroups.entries.map((group) {
                final groupSettings = group.value
                    .map((k) => settingsMap[k])
                    .where((s) => s != null)
                    .toList();
                if (groupSettings.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                  child: ExpansionTile(
                    leading: Icon(_groupIcons[group.key] ?? Icons.settings, size: 22),
                    title: Text(group.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    initiallyExpanded: group.key == 'Commissions',
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: groupSettings.map((s) => _settingRow(s!)).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingRow(Map<String, dynamic> s) {
    final key = s['key'] ?? '';
    final value = s['value'] ?? '';
    final desc = s['description'] ?? '';
    final isPercent = key.contains('percent');
    final isCents = key.contains('_cents');
    final isBool = value == 'true' || value == 'false';

    String displayValue = value;
    if (isBool) {
      displayValue = value == 'true' ? 'ON' : 'OFF';
    } else if (isPercent) {
      displayValue = '$value%';
    } else if (isCents) {
      final parsed = int.tryParse(value);
      displayValue = parsed != null ? '\$${(parsed / 100).toStringAsFixed(2)}' : value;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isBool)
            Switch(
              value: value == 'true',
              activeColor: AppTheme.successOf(context),
              onChanged: (on) => _updateSetting(key, on ? 'true' : 'false'),
            )
          else ...[
            Text(displayValue,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentOf(context))),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit',
              onPressed: () => _showEditSettingDialog(key, value, isPercent),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTIONS & HELPERS
  // ===========================================================================

  List<String> _getWarnings(Map<String, dynamic> e) {
    final raw = e['validation_warnings'];
    if (raw is List) return raw.map((w) => w.toString()).toList();
    return [];
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat(_dateFormat).format(dt);
    } catch (_) {
      return iso;
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'purchased': return AppTheme.successOf(context);
      case 'refund_requested': return AppTheme.warningOf(context);
      case 'refunded': return AppTheme.errorOf(context);
      case 'waitlisted': return AppTheme.accentOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moving event to ${targetStatus.replaceAll('_', ' ')}',
                style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resolveReview(eventId, targetStatus, notes: notesCtrl.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEvent(int id, bool approve) async {
    try {
      final api = context.read<ApiService>();
      await api.adminApproveEvent(id, {
        'approved': approve,
        if (!approve) 'reason': 'Rejected by admin',
      });
      _loadData();
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideExtension(eventId, action);
      _loadData();
      _snack('Extension ${action}d');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/events/$eventId/cancellation/approve', data: {'action': action});
      _loadData();
      _snack('Cancellation ${action}d');
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
      _loadData();
      _snack('Event moved to ${targetStatus.replaceAll('_', ' ')}');
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
      _loadData();
      _snack('Escrow action completed');
    } catch (e) {
      _snack('Escrow action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _updateSetting(String key, String newValue) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.patch('/admin/settings/$key', data: {'value': newValue});
      _loadData();
      _snack('Setting "$key" updated');
    } catch (e) {
      _snack('Failed to update: ${ApiService.extractError(e)}');
    }
  }

  void _showEditSettingDialog(String key, String currentValue, bool isPercent) {
    final ctrl = TextEditingController(text: currentValue);
    String? errorText;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${key.replaceAll('_', ' ')}'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Value',
              suffixText: isPercent ? '%' : null,
              errorText: errorText,
            ),
            onChanged: (v) {
              if (isPercent) {
                final n = int.tryParse(v);
                setDialogState(() {
                  errorText = (n == null || n < 0 || n > 100) ? 'Must be 0-100' : null;
                });
              } else if (key.contains('_cents') || key.contains('_days')) {
                final n = int.tryParse(v);
                setDialogState(() {
                  errorText = (n == null || n < 0) ? 'Must be a non-negative number' : null;
                });
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: errorText != null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _updateSetting(key, ctrl.text.trim());
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ESCROW HELPERS
  // ===========================================================================

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
}
