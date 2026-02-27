import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/press_feedback.dart';
import '../../widgets/kyc_required_banner.dart';
import '../notification/notification_screen.dart';
import 'tabs/explore_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/manage_tab.dart';
import 'tabs/my_events_tab.dart';
import 'tabs/organizer_dashboard_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/sponsor_manage_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _navIndex;
  void Function()? _exploreRefresh;

  // Bookmarks — batch-checked once per event list load
  final Set<int> _bookmarkedIds = {};

  // City filter
  List<String> _cities = [];

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  // Explore tab initial filters (set when navigating from organizer dashboard)
  String? _exploreInitialStatus;
  String? _exploreInitialGenre;

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCities();
      final ep = context.read<EventProvider>();
      ep.addListener(_onEventsChanged);
    });
  }

  void _onEventsChanged() {
    final ep = context.read<EventProvider>();
    final ids = ep.events.map((e) => e.id).toList();
    _batchCheckBookmarks(ids);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _navIndex = widget.initialTab;
        _exploreInitialStatus = null;
        _exploreInitialGenre = null;
      });
    }
  }

  Future<void> _loadCities() async {
    try {
      final api = context.read<ApiService>();
      final cities = await api.getEventCities();
      if (mounted) setState(() => _cities = cities);
    } catch (_) {}
  }

  Future<void> _batchCheckBookmarks(List<int> eventIds) async {
    if (eventIds.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.checkBookmarks(eventIds);
      final ids = (res['bookmarked_ids'] as List?)?.cast<int>() ?? [];
      if (mounted) setState(() {
        _bookmarkedIds.addAll(ids);
      });
    } catch (_) {}
  }

  Future<void> _toggleBookmark(int eventId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.toggleBookmark(eventId);
      if (mounted) {
        setState(() {
          if (res['bookmarked'] == true) {
            _bookmarkedIds.add(eventId);
          } else {
            _bookmarkedIds.remove(eventId);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    context.read<EventProvider>().removeListener(_onEventsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);
    final isOrg = user != null && (user.isOrganizer || user.isAdmin);

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      body: IndexedStack(
        index: _navIndex,
        children: [
          if (isOrg)
            Column(
              children: [
                _orgGreeting(user!, isDark),
                if (user.kycStatus != 'verified' && !user.isAdmin)
                  const KycRequiredBanner(action: 'create and manage events'),
                Expanded(
                  child: OrganizerDashboardTab(
                    bookmarkedIds: _bookmarkedIds,
                    onToggleBookmark: _toggleBookmark,
                    onEventsLoaded: _batchCheckBookmarks,
                    onNavigateToExplore: (status, genre) {
                      setState(() {
                        _exploreInitialStatus = status;
                        _exploreInitialGenre = genre;
                        _navIndex = 1;
                      });
                      context.go('/?tab=explore');
                    },
                  ),
                ),
              ],
            )
          else
            HomeTab(
              bookmarkedIds: _bookmarkedIds,
              onToggleBookmark: _toggleBookmark,
              cities: _cities,
              genres: _genres,
              onRefresh: () {},
            ),
          ExploreTab(
            bookmarkedIds: _bookmarkedIds,
            onToggleBookmark: _toggleBookmark,
            cities: _cities,
            genres: _genres,
            initialStatus: _exploreInitialStatus,
            initialGenre: _exploreInitialGenre,
            onRefreshReady: (refresh) => _exploreRefresh = refresh,
          ),
          if (isOrg)
            ManageTab(
              onEventCreated: () => _exploreRefresh?.call(),
            )
          else if (user != null && user.isSponsor)
            const SponsorManageTab()
          else
            MyEventsTab(
              bookmarkedIds: _bookmarkedIds,
              onToggleBookmark: _toggleBookmark,
              onBookmarksSynced: (ids) =>
                  setState(() => _bookmarkedIds.addAll(ids)),
              genres: _genres,
            ),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          boxShadow: AppShadow.bottomBar(isDark),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
                _navItem(2, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Manage'),
                _navItem(3, Icons.person_rounded, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton:
          isOrg && _navIndex != 3
              ? PressFeedback(
                  child: FloatingActionButton(
                    onPressed: () async {
                      final created = await context.push<bool>('/events/create');
                      if (created == true && mounted) {
                        _exploreRefresh?.call();
                      }
                    },
                    backgroundColor: AppTheme.accentColor,
                    child: const Icon(Icons.add, color: Colors.white, size: AppIconSize.xl),
                  ),
                )
              : null,
    );
  }

  Widget _orgGreeting(dynamic user, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xxlValue),
          bottomRight: Radius.circular(AppRadius.xxlValue),
        ),
        boxShadow: AppShadow.soft(isDark),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppRadius.md,
                ),
                child: Center(
                  child: Text(
                    user.displayLabel[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              AppSpacing.hLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Here's your overview",
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      user.displayLabel ?? 'Guest',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Consumer<ChatProvider>(
                builder: (ctx, chatProv, _) {
                  final unread = chatProv.totalUnreadCount;
                  return GestureDetector(
                    onTap: () => context.push('/chat'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: AppRadius.md,
                      ),
                      child: Badge(
                        isLabelVisible: unread > 0,
                        label: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: AppTheme.accentColor,
                        child: Icon(Icons.chat_outlined,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                  );
                },
              ),
              AppSpacing.hSm,
              Consumer<NotificationProvider>(
                builder: (ctx, notifProv, _) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const NotificationScreen(),
                      ));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: AppRadius.md,
                      ),
                      child: Badge(
                        isLabelVisible: notifProv.unreadCount > 0,
                        label: Text(
                          notifProv.unreadCount > 99 ? '99+' : '${notifProv.unreadCount}',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: AppTheme.errorColor,
                        child: Icon(Icons.notifications_outlined,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                  );
                },
              ),
            ],
          )
              .animate()
              .fadeIn(duration: AppDuration.normal, curve: AppCurve.enter)
              .slideX(begin: -0.05, end: 0, duration: AppDuration.normal, curve: AppCurve.enter),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _navIndex == index;
    return GestureDetector(
      onTap: () {
        if (_navIndex == index) return;
        setState(() {
          _navIndex = index;
          if (index != 1) {
            _exploreInitialStatus = null;
            _exploreInitialGenre = null;
          }
        });
        const tabNames = ['home', 'explore', 'manage', 'profile'];
        final tab = tabNames[index];
        context.go(tab == 'home' ? '/' : '/?tab=$tab');
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.md,
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: AppIconSize.lg,
              color: isActive ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
