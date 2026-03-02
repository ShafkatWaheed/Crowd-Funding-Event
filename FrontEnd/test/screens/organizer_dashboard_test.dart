import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/home/tabs/organizer_dashboard_tab.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;
  late Set<int> bookmarkedIds;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();
    bookmarkedIds = <int>{};

    // Default: logged-in organizer
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  /// Build a properly structured KPI map entry used by DashboardKpiSection.
  Map<String, dynamic> _kpi(dynamic value, {dynamic delta, double? pct}) => {
        'value': value,
        'delta': delta ?? 0,
        'change_pct': pct ?? 0.0,
      };

  /// Stub the dashboard API to return a valid response.
  void stubDashboardSuccess({
    Map<String, dynamic>? dashboardData,
    Map<String, dynamic>? timeSeriesData,
  }) {
    final data = dashboardData ??
        {
          'total_revenue': _kpi(600000, delta: 50000, pct: 9.1),
          'tickets_sold': _kpi(120, delta: 10, pct: 9.1),
          'total_backers': _kpi(45, delta: 5, pct: 12.5),
          'total_events': _kpi(5, delta: 1, pct: 25.0),
          'refund_rate': _kpi(2.5, delta: -0.5, pct: -16.7),
          'total_sponsors': _kpi(3, delta: 1, pct: 50.0),
          'status_breakdown': [
            {'status': 'approved', 'count': 2},
            {'status': 'selling_tickets', 'count': 1},
            {'status': 'completed', 'count': 2},
          ],
          'trending_events': [
            eventJson(id: 1, title: 'Music Fest', status: 'approved'),
            eventJson(id: 2, title: 'Tech Talk', status: 'selling_tickets'),
          ],
          'top_events': [
            eventJson(id: 1, title: 'Music Fest', totalPledgedCents: 100000),
          ],
        };
    when(() => mockApi.getOrganizerDashboard(
          status: any(named: 'status'),
          eventId: any(named: 'eventId'),
          genre: any(named: 'genre'),
          period: any(named: 'period'),
        )).thenAnswer((_) async => data);
    when(() => mockApi.getOrganizerTimeSeries(
          days: any(named: 'days'),
          status: any(named: 'status'),
          eventId: any(named: 'eventId'),
          genre: any(named: 'genre'),
        )).thenAnswer((_) async => timeSeriesData ?? {'points': []});
  }

  /// Wrap the tab in a Scaffold so Material ancestor is available for chips.
  Future<void> pumpDashboard(WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: OrganizerDashboardTab(
          bookmarkedIds: bookmarkedIds,
          onToggleBookmark: (_) {},
        ),
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('OrganizerDashboardTab', () {
    testWidgets('renders key dashboard sections after load', (tester) async {
      stubDashboardSuccess();
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      // CustomScrollView is the root widget of the dashboard
      expect(find.byType(CustomScrollView), findsOneWidget);
      // RefreshIndicator wraps the scrollable content
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('event carousel renders with events', (tester) async {
      stubDashboardSuccess();
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      // The dashboard data includes trending_events with titles
      expect(find.text('Music Fest'), findsWidgets);
    });

    testWidgets('loading state renders scrollview while loading',
        (tester) async {
      // Use completers to keep the futures pending without creating timers
      final dashCompleter = Completer<Map<String, dynamic>>();

      when(() => mockApi.getOrganizerDashboard(
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            genre: any(named: 'genre'),
            period: any(named: 'period'),
          )).thenAnswer((_) => dashCompleter.future);

      await pumpDashboard(tester);
      // Only pump to trigger the post-frame callback, don't settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // When dashboardData is null and loading, the CustomScrollView is still present
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Complete with valid data and also stub time series for clean teardown
      when(() => mockApi.getOrganizerTimeSeries(
            days: any(named: 'days'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            genre: any(named: 'genre'),
          )).thenAnswer((_) async => {'points': []});

      dashCompleter.complete({
        'total_revenue': {'value': 0, 'delta': 0, 'change_pct': 0.0},
        'tickets_sold': {'value': 0, 'delta': 0, 'change_pct': 0.0},
        'total_backers': {'value': 0, 'delta': 0, 'change_pct': 0.0},
        'total_events': {'value': 0, 'delta': 0, 'change_pct': 0.0},
        'status_breakdown': [],
        'trending_events': [],
        'top_events': [],
      });
      await tester.pumpAndSettle();
    });

    testWidgets('empty state when zero events in dashboard', (tester) async {
      stubDashboardSuccess(dashboardData: {
        'total_revenue': _kpi(0),
        'tickets_sold': _kpi(0),
        'total_backers': _kpi(0),
        'total_events': _kpi(0),
        'refund_rate': _kpi(0.0),
        'total_sponsors': _kpi(0),
        'status_breakdown': [],
        'trending_events': [],
        'top_events': [],
      });
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      // The dashboard should still render without crashing
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without errors when data is present', (tester) async {
      stubDashboardSuccess();
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
