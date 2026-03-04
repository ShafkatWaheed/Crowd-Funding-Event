import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/models/admin.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/theme_provider.dart';
import '../../lib/providers/admin_provider.dart';
import '../../lib/repositories/admin_repository.dart';
import '../../lib/screens/admin/admin_dashboard_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_admin_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAdminRepository mockAdmin;
  late MockThemeProvider mockTheme;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockAdmin = MockAdminRepository();
    mockTheme = MockThemeProvider();

    // Default: admin user
    when(() => mockAuth.user)
        .thenReturn(makeUser(role: UserRole.admin, email: 'admin@test.com'));

    // Theme provider stubs
    when(() => mockTheme.isDark).thenReturn(false);
    when(() => mockTheme.mode).thenReturn(ThemeMode.light);
    when(() => mockTheme.toggle()).thenAnswer((_) async {});

    // Stub admin repository calls that are made in initState._loadData
    when(() => mockAdmin.getStats()).thenAnswer((_) async => AdminStats(
          usersTotal: 100,
          eventsTotal: 25,
          eventsPending: 3,
          eventsLive: 10,
          totalTicketCommissionCents: 500000,
          totalFundingCommissionCents: 300000,
          totalEscrowHeldCents: 200000,
        ));
    when(() => mockAdmin.getUsers(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
        )).thenAnswer((_) async => AdminPage<AdminUserItem>(
          items: [
            AdminUserItem.fromJson(userJson(id: 1, email: 'user1@test.com', role: 'customer')),
            AdminUserItem.fromJson(userJson(id: 2, email: 'user2@test.com', role: 'organizer')),
          ],
          total: 2,
        ));
    when(() => mockAdmin.getEvents(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => AdminPage<AdminEventItem>(
          items: [
            AdminEventItem.fromJson(eventJson(
                id: 1, title: 'Pending Event', status: 'pending_approval')),
            AdminEventItem.fromJson(
                eventJson(id: 2, title: 'Active Event', status: 'approved')),
          ],
          total: 2,
        ));

    // Settings endpoint
    when(() => mockAdmin.getSettings()).thenAnswer((_) async => [
          PlatformSetting(key: 'maintenance_mode', value: 'false'),
          PlatformSetting(key: 'max_events', value: '100'),
        ]);

    // Mock overview
    when(() => mockAdmin.getMockOverview())
        .thenAnswer((_) async => AdminMockOverview());
  });

  /// Pump admin screen. Default surface (1080x1920) triggers wide layout
  /// (width >= 900 = adminWideBreakpoint) so NavigationRail is rendered
  /// instead of BottomNavigationBar.
  Future<void> pumpAdmin(WidgetTester tester) async {
    await pumpApp(
      tester,
      const AdminDashboardScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockTheme),
        ChangeNotifierProvider<AdminProvider>.value(value: AdminProvider(mockAdmin)),
      ],
    );
  }

  group('AdminDashboardScreen', () {
    testWidgets('renders navigation rail with section items', (tester) async {
      await pumpAdmin(tester);
      await tester.pumpAndSettle();

      // Wide layout renders a sidebar NavigationRail with all section items
      // instead of a BottomNavigationBar.
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Banking'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('home tab is the default section', (tester) async {
      await pumpAdmin(tester);
      await tester.pumpAndSettle();

      // Home is the default selected section; the ListTile should be present
      expect(find.text('Home'), findsOneWidget);
      // The sidebar title
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('users tab exists in navigation rail', (tester) async {
      await pumpAdmin(tester);
      await tester.pumpAndSettle();

      expect(find.text('Users'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsWidgets);
    });

    testWidgets('settings item visible in navigation rail', (tester) async {
      await pumpAdmin(tester);
      await tester.pumpAndSettle();

      // In wide layout, Settings is directly in the navigation rail
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsWidgets);

      // Financial is also directly accessible
      expect(find.text('Financial'), findsOneWidget);
    });

    testWidgets('renders correctly for admin user with logout button',
        (tester) async {
      await pumpAdmin(tester);
      await tester.pumpAndSettle();

      // Wide layout has the admin email in the sidebar footer
      expect(find.text('admin@test.com'), findsOneWidget);
      // Logout button in sidebar footer
      expect(find.byIcon(Icons.logout), findsWidgets);
    });
  });
}
