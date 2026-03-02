import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/theme_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/admin/admin_dashboard_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

/// Mock for Dio Response used in admin settings loading.
class MockResponse extends Mock implements Response<dynamic> {}

void main() {
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;
  late MockThemeProvider mockTheme;

  setUpAll(() {
    // Register fallback values for types used in any() matchers
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();
    mockTheme = MockThemeProvider();

    // Set ApiService.instance so _loadMockData does not crash
    ApiService.instance = mockApi;

    // Default: admin user
    when(() => mockAuth.user)
        .thenReturn(makeUser(role: UserRole.admin, email: 'admin@test.com'));

    // Theme provider stubs
    when(() => mockTheme.isDark).thenReturn(false);
    when(() => mockTheme.mode).thenReturn(ThemeMode.light);
    when(() => mockTheme.toggle()).thenAnswer((_) async {});

    // Stub admin API calls that are made in initState._loadData
    when(() => mockApi.adminGetStats()).thenAnswer((_) async => {
          'total_users': 100,
          'total_events': 25,
          'total_pledges': 500,
          'total_revenue_cents': 1000000,
          'pending_events': 3,
          'pending_kyc': 2,
        });
    when(() => mockApi.adminGetUsers(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
        )).thenAnswer((_) async => {
          'items': [
            userJson(id: 1, email: 'user1@test.com', role: 'customer'),
            userJson(id: 2, email: 'user2@test.com', role: 'organizer'),
          ],
          'total': 2,
        });
    when(() => mockApi.adminGetEvents(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => {
          'items': [
            eventJson(
                id: 1, title: 'Pending Event', status: 'pending_approval'),
            eventJson(id: 2, title: 'Active Event', status: 'approved'),
          ],
          'total': 2,
        });

    // Settings endpoint returns via dio.get — stub with all optional params
    final settingsResponse = MockResponse();
    when(() => settingsResponse.data).thenReturn(<dynamic>[
      <String, dynamic>{'key': 'maintenance_mode', 'value': 'false'},
      <String, dynamic>{'key': 'max_events', 'value': '100'},
    ]);
    when(() => mockApi.mockDio.get(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        )).thenAnswer((_) async => settingsResponse);

    // _loadMockData calls ApiService.instance.get('/admin/mock-overview')
    when(() => mockApi.get('/admin/mock-overview'))
        .thenAnswer((_) async => <String, dynamic>{});
    when(() => mockApi.get(any()))
        .thenAnswer((_) async => <String, dynamic>{});
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
        Provider<ApiService>.value(value: mockApi),
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
