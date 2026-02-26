import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  int _selectedSection = 0;

  static const _pageSize = 20;

  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  int _usersTotal = 0;
  bool _usersLoadingMore = false;
  List<dynamic> _allEvents = [];
  int _eventsTotal = 0;
  bool _eventsLoadingMore = false;
  List<dynamic> _settings = [];
  List<dynamic> _escrows = [];
  int _escrowsTotal = 0;
  bool _escrowsLoadingMore = false;
  List<dynamic> _adminTickets = [];
  int _ticketsTotal = 0;
  bool _ticketsLoadingMore = false;
  List<dynamic> _adminPledges = [];
  int _pledgesTotal = 0;
  bool _pledgesLoadingMore = false;
  bool _isLoading = true;

  // Dashboard (home tab) state -- independent from _stats / _loadData
  Map<String, dynamic>? _dashboardData;
  bool _dashboardLoading = false;
  String _period = '30d';
  String? _filterGenre;
  String? _filterStatus;

  final _usersScrollCtrl = ScrollController();
  final _eventsScrollCtrl = ScrollController();
  final _ticketsScrollCtrl = ScrollController();
  final _pledgesScrollCtrl = ScrollController();
  final _escrowsScrollCtrl = ScrollController();

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

  // Banking / Mock / Email tab data
  Map<String, dynamic>? _bankingData;
  bool _bankingLoading = false;
  Map<String, dynamic>? _mockData;
  bool _mockLoading = false;
  List<dynamic> _emailTemplates = [];
  bool _emailLoading = false;

  // Escrow pipeline state
  List<dynamic> _ticketEscrows = [];
  List<dynamic> _sponsorEscrows = [];
  bool _pipelineLoading = false;
  String _pipelineSearch = '';
  String _pipelineTypeFilter = 'all';
  Map<String, dynamic>? _selectedEventEscrows;
  int? _selectedPipelineEventId;

  // Search/filter state
  String _eventSearch = '';
  int _eventFilterIndex = -1; // auto-detect on load
  String _financialSubTab = 'tickets';
  String _financialSearch = '';
  String _escrowSearch = '';
  String _ticketStatusFilter = 'all';
  String _pledgeStatusFilter = 'all';
  String _userSearch = '';
  String _userRoleFilter = 'all';

  int get _bottomNavIndex {
    const mapping = {0: 0, 3: 1, 4: 2};
    return mapping[_selectedSection] ?? 3;
  }

  void _onBottomNavTap(int i) {
    if (i == 3) {
      _showMoreSheet();
    } else {
      const mapping = {0: 0, 1: 3, 2: 4};
      setState(() => _selectedSection = mapping[i] ?? 0);
    }
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.event), title: const Text('Events'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 1); }),
            ListTile(leading: const Icon(Icons.paid), title: const Text('Financial'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 2); }),
            ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 5); }),
            ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 6); }),
            ListTile(leading: const Icon(Icons.science_outlined), title: const Text('Mock'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 7); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDashboard();
    _usersScrollCtrl.addListener(() => _onScroll(_usersScrollCtrl, _loadMoreUsers));
    _eventsScrollCtrl.addListener(() => _onScroll(_eventsScrollCtrl, _loadMoreEvents));
    _ticketsScrollCtrl.addListener(() => _onScroll(_ticketsScrollCtrl, _loadMoreTickets));
    _pledgesScrollCtrl.addListener(() => _onScroll(_pledgesScrollCtrl, _loadMorePledges));
    _escrowsScrollCtrl.addListener(() => _onScroll(_escrowsScrollCtrl, _loadMoreEscrows));
  }

  @override
  void dispose() {
    _userSearchDebounce?.cancel();
    _financialSearchDebounce?.cancel();
    _usersScrollCtrl.dispose();
    _eventsScrollCtrl.dispose();
    _ticketsScrollCtrl.dispose();
    _pledgesScrollCtrl.dispose();
    _escrowsScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll(ScrollController ctrl, VoidCallback loadMore) {
    if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200) {
      loadMore();
    }
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
        api.adminGetUsers(offset: 0, limit: _pageSize, search: _userSearch.isEmpty ? null : _userSearch),  // 1
        api.adminGetEvents(offset: 0, limit: _pageSize, search: _eventSearch.isEmpty ? null : _eventSearch),  // 2
        api.dio.get('/admin/settings'), // 3
        api.dio.get('/admin/escrows', queryParameters: {'offset': 0, 'limit': _pageSize, if (_escrowSearch.isNotEmpty) 'search': _escrowSearch}),  // 4
        api.adminGetTickets(offset: 0, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter),  // 5
        api.adminGetPledges(offset: 0, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _pledgeApiStatus, isDonation: _pledgeApiDonation),  // 6
      ]);
      final usersResp = results[1] as Map<String, dynamic>;
      final eventsResp = results[2] as Map<String, dynamic>;
      final escrowsResp = (results[4] as dynamic).data as Map<String, dynamic>;
      final ticketsResp = results[5] as Map<String, dynamic>;
      final pledgesResp = results[6] as Map<String, dynamic>;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = (usersResp['items'] as List<dynamic>?) ?? [];
        _usersTotal = (usersResp['total'] as int?) ?? 0;
        _allEvents = (eventsResp['items'] as List<dynamic>?) ?? [];
        _eventsTotal = (eventsResp['total'] as int?) ?? 0;
        _settings = (results[3] as dynamic).data as List<dynamic>;
        _escrows = (escrowsResp['items'] as List<dynamic>?) ?? [];
        _escrowsTotal = (escrowsResp['total'] as int?) ?? 0;
        _adminTickets = (ticketsResp['items'] as List<dynamic>?) ?? [];
        _ticketsTotal = (ticketsResp['total'] as int?) ?? 0;
        _adminPledges = (pledgesResp['items'] as List<dynamic>?) ?? [];
        _pledgesTotal = (pledgesResp['total'] as int?) ?? 0;
        if (_eventFilterIndex < 0) {
          _eventFilterIndex = _autoSelectEventFilter();
        }
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadDashboard() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !user.isAdmin) return;
    setState(() => _dashboardLoading = true);
    try {
      final data = await context.read<ApiService>().adminGetDashboard(
        period: _period,
        genre: _filterGenre,
        status: _filterStatus,
      );
      if (mounted) setState(() => _dashboardData = data);
    } catch (_) {}
    if (mounted) setState(() => _dashboardLoading = false);
  }

  void _onPeriodChanged(String p) {
    setState(() {
      _period = p;
      _filterGenre = null;
      _filterStatus = null;
    });
    _loadDashboard();
  }

  void _onGenreChanged(String? g) {
    setState(() {
      _filterGenre = g;
      _filterStatus = null;
    });
    _loadDashboard();
  }

  void _onStatusChanged(String? s) {
    setState(() => _filterStatus = s);
    _loadDashboard();
  }

  Future<void> _loadMoreUsers() async {
    if (_usersLoadingMore || _users.length >= _usersTotal) return;
    setState(() => _usersLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetUsers(offset: _users.length, limit: _pageSize, search: _userSearch.isEmpty ? null : _userSearch);
      final items = (resp['items'] as List<dynamic>?) ?? [];
      setState(() { _users.addAll(items); _usersTotal = (resp['total'] as int?) ?? _usersTotal; });
    } catch (_) {}
    if (mounted) setState(() => _usersLoadingMore = false);
  }

  Future<void> _loadMoreEvents() async {
    if (_eventsLoadingMore || _allEvents.length >= _eventsTotal) return;
    setState(() => _eventsLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetEvents(offset: _allEvents.length, limit: _pageSize, search: _eventSearch.isEmpty ? null : _eventSearch);
      final items = (resp['items'] as List<dynamic>?) ?? [];
      setState(() { _allEvents.addAll(items); _eventsTotal = (resp['total'] as int?) ?? _eventsTotal; });
    } catch (_) {}
    if (mounted) setState(() => _eventsLoadingMore = false);
  }

  String? get _pledgeApiStatus {
    if (_pledgeStatusFilter == 'all' || _pledgeStatusFilter == '_donation') return null;
    return _pledgeStatusFilter;
  }
  bool? get _pledgeApiDonation {
    if (_pledgeStatusFilter == '_donation') return true;
    return null;
  }

  Future<void> _loadMoreTickets() async {
    if (_ticketsLoadingMore || _adminTickets.length >= _ticketsTotal) return;
    setState(() => _ticketsLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetTickets(offset: _adminTickets.length, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter);
      final items = (resp['items'] as List<dynamic>?) ?? [];
      setState(() { _adminTickets.addAll(items); _ticketsTotal = (resp['total'] as int?) ?? _ticketsTotal; });
    } catch (_) {}
    if (mounted) setState(() => _ticketsLoadingMore = false);
  }

  Future<void> _loadMorePledges() async {
    if (_pledgesLoadingMore || _adminPledges.length >= _pledgesTotal) return;
    setState(() => _pledgesLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetPledges(offset: _adminPledges.length, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _pledgeApiStatus, isDonation: _pledgeApiDonation);
      final items = (resp['items'] as List<dynamic>?) ?? [];
      setState(() { _adminPledges.addAll(items); _pledgesTotal = (resp['total'] as int?) ?? _pledgesTotal; });
    } catch (_) {}
    if (mounted) setState(() => _pledgesLoadingMore = false);
  }

  Future<void> _loadMoreEscrows() async {
    if (_escrowsLoadingMore || _escrows.length >= _escrowsTotal) return;
    setState(() => _escrowsLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.get('/admin/escrows', queryParameters: {
        'offset': _escrows.length, 'limit': _pageSize,
        if (_escrowSearch.isNotEmpty) 'search': _escrowSearch,
      });
      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];
      setState(() { _escrows.addAll(items); _escrowsTotal = (data['total'] as int?) ?? _escrowsTotal; });
    } catch (_) {}
    if (mounted) setState(() => _escrowsLoadingMore = false);
  }

  Future<void> _loadSettings() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.get('/admin/settings');
      if (mounted) {
        setState(() => _settings = (resp.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.adminGetEvents(offset: 0, limit: _pageSize, search: _eventSearch.isEmpty ? null : _eventSearch),
        api.adminGetStats(),
      ]);
      final eventsResp = results[0] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _allEvents = (eventsResp['items'] as List<dynamic>?) ?? [];
          _eventsTotal = (eventsResp['total'] as int?) ?? 0;
          _stats = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTickets() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetTickets(offset: 0, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter);
      if (mounted) {
        setState(() {
          _adminTickets = (resp['items'] as List<dynamic>?) ?? [];
          _ticketsTotal = (resp['total'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPledges() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.adminGetPledges(offset: 0, limit: _pageSize, search: _financialSearch.isEmpty ? null : _financialSearch, status: _pledgeApiStatus, isDonation: _pledgeApiDonation);
      if (mounted) {
        setState(() {
          _adminPledges = (resp['items'] as List<dynamic>?) ?? [];
          _pledgesTotal = (resp['total'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEscrowsOnly() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.get('/admin/escrows', queryParameters: {
        'offset': 0, 'limit': _pageSize,
        if (_escrowSearch.isNotEmpty) 'search': _escrowSearch,
      });
      final data = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _escrows = (data['items'] as List<dynamic>?) ?? [];
          _escrowsTotal = (data['total'] as int?) ?? 0;
        });
      }
    } catch (_) {}
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

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: isWide
            ? null
            : AppBar(
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
        body: isWide
            ? Row(
                children: [
                  _buildNavigationRail(context),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: isWide
            ? null
            : BottomNavigationBar(
                currentIndex: _bottomNavIndex,
                onTap: _onBottomNavTap,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.accentOf(context),
                unselectedItemColor: AppTheme.textSecondaryOf(context),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Banking'),
                  BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                  BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
                ],
              ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final email = context.read<AuthProvider>().user?.email ?? '';
    final pendingCount = _pendingApproval.length +
        _underReviewEvents.length +
        _pendingCancellations.length +
        _pendingExtensions.length;

    return Container(
      width: 220,
      color: AppTheme.cardOf(context),
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
                _navItem(3, Icons.account_balance, 'Banking'),
                _navItem(4, Icons.people, 'Users'),
                _navItem(5, Icons.email_outlined, 'Email'),
                _navItem(6, Icons.settings, 'Settings'),
                _navItem(7, Icons.science_outlined, 'Mock'),
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
      case 3: return 'Banking';
      case 4: return 'Users';
      case 5: return 'Email';
      case 6: return 'Settings';
      case 7: return 'Mock';
      default: return 'Admin';
    }
  }

  Widget _bodyForSection(int index) {
    switch (index) {
      case 0: return _buildOverview();
      case 1: return _buildEventsSection();
      case 2: return _buildFinancialSection();
      case 3: return _buildBankingSection();
      case 4: return _buildUsersSection();
      case 5: return _buildEmailSection();
      case 6: return _buildSettingsSection();
      case 7: return _buildMockSection();
      default: return _buildOverview();
    }
  }

  // ===========================================================================
  // SECTION 1: HOME / OVERVIEW
  // ===========================================================================

  String _centsToStr(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Widget _buildOverview() {
    if (_dashboardData == null && !_dashboardLoading) {
      return const Center(child: Text('Failed to load dashboard'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterBar(),
                const SizedBox(height: AppSpacing.lg),
                if (_dashboardLoading && _dashboardData == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_dashboardData != null) ...[
                  _buildKpiChips(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildTimeSeriesSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildBreakdownSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildHealthAndEscrow(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildTopEvents(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildActionItems(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter Bar ──

  Widget _buildFilterBar() {
    final filters = _dashboardData?['available_filters'] as Map<String, dynamic>?;
    final genres = (filters?['genres'] as List?)?.cast<String>() ?? [];
    final statuses = (filters?['statuses'] as List?)?.cast<String>() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in ['7d', '30d', '90d', '130d', '1y'])
              ChoiceChip(
                label: Text(p),
                selected: _period == p,
                onSelected: (_) => _onPeriodChanged(p),
              ),
            const SizedBox(width: AppSpacing.sm),
            _filterDropdown<String>(
              hint: 'Genre',
              value: _filterGenre,
              items: genres.map((g) => DropdownMenuItem(value: g, child: Text(_capitalize(g)))).toList(),
              onChanged: _onGenreChanged,
            ),
            _filterDropdown<String>(
              hint: 'Status',
              value: _filterStatus,
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s)))).toList(),
              onChanged: _onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.inputFillOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          value: value,
          items: [
            DropdownMenuItem<T>(value: null, child: Text('All $hint', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13))),
            ...items,
          ],
          onChanged: onChanged,
          style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 13),
          dropdownColor: AppTheme.cardOf(context),
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryOf(context)),
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _statusLabel(String s) => s.replaceAll('_', ' ').split(' ').map(_capitalize).join(' ');

  // ── KPI Chips ──

  Widget _buildKpiChips() {
    final kpis = _dashboardData!['kpis'] as Map<String, dynamic>;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        AdminKpiCard(
          icon: Icons.paid,
          label: 'Total Revenue',
          value: _centsToStr((kpis['total_revenue_cents'] as num).toInt()),
          color: AppTheme.accentOf(context),
        ),
        AdminKpiCard(
          icon: Icons.confirmation_number,
          label: 'Ticket Commission',
          value: _centsToStr((kpis['ticket_commission_cents'] as num).toInt()),
          color: context.sponsorAccent,
        ),
        AdminKpiCard(
          icon: Icons.savings,
          label: 'Funding Commission',
          value: _centsToStr((kpis['funding_commission_cents'] as num).toInt()),
          color: context.ticketAccent,
        ),
        AdminKpiCard(
          icon: Icons.account_balance,
          label: 'Escrow Held',
          value: _centsToStr((kpis['escrow_held_cents'] as num).toInt()),
          color: context.fundingAccent,
        ),
        AdminKpiCard(
          icon: Icons.local_activity,
          label: 'Tickets Sold',
          value: '${kpis['tickets_sold'] ?? 0}',
          color: context.ticketAccent,
        ),
        AdminKpiCard(
          icon: Icons.volunteer_activism,
          label: 'Pledges Made',
          value: '${kpis['pledges_made'] ?? 0}',
          color: context.fundingAccent,
        ),
        AdminKpiCard(
          icon: Icons.event,
          label: 'Total Events',
          value: '${kpis['events_total'] ?? 0}',
          color: AppTheme.accentOf(context),
        ),
        AdminKpiCard(
          icon: Icons.event_available,
          label: 'Live Events',
          value: '${kpis['events_live'] ?? 0}',
          color: AppTheme.successOf(context),
        ),
        AdminKpiCard(
          icon: Icons.people,
          label: 'Total Users',
          value: '${kpis['users_total'] ?? 0}',
          color: context.managementAccent,
        ),
      ],
    );
  }

  // ── Time Series Charts ──

  Widget _buildTimeSeriesSection() {
    final points = (_dashboardData!['time_series'] as List?) ?? [];
    if (points.isEmpty) {
      return _emptyChartRow('Revenue Over Time', 'Activity Over Time');
    }
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _chartCard('Revenue Over Time', _buildRevenueChart(points))),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _chartCard('Activity Over Time', _buildActivityChart(points))),
        ],
      );
    }
    return Column(
      children: [
        _chartCard('Revenue Over Time', _buildRevenueChart(points)),
        const SizedBox(height: AppSpacing.lg),
        _chartCard('Activity Over Time', _buildActivityChart(points)),
      ],
    );
  }

  Widget _emptyChartRow(String title1, String title2) {
    final placeholder = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 40, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: 8),
            Text('No data for selected period',
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          ],
        ),
      ),
    );
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _chartCard(title1, placeholder)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _chartCard(title2, placeholder)),
        ],
      );
    }
    return Column(
      children: [
        _chartCard(title1, placeholder),
        const SizedBox(height: AppSpacing.lg),
        _chartCard(title2, placeholder),
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List points) {
    final isDark = AppTheme.isDark(context);
    final color = AppTheme.accentColor;
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      spots.add(FlSpot(i.toDouble(), ((p['revenue_cents'] as num?)?.toDouble() ?? 0) / 100));
    }
    if (spots.isEmpty) return const SizedBox.shrink();
    final maxY = spots.map((s) => s.y).reduce(math.max);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.dividerOf(context), strokeWidth: 0.5),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) =>
              LineTooltipItem('\$${s.y.toStringAsFixed(0)}', TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: spots.length <= 3),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildActivityChart(List points) {
    final isDark = AppTheme.isDark(context);
    final ticketColor = context.ticketAccent;
    final pledgeColor = context.fundingAccent;
    final ticketSpots = <FlSpot>[];
    final pledgeSpots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      ticketSpots.add(FlSpot(i.toDouble(), (p['tickets_sold'] as num?)?.toDouble() ?? 0));
      pledgeSpots.add(FlSpot(i.toDouble(), (p['pledges_count'] as num?)?.toDouble() ?? 0));
    }
    if (ticketSpots.isEmpty) return const SizedBox.shrink();
    final maxY = math.max(
      ticketSpots.map((s) => s.y).reduce(math.max),
      pledgeSpots.map((s) => s.y).reduce(math.max),
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.dividerOf(context), strokeWidth: 0.5),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final isTicket = s.barIndex == 0;
              return LineTooltipItem(
                isTicket ? '${s.y.toInt()} tickets' : '${s.y.toInt()} pledges',
                TextStyle(color: isTicket ? ticketColor : pledgeColor, fontWeight: FontWeight.w700, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ticketSpots, isCurved: ticketSpots.length > 2, curveSmoothness: 0.3,
            color: ticketColor, barWidth: 2.5, dotData: FlDotData(show: ticketSpots.length <= 3),
            belowBarData: BarAreaData(show: true, color: ticketColor.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
          LineChartBarData(
            spots: pledgeSpots, isCurved: pledgeSpots.length > 2, curveSmoothness: 0.3,
            color: pledgeColor, barWidth: 2.5, dotData: FlDotData(show: pledgeSpots.length <= 3),
            belowBarData: BarAreaData(show: true, color: pledgeColor.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  FlTitlesData _chartTitles(List points) {
    return FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: math.max(1, (points.length / 5).ceilToDouble()),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
            final dateStr = (points[idx] as Map)['date'] as String? ?? '';
            final dt = DateTime.tryParse(dateStr);
            if (dt == null) return const SizedBox.shrink();
            return Text(
              DateFormat.MMMd().format(dt),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
            );
          },
        ),
      ),
    );
  }

  // ── Breakdown Section (Genre Bar + Status Donut) ──

  Color _genreColor(String genre) {
    switch (genre) {
      case 'music': return context.sponsorAccent;
      case 'tech': return AppTheme.accentOf(context);
      case 'sports': return context.ticketAccent;
      case 'arts': return context.fundingAccent;
      case 'community': return AppTheme.successOf(context);
      case 'charity': return AppTheme.warningOf(context);
      case 'food': return AppTheme.errorOf(context);
      case 'education': return context.managementAccent;
      case 'business': return context.statusDraft;
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return context.statusDraft;
      case 'pending_approval': return context.statusPending;
      case 'approved': return context.statusApproved;
      case 'live': return context.statusLive;
      case 'selling_tickets': return context.statusSelling;
      case 'waiting_event_date': return context.statusWaiting;
      case 'completed': return context.statusCompleted;
      case 'cancelled': return context.statusCancelled;
      default: return context.statusDraft;
    }
  }

  Color _escrowStatusColor(String status) {
    switch (status) {
      case 'holding': return context.fundingAccent;
      case 'partially_released': return AppTheme.warningOf(context);
      case 'fully_released': return AppTheme.successOf(context);
      case 'refunded': return AppTheme.errorOf(context);
      case 'frozen': return context.managementAccent;
      case 'waived': return context.statusDraft;
      default: return context.statusDraft;
    }
  }

  Widget _buildBreakdownSection() {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildGenreBreakdown()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _buildStatusBreakdown()),
        ],
      );
    }
    return Column(
      children: [
        _buildGenreBreakdown(),
        const SizedBox(height: AppSpacing.lg),
        _buildStatusBreakdown(),
      ],
    );
  }

  Widget _buildGenreBreakdown() {
    final rows = (_dashboardData!['by_genre'] as List?) ?? [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final items = rows.cast<Map<String, dynamic>>();
    final maxRev = items.map((r) => (r['revenue_cents'] as num).toInt()).reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by Genre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            for (final r in items) ...[
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(_capitalize(r['genre'] as String), style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context))),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.dividerOf(context).withValues(alpha: 0.3),
                            borderRadius: AppRadius.sm,
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: maxRev > 0 ? (r['revenue_cents'] as num).toInt() / maxRev : 0,
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: _genreColor(r['genre'] as String),
                              borderRadius: AppRadius.sm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 70,
                    child: Text(
                      _centsToStr((r['revenue_cents'] as num).toInt()),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final rows = (_dashboardData!['by_status'] as List?) ?? [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final items = rows.cast<Map<String, dynamic>>();
    final total = items.fold<int>(0, (sum, r) => sum + (r['count'] as num).toInt());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Events by Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: items.map((r) {
                          final count = (r['count'] as num).toInt();
                          return PieChartSectionData(
                            value: count.toDouble(),
                            color: _statusColor(r['status'] as String),
                            radius: 40,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$total total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: AppSpacing.sm),
                      for (final r in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(r['status'] as String), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('${_statusLabel(r['status'] as String)} (${r['count']})', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Health Metrics + Escrow Breakdown ──

  Widget _buildHealthAndEscrow() {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildEscrowBreakdown()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _buildHealthMetrics()),
        ],
      );
    }
    return Column(
      children: [
        _buildEscrowBreakdown(),
        const SizedBox(height: AppSpacing.lg),
        _buildHealthMetrics(),
      ],
    );
  }

  Widget _buildEscrowBreakdown() {
    final rows = (_dashboardData!['by_escrow_status'] as List?) ?? [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final items = rows.cast<Map<String, dynamic>>();
    final total = items.fold<int>(0, (sum, r) => sum + (r['total_cents'] as num).toInt());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escrow Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: items.map((r) {
                          final cents = (r['total_cents'] as num).toInt();
                          return PieChartSectionData(
                            value: cents.toDouble(),
                            color: _escrowStatusColor(r['status'] as String),
                            radius: 40,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_centsToStr(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: AppSpacing.sm),
                      for (final r in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: _escrowStatusColor(r['status'] as String), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                '${_statusLabel(r['status'] as String)}  ${_centsToStr((r['total_cents'] as num).toInt())}',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetrics() {
    final kpis = _dashboardData!['kpis'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Health', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            _healthTile(Icons.sync, 'Refund Rate', '${(kpis['refund_rate_percent'] as num).toStringAsFixed(1)}%', AppTheme.errorOf(context)),
            _healthTile(Icons.local_activity, 'Avg Ticket Price', _centsToStr((kpis['avg_ticket_price_cents'] as num).toInt()), context.ticketAccent),
            _healthTile(Icons.flag, 'Funding Goal Hit Rate', '${(kpis['funding_goal_hit_rate_percent'] as num).toStringAsFixed(1)}%', AppTheme.successOf(context)),
            _healthTile(Icons.savings, 'Avg Funding / Event', _centsToStr((kpis['avg_funding_per_event_cents'] as num).toInt()), context.fundingAccent),
          ],
        ),
      ),
    );
  }

  Widget _healthTile(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.sm),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }

  // ── Top Events Leaderboard ──

  Widget _buildTopEvents() {
    final rows = (_dashboardData!['top_events'] as List?) ?? [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final items = rows.cast<Map<String, dynamic>>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Events by Revenue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(color: AppTheme.dividerOf(context), height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('#${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i]['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)), overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              if (items[i]['genre'] != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 6, top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.accentSurfaceOf(context), borderRadius: AppRadius.pill),
                                  child: Text(items[i]['genre'] as String, style: TextStyle(fontSize: 10, color: AppTheme.accentOf(context))),
                                ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: _statusColor(items[i]['status'] as String).withValues(alpha: 0.15), borderRadius: AppRadius.pill),
                                child: Text(_statusLabel(items[i]['status'] as String), style: TextStyle(fontSize: 10, color: _statusColor(items[i]['status'] as String))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_centsToStr((items[i]['revenue_cents'] as num).toInt()), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context))),
                        Text(
                          '${items[i]['tickets_sold']} tix · ${_centsToStr((items[i]['funding_cents'] as num).toInt())} funded',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Action Items ──

  Widget _buildActionItems() {
    final actions = _dashboardData!['action_items'] as Map<String, dynamic>?;
    if (actions == null) return const SizedBox.shrink();

    final pa = (actions['pending_approval'] as num?)?.toInt() ?? 0;
    final pc = (actions['pending_cancellations'] as num?)?.toInt() ?? 0;
    final pe = (actions['pending_extensions'] as num?)?.toInt() ?? 0;
    final ur = (actions['under_review'] as num?)?.toInt() ?? 0;
    final pr = (actions['pending_refunds'] as num?)?.toInt() ?? 0;

    if (pa == 0 && pc == 0 && pe == 0 && ur == 0 && pr == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Action Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: AppSpacing.sm),
        if (pa > 0)
          AdminActionCard(
            icon: Icons.pending_actions,
            count: pa,
            title: '$pa events waiting approval',
            subtitle: 'Review and approve pending events',
            color: AppTheme.accentOf(context),
            onTap: () => setState(() { _selectedSection = 1; _eventFilterIndex = 0; }),
          ),
        if (pc > 0)
          AdminActionCard(
            icon: Icons.cancel_outlined,
            count: pc,
            title: '$pc pending cancellations',
            subtitle: 'Review cancellation requests',
            color: AppTheme.errorOf(context),
            onTap: () => setState(() { _selectedSection = 1; _eventFilterIndex = 3; }),
          ),
        if (pe > 0)
          AdminActionCard(
            icon: Icons.schedule,
            count: pe,
            title: '$pe pending extensions',
            subtitle: 'Review extension requests',
            color: AppTheme.warningOf(context),
            onTap: () => setState(() { _selectedSection = 1; _eventFilterIndex = 4; }),
          ),
        if (ur > 0)
          AdminActionCard(
            icon: Icons.warning_amber_rounded,
            count: ur,
            title: '$ur under review',
            subtitle: 'Investigate and resolve flagged events',
            color: AppTheme.warningOf(context),
            onTap: () => setState(() { _selectedSection = 1; _eventFilterIndex = 1; }),
          ),
        if (pr > 0)
          AdminActionCard(
            icon: Icons.receipt_long,
            count: pr,
            title: '$pr pending refunds',
            subtitle: 'Process ticket refund requests',
            color: AppTheme.errorOf(context),
            onTap: () => setState(() { _selectedSection = 2; }),
          ),
      ],
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
                    controller: _eventsScrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length + (_eventsLoadingMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _filteredEvents.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      return _buildEventCard(_filteredEvents[i]);
                    },
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

  static const _ticketRefundStatuses = ['refund_requested', 'refund_processing', 'refunded', 'refund_failed'];
  static const _pledgeRefundStatuses = ['refund_processing', 'refunded', 'refund_failed'];

  Widget _buildFinancialSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'tickets', label: Text('Tickets ($_ticketsTotal)')),
              ButtonSegment(value: 'pledges', label: Text('Pledges ($_pledgesTotal)')),
              ButtonSegment(value: 'escrow', label: Text('Escrow ($_escrowsTotal)')),
            ],
            selected: {_financialSubTab},
            onSelectionChanged: (s) {
              setState(() {
                _financialSubTab = s.first;
                _financialSearch = '';
                _escrowSearch = '';
                _ticketStatusFilter = 'all';
                _pledgeStatusFilter = 'all';
              });
              _reloadFinancialData();
              _reloadEscrowData();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AdminSearchBar(
            hint: _financialSubTab == 'tickets'
                ? 'Search by event, attendee, or tier...'
                : _financialSubTab == 'pledges'
                    ? 'Search by event or user...'
                    : 'Search by event name or ID...',
            onChanged: _financialSubTab == 'escrow'
                ? _onEscrowSearchChanged
                : _onFinancialSearchChanged,
          ),
        ),
        if (_financialSubTab == 'tickets')
          _buildTicketFilterChips(),
        if (_financialSubTab == 'pledges')
          _buildPledgeFilterChips(),
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

  Widget _buildTicketFilterChips() {
    const regular = ['purchased', 'waitlisted', 'cancelled'];
    final selected = _ticketStatusFilter;
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
              onSelected: (_) { setState(() => _ticketStatusFilter = 'all'); _reloadFinancialData(); },
            ),
          ),
          ...regular.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_formatFilterStatus(s)),
              selected: selected == s,
              onSelected: (_) { setState(() => _ticketStatusFilter = s); _reloadFinancialData(); },
            ),
          )),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppTheme.dividerOf(context)),
          ..._ticketRefundStatuses.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(Icons.money_off, size: 16, color: selected == s ? null : AppTheme.errorOf(context)),
              label: Text(_formatFilterStatus(s)),
              selected: selected == s,
              onSelected: (_) { setState(() => _ticketStatusFilter = s); _reloadFinancialData(); },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPledgeFilterChips() {
    const regular = ['pledged', 'collected'];
    final selected = _pledgeStatusFilter;
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
              onSelected: (_) { setState(() => _pledgeStatusFilter = 'all'); _reloadFinancialData(); },
            ),
          ),
          ...regular.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_formatFilterStatus(s)),
              selected: selected == s,
              onSelected: (_) { setState(() => _pledgeStatusFilter = s); _reloadFinancialData(); },
            ),
          )),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppTheme.dividerOf(context)),
          ..._pledgeRefundStatuses.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(Icons.money_off, size: 16, color: selected == s ? null : AppTheme.errorOf(context)),
              label: Text(_formatFilterStatus(s)),
              selected: selected == s,
              onSelected: (_) { setState(() => _pledgeStatusFilter = s); _reloadFinancialData(); },
            ),
          )),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppTheme.dividerOf(context)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(Icons.card_giftcard, size: 16, color: selected == '_donation' ? null : AppTheme.warningOf(context)),
              label: const Text('Donations'),
              selected: selected == '_donation',
              onSelected: (_) { setState(() => _pledgeStatusFilter = selected == '_donation' ? 'all' : '_donation'); _reloadFinancialData(); },
            ),
          ),
        ],
      ),
    );
  }

  String _formatFilterStatus(String s) {
    return s.replaceAll('_', ' ').split(' ').map((w) =>
        w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join(' ');
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

  Timer? _financialSearchDebounce;

  void _onFinancialSearchChanged(String q) {
    _financialSearchDebounce?.cancel();
    _financialSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      _financialSearch = q;
      _reloadFinancialData();
    });
  }

  Future<void> _reloadFinancialData() async {
    final api = context.read<ApiService>();
    try {
      final search = _financialSearch.isEmpty ? null : _financialSearch;
      final ticketsResp = await api.adminGetTickets(offset: 0, limit: _pageSize, search: search, status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter);
      final pledgesResp = await api.adminGetPledges(offset: 0, limit: _pageSize, search: search, status: _pledgeApiStatus, isDonation: _pledgeApiDonation);
      if (mounted) {
        setState(() {
          _adminTickets = (ticketsResp['items'] as List<dynamic>?) ?? [];
          _ticketsTotal = (ticketsResp['total'] as int?) ?? 0;
          _adminPledges = (pledgesResp['items'] as List<dynamic>?) ?? [];
          _pledgesTotal = (pledgesResp['total'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Timer? _escrowSearchDebounce;

  void _onEscrowSearchChanged(String q) {
    _escrowSearchDebounce?.cancel();
    _escrowSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      _escrowSearch = q;
      _reloadEscrowData();
    });
  }

  Future<void> _reloadEscrowData() async {
    final api = context.read<ApiService>();
    try {
      final resp = await api.dio.get('/admin/escrows', queryParameters: {
        'offset': 0, 'limit': _pageSize,
        if (_escrowSearch.isNotEmpty) 'search': _escrowSearch,
      });
      final data = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _escrows = (data['items'] as List<dynamic>?) ?? [];
          _escrowsTotal = (data['total'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Widget _buildTicketsList() {
    final tickets = _adminTickets;
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
      controller: _ticketsScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length + (_ticketsLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= tickets.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
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
                    _ticketStatusColor(status)),
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
                        _loadTickets();
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
    final pledges = _adminPledges;
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
      controller: _pledgesScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: pledges.length + (_pledgesLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= pledges.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
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
                  _loadPledges();
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
      controller: _escrowsScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _escrows.length + (_escrowsLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _escrows.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        return _escrowCard(_escrows[i]);
      },
    );
  }

  Widget _escrowCard(Map<String, dynamic> e) {
    final eventId = e['event_id'] ?? 0;
    final eventTitle = e['event_title'] as String? ?? 'Event #$eventId';
    final organizerName = e['organizer_name'] as String?;
    final organizerEmail = e['organizer_email'] as String? ?? '';
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                      Text('Event #$eventId',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(status.toUpperCase().replaceAll('_', ' '), statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${organizerName ?? 'Unknown'} · $organizerEmail',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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

  Timer? _userSearchDebounce;

  List<dynamic> get _filteredUsers {
    var list = _users;
    if (_userRoleFilter != 'all') {
      list = list.where((u) => u['role'] == _userRoleFilter).toList();
    }
    return list;
  }

  void _onUserSearchChanged(String q) {
    _userSearchDebounce?.cancel();
    _userSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      _userSearch = q;
      final api = context.read<ApiService>();
      try {
        final resp = await api.adminGetUsers(offset: 0, limit: _pageSize, search: q.isEmpty ? null : q);
        if (mounted) {
          setState(() {
            _users = (resp['items'] as List<dynamic>?) ?? [];
            _usersTotal = (resp['total'] as int?) ?? 0;
          });
        }
      } catch (_) {}
    });
  }

  Widget _buildUsersSection() {
    final roles = ['all', 'customer', 'organizer', 'sponsor', 'admin'];
    final displayList = _filteredUsers;
    final showingCount = displayList.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminSearchBar(
              hint: 'Search by name or email...',
              onChanged: _onUserSearchChanged,
              resultCount: showingCount,
              totalCount: _usersTotal,
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
            child: displayList.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 300,
                      child: AdminEmptyState(icon: Icons.people, message: 'No users found'),
                    ),
                  )
                : ListView.builder(
                    controller: _usersScrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayList.length + (_usersLoadingMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= displayList.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final user = displayList[i];
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
                            backgroundColor: AppTheme.accentOf(context).withValues(alpha: 0.15),
                            foregroundColor: AppTheme.accentOf(context),
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
    'Escrow': ['escrow_stage1_percent', 'escrow_stage1_trigger_enabled', 'escrow_stage1_trigger_mode', 'escrow_stage1_ticket_percent', 'escrow_stage2_percent', 'escrow_stage2_trigger_enabled', 'escrow_stage2_trigger_mode', 'escrow_stage2_ticket_percent', 'escrow_stage2_days_percent', 'escrow_stage3_percent', 'escrow_stage3_trigger_enabled', 'escrow_stage3_trigger_mode', 'escrow_stage3_days_after_event', 'scan_threshold_percent', 'stage3_grace_days'],
    'Events': ['cancel_approval_threshold_percent', 'event_date_grace_days', 'event_date_deadline_days', 'default_refund_deadline_days'],
    'Community Rules': ['community_max_duration_days', 'community_max_ticket_price_cents', 'community_listing_fee_cents', 'community_ticket_commission_percent', 'community_funding_commission_percent', 'community_sponsor_commission_percent', 'community_escrow_disabled', 'new_organizer_deposit_cents'],
    'Rate Limits': ['max_tickets_per_purchase', 'max_tickets_backend_enabled', 'max_tickets_frontend_enabled'],
    'Feature Flags': ['feature_milestones_enabled', 'feature_schedule_enabled', 'feature_sponsors_enabled', 'feature_community_rules_enabled'],
    'Cache': ['cache_enabled', 'cache_ttl_settings', 'cache_ttl_featured', 'cache_ttl_event_detail', 'cache_ttl_dashboard'],
  };

  static const _groupIcons = {
    'Branding': Icons.palette,
    'Commissions': Icons.monetization_on,
    'Escrow': Icons.account_balance_wallet,
    'Events': Icons.event,
    'Community Rules': Icons.groups,
    'Rate Limits': Icons.speed,
    'Feature Flags': Icons.toggle_on_rounded,
    'Cache': Icons.cached,
  };

  // ===========================================================================
  // SECTION: BANKING
  // ===========================================================================

  Future<void> _loadBankingData() async {
    setState(() => _bankingLoading = true);
    try {
      final data = await ApiService.instance.get('/admin/banking-overview');
      if (mounted) setState(() { _bankingData = data; _bankingLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _bankingLoading = false);
    }
  }

  Widget _buildBankingSection() {
    if (_bankingData == null && !_bankingLoading) _loadBankingData();
    if (_bankingLoading || _bankingData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = _bankingData!;
    final mockActive = d['mock_mode_active'] == true;
    return RefreshIndicator(
      onRefresh: _loadBankingData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mockActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.warningSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Mock Mode Active — No real money is moving', style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            Text('Platform Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(d['platform_account_configured'] == true ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: d['platform_account_configured'] == true ? AppTheme.successColor : AppTheme.warningColor),
                    const SizedBox(width: 12),
                    Text(d['platform_account_configured'] == true ? 'Configured' : 'Not configured',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Escrow Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _escrowSummaryCard('Fund', d['fund_escrow_total_held_cents'] ?? 0, d['fund_escrow_total_released_cents'] ?? 0, d['fund_escrow_active_count'] ?? 0, AppTheme.fundingAccent)),
                const SizedBox(width: 8),
                Expanded(child: _escrowSummaryCard('Ticket', d['ticket_escrow_total_held_cents'] ?? 0, d['ticket_escrow_total_released_cents'] ?? 0, d['ticket_escrow_active_count'] ?? 0, AppTheme.ticketAccent)),
                const SizedBox(width: 8),
                Expanded(child: _escrowSummaryCard('Sponsor', d['sponsor_escrow_total_held_cents'] ?? 0, d['sponsor_escrow_total_released_cents'] ?? 0, d['sponsor_escrow_active_count'] ?? 0, AppTheme.sponsorAccent)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Commission & Tax', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _infoCard('Commission Total', _centsToStr(d['commission_total_cents'] ?? 0), Icons.attach_money, AppTheme.accentColor)),
                const SizedBox(width: 8),
                Expanded(child: _infoCard('Tax Collected', _centsToStr(d['tax_collected_total_cents'] ?? 0), Icons.receipt_long, AppTheme.warningColor)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Disputes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _infoCard('Open Disputes', '${d['disputes_open_count'] ?? 0}', Icons.gavel, AppTheme.errorColor)),
                const SizedBox(width: 8),
                Expanded(child: _infoCard('Disputed Amount', _centsToStr(d['disputes_total_amount_cents'] ?? 0), Icons.money_off, AppTheme.errorColor)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      d['last_reconciliation_status'] == 'balanced' ? Icons.check_circle : Icons.error,
                      color: d['last_reconciliation_status'] == 'balanced' ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d['last_reconciliation_status'] != null
                          ? 'Last: ${d['last_reconciliation_status']} (delta: ${_centsToStr((d['last_reconciliation_delta_cents'] ?? 0).abs())})'
                          : 'No reconciliation run yet',
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEscrowConfigUI(),
            const SizedBox(height: 16),
            _buildEscrowPipelineUI(),
          ],
        ),
      ),
    );
  }

  Widget _escrowSummaryCard(String label, int heldCents, int releasedCents, int activeCount, Color color) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Held: ${_centsToStr(heldCents)}', style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
            Text('Released: ${_centsToStr(releasedCents)}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
            Text('Active: $activeCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }

  // ── Escrow Config UI ──

  Widget _buildEscrowConfigUI() {
    final fundStages = [
      {'label': 'Stage 1', 'pct': 'escrow_stage1_percent'},
      {'label': 'Stage 2', 'pct': 'escrow_stage2_percent'},
      {'label': 'Stage 3', 'pct': 'escrow_stage3_percent'},
    ];
    final ticketStages = [
      {'label': 'Stage 1', 'pct': 'ticket_escrow_stage1_percent', 'days': 'ticket_escrow_stage1_days_after_event'},
      {'label': 'Stage 2', 'pct': 'ticket_escrow_stage2_percent', 'days': 'ticket_escrow_stage2_days_after_event', 'extra': 'ticket_escrow_stage2_max_refund_rate'},
      {'label': 'Stage 3', 'pct': 'ticket_escrow_stage3_percent', 'days': 'ticket_escrow_stage3_days_after_event', 'extra': 'ticket_escrow_stage3_require_no_disputes'},
    ];
    final sponsorStages = [
      {'label': 'Stage 1', 'pct': 'sponsor_escrow_stage1_percent', 'mode': 'sponsor_escrow_stage1_trigger_mode', 'days': 'sponsor_escrow_stage1_days_before_event'},
      {'label': 'Stage 2', 'pct': 'sponsor_escrow_stage2_percent', 'mode': 'sponsor_escrow_stage2_trigger_mode', 'days': 'sponsor_escrow_stage2_ticket_percent'},
      {'label': 'Stage 3', 'pct': 'sponsor_escrow_stage3_percent', 'mode': 'sponsor_escrow_stage3_trigger_mode', 'days': 'sponsor_escrow_stage3_days_after_event'},
    ];

    int fundSum = fundStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));
    int ticketSum = ticketStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));
    int sponsorSum = sponsorStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escrow Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        _escrowConfigTile('Fund Escrow', '${_settingVal('escrow_stage1_percent')}% / ${_settingVal('escrow_stage2_percent')}% / ${_settingVal('escrow_stage3_percent')}%',
          fundSum, AppTheme.fundingAccent, fundStages.map((st) => _escrowStageRow(st['label']!, st['pct']!)).toList()),
        const SizedBox(height: 8),
        _escrowConfigTile(
          'Ticket Escrow',
          '${_settingVal('ticket_escrow_stage1_percent')}% / ${_settingVal('ticket_escrow_stage2_percent')}% / ${_settingVal('ticket_escrow_stage3_percent')}%',
          ticketSum, AppTheme.ticketAccent,
          ticketStages.map((st) {
            return Column(children: [
              _escrowStageRow(st['label']!, st['pct']!),
              if (st['days'] != null) _mockInputRow('Days after event', st['days']!),
              if (st['extra'] != null && st['extra']!.contains('refund'))
                _mockInputRow('Max refund rate (%)', st['extra']!),
              if (st['extra'] != null && st['extra']!.contains('disputes'))
                _escrowBoolRow('Require no disputes', st['extra']!),
            ]);
          }).toList(),
        ),
        const SizedBox(height: 8),
        _escrowConfigTile(
          'Sponsor Escrow',
          '${_settingVal('sponsor_escrow_stage1_percent')}% / ${_settingVal('sponsor_escrow_stage2_percent')}% / ${_settingVal('sponsor_escrow_stage3_percent')}%',
          sponsorSum, AppTheme.sponsorAccent,
          sponsorStages.map((st) {
            return Column(children: [
              _escrowStageRow(st['label']!, st['pct']!),
              if (st['mode'] != null) _escrowModeRow('Trigger', st['mode']!),
              if (st['days'] != null) _mockInputRow('Param', st['days']!),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _escrowConfigTile(String title, String subtitle, int sum, Color color, List<Widget> children) {
    final valid = sum == 100;
    return Card(
      color: AppTheme.cardOf(context),
      child: ExpansionTile(
        leading: Icon(Icons.lock_clock, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(subtitle, style: TextStyle(color: valid ? AppTheme.textSecondaryOf(context) : AppTheme.errorColor)),
        trailing: valid
            ? Icon(Icons.check_circle, color: AppTheme.successColor, size: 20)
            : Text('$sum% (must = 100)', style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _escrowStageRow(String label, String key) {
    final val = double.tryParse(_settingVal(key)) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            child: Slider(
              value: val.clamp(0, 100),
              min: 0, max: 100, divisions: 100,
              label: '${val.round()}%',
              activeColor: AppTheme.accentOf(context),
              onChangeEnd: (v) => _updateSetting(key, v.round().toString()),
              onChanged: (v) => setState(() {
                final idx = _settings.indexWhere((s) => s['key'] == key);
                if (idx != -1) _settings[idx] = Map<String, dynamic>.from(_settings[idx] as Map)..['value'] = v.round().toString();
              }),
            ),
          ),
          SizedBox(width: 40, child: Text('${val.round()}%', textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accentOf(context)))),
        ],
      ),
    );
  }

  Widget _escrowBoolRow(String label, String key) {
    final val = _settingVal(key) == 'true';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Switch(value: val, activeColor: AppTheme.successOf(context),
            onChanged: (on) => _updateSetting(key, on ? 'true' : 'false')),
        ],
      ),
    );
  }

  Widget _escrowModeRow(String label, String key) {
    final val = _settingVal(key);
    final options = const {
      'sponsor_escrow_stage1_trigger_mode': ['event_live', 'days_before_event'],
      'sponsor_escrow_stage2_trigger_mode': ['event_started', 'ticket_percent'],
      'sponsor_escrow_stage3_trigger_mode': ['days_after_event', 'sponsor_confirmed'],
    };
    final opts = options[key] ?? [val];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          DropdownButton<String>(
            value: opts.contains(val) ? val : opts.first,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context)),
            items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))).toList(),
            onChanged: (v) { if (v != null) _updateSetting(key, v); },
          ),
        ],
      ),
    );
  }

  // ── Escrow Pipeline UI ──

  Future<void> _loadEscrowPipeline() async {
    setState(() => _pipelineLoading = true);
    try {
      final fundResp = await ApiService.instance.get('/admin/escrows', queryParams: {'limit': '50'});
      final ticketResp = await ApiService.instance.get('/admin/ticket-escrows', queryParams: {'limit': '50'});
      final sponsorResp = await ApiService.instance.get('/admin/sponsor-escrows', queryParams: {'limit': '50'});
      if (mounted) setState(() {
        _ticketEscrows = (ticketResp['items'] as List?) ?? [];
        _sponsorEscrows = (sponsorResp['items'] as List?) ?? [];
        _pipelineLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _pipelineLoading = false);
    }
  }

  Future<void> _loadEventEscrowDetail(int eventId) async {
    try {
      final data = await ApiService.instance.get('/admin/escrows/by-event/$eventId');
      if (mounted) setState(() { _selectedEventEscrows = data; _selectedPipelineEventId = eventId; });
    } catch (_) {}
  }

  Widget _buildEscrowPipelineUI() {
    if (_ticketEscrows.isEmpty && _sponsorEscrows.isEmpty && !_pipelineLoading) _loadEscrowPipeline();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Escrow Pipeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEscrowPipeline, iconSize: 20),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(label: const Text('All'), selected: _pipelineTypeFilter == 'all',
            selectedColor: AppTheme.accentOf(context).withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'all')),
          ChoiceChip(label: const Text('Fund'), selected: _pipelineTypeFilter == 'fund',
            selectedColor: AppTheme.fundingAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'fund')),
          ChoiceChip(label: const Text('Ticket'), selected: _pipelineTypeFilter == 'ticket',
            selectedColor: AppTheme.ticketAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'ticket')),
          ChoiceChip(label: const Text('Sponsor'), selected: _pipelineTypeFilter == 'sponsor',
            selectedColor: AppTheme.sponsorAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'sponsor')),
        ]),
        const SizedBox(height: 8),
        if (_pipelineLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'fund')
            ..._escrowRows.where((e) => e['_type'] == 'fund').map(_pipelineRow),
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'ticket')
            ..._escrowRows.where((e) => e['_type'] == 'ticket').map(_pipelineRow),
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'sponsor')
            ..._escrowRows.where((e) => e['_type'] == 'sponsor').map(_pipelineRow),
        ],
        if (_selectedEventEscrows != null && _selectedPipelineEventId != null) ...[
          const SizedBox(height: 12),
          _buildEventEscrowDetail(_selectedPipelineEventId!, _selectedEventEscrows!),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> get _escrowRows {
    final rows = <Map<String, dynamic>>[];
    for (final e in _escrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'fund'});
    for (final e in _ticketEscrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'ticket'});
    for (final e in _sponsorEscrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'sponsor'});
    return rows;
  }

  Widget _pipelineRow(Map<String, dynamic> e) {
    final type = e['_type'] as String;
    final color = type == 'fund' ? AppTheme.fundingAccent : type == 'ticket' ? AppTheme.ticketAccent : AppTheme.sponsorAccent;
    final statusStr = e['status'] ?? 'holding';
    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Text(type[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        title: Text(e['event_title'] ?? 'Event #${e['event_id']}', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context), fontSize: 14)),
        subtitle: Row(children: [
          _stageDot(e['stage1_released_at']),
          _stageDot(e['stage2_released_at']),
          _stageDot(e['stage3_released_at']),
          const SizedBox(width: 8),
          Text('${_centsToStr(e['total_held_cents'] ?? 0)} held', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ]),
        trailing: Chip(
          label: Text(statusStr, style: const TextStyle(fontSize: 11)),
          backgroundColor: _escrowStatusChipColor(statusStr),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => _loadEventEscrowDetail(e['event_id']),
      ),
    );
  }

  Widget _stageDot(dynamic releasedAt) {
    final released = releasedAt != null;
    return Container(
      width: 12, height: 12,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: released ? AppTheme.successColor : Colors.grey.shade400,
      ),
    );
  }

  Color _escrowStatusChipColor(String status) {
    switch (status) {
      case 'fully_released': return AppTheme.successColor.withOpacity(0.2);
      case 'partially_released': return AppTheme.warningColor.withOpacity(0.2);
      case 'frozen': return AppTheme.errorColor.withOpacity(0.2);
      case 'refunded': return Colors.purple.withOpacity(0.2);
      default: return AppTheme.accentColor.withOpacity(0.15);
    }
  }

  Widget _buildEventEscrowDetail(int eventId, Map<String, dynamic> data) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Event #$eventId — All Escrows', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _selectedEventEscrows = null; _selectedPipelineEventId = null; })),
            ]),
            const SizedBox(height: 8),
            if (data['fund'] != null) _escrowDetailColumn('Fund', data['fund'], 'fund', eventId),
            if (data['ticket'] != null) _escrowDetailColumn('Ticket', data['ticket'], 'ticket', eventId),
            if (data['sponsor'] != null) _escrowDetailColumn('Sponsor', data['sponsor'], 'sponsor', eventId),
            if (data['fund'] == null && data['ticket'] == null && data['sponsor'] == null)
              Text('No escrow records for this event.', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }

  Widget _escrowDetailColumn(String label, Map<String, dynamic> esc, String type, int eventId) {
    final color = type == 'fund' ? AppTheme.fundingAccent : type == 'ticket' ? AppTheme.ticketAccent : AppTheme.sponsorAccent;
    final stages = [
      {'n': 1, 'cents': esc['stage1_released_cents'] ?? 0, 'at': esc['stage1_released_at']},
      {'n': 2, 'cents': esc['stage2_released_cents'] ?? 0, 'at': esc['stage2_released_at']},
      {'n': 3, 'cents': esc['stage3_released_cents'] ?? 0, 'at': esc['stage3_released_at']},
    ];
    final frozen = esc['status'] == 'frozen';
    final prefix = type == 'fund' ? '' : '$type-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label — ${esc['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          Text('Held: ${_centsToStr(esc['total_held_cents'] ?? 0)} | Released: ${_centsToStr(esc['total_released_cents'] ?? 0)} | Remaining: ${_centsToStr(esc['remaining_cents'] ?? 0)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 4),
          ...stages.map((st) {
            final released = st['at'] != null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(released ? Icons.check_circle : Icons.radio_button_unchecked, color: released ? AppTheme.successColor : Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text('Stage ${st['n']}: ${_centsToStr(st['cents'] as int)}', style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                if (!released && !frozen) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final path = type == 'fund'
                          ? '/admin/escrows/$eventId/release/${st['n']}'
                          : '/admin/$type-escrows/$eventId/release/${st['n']}';
                      try {
                        await ApiService.instance.post(path, {});
                        _loadEventEscrowDetail(eventId);
                        _loadEscrowPipeline();
                        _loadEscrowsOnly();
                        _snack('$label Stage ${st['n']} released');
                      } catch (e) {
                        _snack('Release failed: ${ApiService.extractError(e)}');
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
                  final path = type == 'fund' ? '/admin/escrows/$eventId/freeze' : '/admin/$type-escrows/$eventId/freeze';
                  await ApiService.instance.post(path, {});
                  _loadEventEscrowDetail(eventId);
                  _loadEscrowPipeline();
                },
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Unfreeze', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final path = type == 'fund' ? '/admin/escrows/$eventId/unfreeze' : '/admin/$type-escrows/$eventId/unfreeze';
                  await ApiService.instance.post(path, {});
                  _loadEventEscrowDetail(eventId);
                  _loadEscrowPipeline();
                },
              ),
          ]),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION: EMAIL
  // ===========================================================================

  Future<void> _loadEmailTemplates() async {
    setState(() => _emailLoading = true);
    try {
      final data = await ApiService.instance.get('/admin/email-templates');
      if (mounted) setState(() { _emailTemplates = data is List ? data : []; _emailLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Widget _buildEmailSection() {
    if (_emailTemplates.isEmpty && !_emailLoading) _loadEmailTemplates();
    if (_emailLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadEmailTemplates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configure email provider and templates from platform settings.', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 8),
                    Text('Provider settings: email_enabled, email_provider, email_from_address, email_from_name',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Email Templates (${_emailTemplates.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            if (_emailTemplates.isEmpty)
              Card(
                color: AppTheme.cardOf(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No custom templates. All emails use default hardcoded templates.', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                ),
              ),
            ..._emailTemplates.map((t) => Card(
              color: AppTheme.cardOf(context),
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(t['template_key'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
                subtitle: Text(t['subject'] ?? '', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
                trailing: Icon(t['is_active'] == true ? Icons.check_circle : Icons.cancel, color: t['is_active'] == true ? AppTheme.successColor : AppTheme.errorColor, size: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Variables: ${t['variables'] ?? '[]'}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Test Send'),
                              onPressed: () async {
                                try {
                                  await ApiService.instance.post('/admin/email-templates/${t['template_key']}/test-send', {});
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test email sent')));
                                } catch (_) {}
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Reset'),
                              onPressed: () async {
                                try {
                                  await ApiService.instance.post('/admin/email-templates/${t['template_key']}/reset', {});
                                  _loadEmailTemplates();
                                } catch (_) {}
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION: MOCK
  // ===========================================================================

  Future<void> _loadMockData() async {
    setState(() => _mockLoading = true);
    try {
      final data = await ApiService.instance.get('/admin/mock-overview');
      if (mounted) setState(() { _mockData = data; _mockLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _mockLoading = false);
    }
  }

  Widget _buildMockSection() {
    if (_mockData == null && !_mockLoading) _loadMockData();
    if (_mockLoading || _mockData == null) return const Center(child: CircularProgressIndicator());
    final d = _mockData!;

    return RefreshIndicator(
      onRefresh: _loadMockData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.warningSurface, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Mock Mode — All payments and emails are simulated', style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            Text('Mock Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _infoCard('Transactions', '${d['total_transactions'] ?? 0}', Icons.receipt, AppTheme.accentColor),
                _infoCard('Volume', _centsToStr(d['total_volume_cents'] ?? 0), Icons.attach_money, AppTheme.successColor),
                _infoCard('Success Rate', '${d['success_rate'] ?? 100}%', Icons.check_circle, AppTheme.successColor),
                _infoCard('Emails', '${d['total_emails'] ?? 0}', Icons.email, AppTheme.accentColor),
                _infoCard('Bounce Rate', '${d['email_bounce_rate'] ?? 0}%', Icons.error_outline, AppTheme.warningColor),
              ],
            ),
            const SizedBox(height: 16),
            Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear All Mock Data'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Mock Data?'),
                        content: const Text('This will delete all mock transactions and emails. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ApiService.instance.post('/admin/mock/clear', {});
                      _loadMockData();
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Settle All Pending'),
                  onPressed: () async {
                    await ApiService.instance.post('/admin/mock/settle-all', {});
                    _loadMockData();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.error_outline, size: 18),
                  label: const Text('Fail Next Charge'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor, foregroundColor: Colors.white),
                  onPressed: () async {
                    await ApiService.instance.post('/admin/mock/fail-next', {});
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Next charge will fail')));
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Reset to Defaults'),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset Mock Settings?'),
                        content: const Text('All mock parameters will be reset to their default values.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ApiService.instance.post('/admin/mock/reset-defaults', {});
                      _loadSettings();
                      _loadMockData();
                      if (mounted) _snack('Mock settings reset to defaults');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMockTuneables(),
            const SizedBox(height: 16),
            Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            ...((d['recent_transactions'] as List? ?? []).map((t) => Card(
              color: AppTheme.cardOf(context),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(_mockOpIcon(t['operation']), color: _mockStatusColor(t['status']), size: 24),
                title: Text('${t['operation']} — ${_centsToStr(t['amount_cents'] ?? 0)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                subtitle: Text('${t['from_account']} → ${t['to_account']}\n${t['status']}${t['failure_reason'] != null ? ' (${t['failure_reason']})' : ''}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                trailing: Text(t['authorization_code'] ?? '', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
                isThreeLine: true,
              ),
            ))),
            const SizedBox(height: 16),
            Text('Recent Emails', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            ...((d['recent_emails'] as List? ?? []).map((e) => Card(
              color: AppTheme.cardOf(context),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(e['status'] == 'bounced' ? Icons.error : Icons.check_circle,
                  color: e['status'] == 'bounced' ? AppTheme.errorColor : AppTheme.successColor, size: 20),
                title: Text(e['subject'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                subtitle: Text('To: ${e['to_email']} — ${e['template_key'] ?? 'custom'}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
              ),
            ))),
          ],
        ),
      ),
    );
  }

  IconData _mockOpIcon(String? op) {
    switch (op) {
      case 'charge': return Icons.credit_card;
      case 'transfer': return Icons.swap_horiz;
      case 'refund': return Icons.replay;
      case 'hold': return Icons.lock;
      case 'release': return Icons.lock_open;
      default: return Icons.receipt;
    }
  }

  Color _mockStatusColor(String? status) {
    switch (status) {
      case 'completed': case 'settled': return AppTheme.successColor;
      case 'failed': return AppTheme.errorColor;
      case 'processing': case 'settlement_pending': return AppTheme.warningColor;
      default: return AppTheme.accentColor;
    }
  }

  String _settingVal(String key) {
    final s = _settings.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s?['key'] == key, orElse: () => null,
    );
    return s?['value']?.toString() ?? '';
  }

  Widget _buildMockTuneables() {
    final feePercent = double.tryParse(_settingVal('mock_stripe_fee_percent')) ?? 2.9;
    final feeFixed = int.tryParse(_settingVal('mock_stripe_fee_fixed_cents')) ?? 30;
    final sampleFee = (5000 * feePercent / 100).round() + feeFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mockSliderRow('Charge Latency Min (ms)', 'mock_charge_latency_min_ms', 0, 10000),
                _mockSliderRow('Charge Latency Max (ms)', 'mock_charge_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Transfer Latency Min (ms)', 'mock_transfer_latency_min_ms', 0, 10000),
                _mockSliderRow('Transfer Latency Max (ms)', 'mock_transfer_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Refund Latency Min (ms)', 'mock_refund_latency_min_ms', 0, 10000),
                _mockSliderRow('Refund Latency Max (ms)', 'mock_refund_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Failure Rate (%)', 'mock_failure_rate_percent', 0, 50),
                _mockSliderRow('Settlement Delay (s)', 'mock_settlement_delay_seconds', 0, 86400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Fee Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mockInputRow('Fee Percent', 'mock_stripe_fee_percent'),
                _mockInputRow('Fixed Fee (cents)', 'mock_stripe_fee_fixed_cents'),
                const SizedBox(height: 8),
                Text('Preview: on a \$50.00 charge, fee = \$${(sampleFee / 100).toStringAsFixed(2)}, net = \$${((5000 - sampleFee) / 100).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Email Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _mockSliderRow('Bounce Rate (%)', 'mock_email_bounce_rate_percent', 0, 50),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockSliderRow(String label, String key, double min, double max) {
    final val = double.tryParse(_settingVal(key)) ?? min;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            child: Slider(
              value: val.clamp(min, max),
              min: min, max: max,
              divisions: ((max - min) / (max > 1000 ? 100 : 1)).round().clamp(1, 500),
              label: val.round().toString(),
              activeColor: AppTheme.accentOf(context),
              onChangeEnd: (v) => _updateSetting(key, v.round().toString()),
              onChanged: (v) {
                setState(() {
                  final idx = _settings.indexWhere((s) => s['key'] == key);
                  if (idx != -1) {
                    _settings[idx] = Map<String, dynamic>.from(_settings[idx] as Map)..['value'] = v.round().toString();
                  }
                });
              },
            ),
          ),
          SizedBox(width: 50, child: Text(val.round().toString(), textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accentOf(context)))),
        ],
      ),
    );
  }

  Widget _mockInputRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          SizedBox(
            width: 120,
            child: TextField(
              controller: TextEditingController(text: _settingVal(key)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryOf(context)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accentOf(context))),
              ),
              onSubmitted: (v) => _updateSetting(key, v),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION: SETTINGS
  // ===========================================================================

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

  static const _triggerModeOptions = <String, List<String>>{
    'escrow_stage1_trigger_mode': ['ticket_percent', 'funding_end', 'selling_started'],
    'escrow_stage2_trigger_mode': ['ticket_percent', 'days_percent'],
    'escrow_stage3_trigger_mode': ['days_after', 'scan_threshold'],
  };

  Widget _settingRow(Map<String, dynamic> s) {
    final key = s['key'] ?? '';
    final value = s['value'] ?? '';
    final desc = s['description'] ?? '';
    final isPercent = key.contains('percent');
    final isCents = key.contains('_cents');
    final isBool = value == 'true' || value == 'false';
    final isDropdown = _triggerModeOptions.containsKey(key);

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
          else if (isDropdown)
            DropdownButton<String>(
              value: _triggerModeOptions[key]!.contains(value) ? value : _triggerModeOptions[key]!.first,
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context)),
              items: _triggerModeOptions[key]!.map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt.replaceAll('_', ' ')),
              )).toList(),
              onChanged: (v) { if (v != null) _updateSetting(key, v); },
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

  Color _ticketStatusColor(String status) {
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
      case 'customer': return AppTheme.successOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    _messengerKey.currentState
        ?.showSnackBar(SnackBar(content: Text(msg)));
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
      _loadEvents();
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideExtension(eventId, action);
      _loadEvents();
      _snack('Extension ${action}d');
    } catch (e) {
      _snack('Action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/events/$eventId/cancellation/approve', data: {'action': action});
      _loadEvents();
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
      _loadEvents();
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
      _loadEscrowsOnly();
      _snack('Escrow action completed');
    } catch (e) {
      _snack('Escrow action failed: ${ApiService.extractError(e)}');
    }
  }

  Future<void> _updateSetting(String key, String newValue) async {
    setState(() {
      final idx = _settings.indexWhere((s) => s['key'] == key);
      if (idx != -1) {
        _settings[idx] = Map<String, dynamic>.from(_settings[idx])
          ..['value'] = newValue;
      }
    });
    try {
      final api = context.read<ApiService>();
      await api.dio.patch('/admin/settings/$key', data: {'value': newValue});
      _loadSettings();
      _snack('Setting "$key" updated');
    } catch (e) {
      _loadSettings();
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
