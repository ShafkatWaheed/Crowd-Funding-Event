import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../providers/admin_provider.dart';
import '../../repositories/base_repository.dart';
import 'admin_shared.dart';
import 'tabs/admin_banking_tab.dart';
import 'tabs/admin_email_tab.dart';
import 'tabs/admin_events_tab.dart';
import 'tabs/admin_home_tab.dart';
import 'tabs/admin_financial_tab.dart';
import 'tabs/admin_arq_tab.dart';
import 'tabs/admin_mock_tab.dart';
import 'tabs/admin_settings_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_kyc_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  int _selectedSection = 0;
  bool _isLoading = true;

  AdminStats? _stats;
  List<AdminEventItem> _allEvents = [];
  int _eventsTotal = 0;
  bool _eventsLoadingMore = false;
  List<PlatformSetting> _settings = [];
  List<AdminUserItem> _users = [];
  int _usersTotal = 0;
  AdminMockOverview? _mockData;
  int _eventFilterIndex = -1;

  List<AdminEventItem> get _pendingApproval =>
      _allEvents.where((e) => e.status == 'pending_approval').toList();
  List<AdminEventItem> get _underReviewEvents =>
      _allEvents.where((e) => e.status == 'under_review').toList();
  List<AdminEventItem> get _draftEvents =>
      _allEvents.where((e) => e.status == 'draft').toList();
  List<AdminEventItem> get _pendingCancellations =>
      _allEvents.where((e) => e.pendingCancellation != null).toList();
  List<AdminEventItem> get _pendingExtensions =>
      _allEvents.where((e) => e.pendingExtension != null).toList();

  int get _bottomNavIndex {
    const mapping = {0: 0, 3: 1, 4: 2};
    return mapping[_selectedSection] ?? 3;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMockData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loaders
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !user.isAdmin) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final admin = context.read<AdminProvider>();
    try {
      final results = await Future.wait([
        admin.getStats(),
        admin.getUsers(offset: 0, limit: adminPageSize),
        admin.getEvents(offset: 0, limit: adminPageSize),
        admin.getSettings(),
      ]);
      final usersResp = results[1] as AdminPage<AdminUserItem>;
      final eventsResp = results[2] as AdminPage<AdminEventItem>;
      setState(() {
        _stats = results[0] as AdminStats;
        _users = usersResp.items;
        _usersTotal = usersResp.total;
        _allEvents = eventsResp.items;
        _eventsTotal = eventsResp.total;
        _settings = results[3] as List<PlatformSetting>;
        if (_eventFilterIndex < 0) {
          _eventFilterIndex = _autoSelectEventFilter();
        }
      });
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getSettings();
      if (mounted) setState(() => _settings = data);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadEvents() async {
    try {
      final admin = context.read<AdminProvider>();
      final results = await Future.wait([
        admin.getEvents(offset: 0, limit: adminPageSize),
        admin.getStats(),
      ]);
      final eventsResp = results[0] as AdminPage<AdminEventItem>;
      if (mounted) {
        setState(() {
          _allEvents = eventsResp.items;
          _eventsTotal = eventsResp.total;
          _stats = results[1] as AdminStats;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadMoreEvents() async {
    if (_eventsLoadingMore || _allEvents.length >= _eventsTotal) return;
    setState(() => _eventsLoadingMore = true);
    try {
      final admin = context.read<AdminProvider>();
      final resp =
          await admin.getEvents(offset: _allEvents.length, limit: adminPageSize);
      setState(() {
        _allEvents.addAll(resp.items);
        _eventsTotal = resp.total;
      });
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _eventsLoadingMore = false);
  }

  Future<void> _loadMockData() async {
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getMockOverview();
      if (mounted) setState(() => _mockData = data);
    } catch (e) { debugPrint(e.toString()); }
  }

  int _autoSelectEventFilter() {
    if (_pendingApproval.isNotEmpty) return 0;
    if (_underReviewEvents.isNotEmpty) return 1;
    if (_draftEvents.isNotEmpty) return 2;
    if (_pendingCancellations.isNotEmpty) return 3;
    if (_pendingExtensions.isNotEmpty) return 4;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Actions & helpers
  // ---------------------------------------------------------------------------

  Future<void> _updateSetting(String key, String newValue) async {
    setState(() {
      final idx = _settings.indexWhere((s) => s.key == key);
      if (idx != -1) {
        _settings[idx] = PlatformSetting(
          key: key,
          value: newValue,
          description: _settings[idx].description,
        );
      }
    });
    try {
      final admin = context.read<AdminProvider>();
      await admin.updateSetting(key, newValue);
      _loadSettings();
      _snack('Setting "$key" updated');
    } catch (e) {
      _loadSettings();
      _snack('Failed to update: ${ApiError.extractMessage(e)}');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    _messengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.errorColor : null,
    ));
  }

  void _logout() async {
    await context.read<AuthProvider>().signOut();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.event), title: const Text('Events'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 1); }),
            ListTile(leading: const Icon(Icons.paid), title: const Text('Financial'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 2); }),
            ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 5); }),
            ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 6); }),
            ListTile(leading: const Icon(Icons.science_outlined), title: const Text('Mock'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 7); }),
            ListTile(leading: const Icon(Icons.schedule_send_rounded), title: const Text('ARQ Control'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 8); }),
            ListTile(leading: const Icon(Icons.verified_user), title: const Text('KYC Review'), onTap: () { Navigator.pop(ctx); setState(() => _selectedSection = 9); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= adminWideBreakpoint;
    final loadingBody = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(4, (_) => const ShimmerListTile()),
      ),
    );

    final sectionBody =
        _isLoading ? loadingBody : _bodyForSection(_selectedSection);

    final body = (_mockData != null && _selectedSection != 7)
        ? Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppTheme.warningSurface,
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined,
                        color: AppTheme.warningColor, size: 16),
                    const SizedBox(width: 6),
                    Text('Mock Mode Active',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context))),
                  ],
                ),
              ),
              Expanded(child: sectionBody),
            ],
          )
        : sectionBody;

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
                  BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard), label: 'Home'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.account_balance), label: 'Banking'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.people), label: 'Users'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz), label: 'More'),
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
                _navItem(8, Icons.schedule_send_rounded, 'ARQ'),
                _navItem(9, Icons.verified_user, 'KYC Review'),
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
      case 8: return 'ARQ Control';
      case 9: return 'KYC Review';
      default: return 'Admin';
    }
  }

  // ---------------------------------------------------------------------------
  // Tab routing
  // ---------------------------------------------------------------------------

  Widget _bodyForSection(int index) {
    switch (index) {
      case 0:
        return AdminHomeTab(
          stats: _stats,
          onSnack: _snack,
          onNavigateToSection: (section, filterIndex) => setState(() {
            _selectedSection = section;
            _eventFilterIndex = filterIndex;
          }),
        );
      case 1:
        return AdminEventsTab(
          events: _allEvents,
          eventsTotal: _eventsTotal,
          stats: _stats,
          onSnack: _snack,
          onEventsChanged: _loadEvents,
          onLoadMore: _loadMoreEvents,
          eventsLoadingMore: _eventsLoadingMore,
          initialEventFilterIndex: _eventFilterIndex,
        );
      case 2:
        return AdminFinancialTab(stats: _stats, onSnack: _snack);
      case 3:
        return AdminBankingTab(
          settings: _settings,
          onSnack: _snack,
          onUpdateSetting: _updateSetting,
          mockModeActive: _mockData?.mockModeActive == true,
        );
      case 4:
        return AdminUsersTab(
          users: _users,
          usersTotal: _usersTotal,
          onSnack: _snack,
          onLoadMore: (offset, limit, {search, role}) =>
              context.read<AdminProvider>().getUsers(
                    offset: offset,
                    limit: limit,
                    search: search,
                  ),
        );
      case 5:
        return AdminEmailTab(
          settings: _settings,
          onSnack: _snack,
          onUpdateSetting: _updateSetting,
          onReloadSettings: _loadSettings,
        );
      case 6:
        return AdminSettingsTab(
          settings: _settings,
          onUpdateSetting: _updateSetting,
          onReloadSettings: _loadSettings,
        );
      case 7:
        return AdminMockTab(
          onSnack: _snack,
          settings: _settings,
          onUpdateSetting: _updateSetting,
          onSettingsReload: _loadSettings,
        );
      case 8:
        return AdminArqTab(
          onSnack: _snack,
          settings: _settings,
          onUpdateSetting: _updateSetting,
        );
      case 9:
        return AdminKycTab(onSnack: _snack);
      default:
        return AdminHomeTab(
          stats: _stats,
          onSnack: _snack,
          onNavigateToSection: (section, filterIndex) => setState(() {
            _selectedSection = section;
            _eventFilterIndex = filterIndex;
          }),
        );
    }
  }
}
