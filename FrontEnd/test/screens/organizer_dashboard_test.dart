import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/dashboard.dart';
import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/screens/home/tabs/organizer_dashboard_tab.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventRepository mockEventRepo;
  late Set<int> bookmarkedIds;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEventRepo = MockEventRepository();
    bookmarkedIds = <int>{};

    // Default: logged-in organizer
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  /// Build a KpiItem from raw values.
  KpiItem kpiItem(int value, {double? deltaPct}) =>
      KpiItem.fromJson({'value': value, 'delta_percent': deltaPct});

  /// Build a KpiFloatItem from raw values.
  KpiFloatItem kpiFloatItem(double value, {double? deltaPct}) =>
      KpiFloatItem.fromJson({'value': value, 'delta_percent': deltaPct});

  /// Stub the dashboard API to return a valid response.
  void stubDashboardSuccess({
    OrganizerDashboard? dashboardData,
    OrganizerTimeSeries? timeSeriesData,
  }) {
    final data = dashboardData ??
        OrganizerDashboard(
          totalRevenue: kpiItem(600000, deltaPct: 9.1),
          ticketsSold: kpiItem(120, deltaPct: 9.1),
          totalBackers: kpiItem(45, deltaPct: 12.5),
          totalEvents: kpiItem(5, deltaPct: 25.0),
          totalSponsors: kpiItem(3, deltaPct: 50.0),
          refundRate: kpiFloatItem(2.5, deltaPct: -16.7),
          statusBreakdown: [
            StatusBreakdown(status: 'approved', count: 2),
            StatusBreakdown(status: 'selling_tickets', count: 1),
            StatusBreakdown(status: 'completed', count: 2),
          ],
          trendingEvents: [
            Event.fromJson(eventJson(id: 1, title: 'Music Fest', status: 'approved')),
            Event.fromJson(eventJson(id: 2, title: 'Tech Talk', status: 'selling_tickets')),
          ],
          topEvents: [
            Event.fromJson(eventJson(id: 1, title: 'Music Fest', totalPledgedCents: 100000)),
          ],
        );
    when(() => mockEventRepo.getOrganizerDashboard(
          status: any(named: 'status'),
          eventId: any(named: 'eventId'),
          genre: any(named: 'genre'),
          period: any(named: 'period'),
        )).thenAnswer((_) async => data);
    when(() => mockEventRepo.getOrganizerTimeSeries(
          days: any(named: 'days'),
          status: any(named: 'status'),
          eventId: any(named: 'eventId'),
          genre: any(named: 'genre'),
        )).thenAnswer((_) async => timeSeriesData ?? OrganizerTimeSeries(points: [], granularity: 'daily'));
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
        ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo)),
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
      final dashCompleter = Completer<OrganizerDashboard>();

      when(() => mockEventRepo.getOrganizerDashboard(
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
      when(() => mockEventRepo.getOrganizerTimeSeries(
            days: any(named: 'days'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            genre: any(named: 'genre'),
          )).thenAnswer((_) async => OrganizerTimeSeries(points: [], granularity: 'daily'));

      dashCompleter.complete(OrganizerDashboard(
        totalRevenue: kpiItem(0),
        ticketsSold: kpiItem(0),
        totalBackers: kpiItem(0),
        totalEvents: kpiItem(0),
        totalSponsors: kpiItem(0),
        refundRate: kpiFloatItem(0.0),
        statusBreakdown: [],
        trendingEvents: [],
        topEvents: [],
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('empty state when zero events in dashboard', (tester) async {
      stubDashboardSuccess(dashboardData: OrganizerDashboard(
        totalRevenue: kpiItem(0),
        ticketsSold: kpiItem(0),
        totalBackers: kpiItem(0),
        totalEvents: kpiItem(0),
        totalSponsors: kpiItem(0),
        refundRate: kpiFloatItem(0.0),
        statusBreakdown: [],
        trendingEvents: [],
        topEvents: [],
      ));
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
