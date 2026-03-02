import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/manage/organizer_pledges_screen.dart';
import '../../lib/screens/manage/global_ticket_sales_screen.dart';
import '../../lib/screens/manage/global_refund_requests_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  group('OrganizerPledgesScreen', () {
    Future<void> pumpPledges(WidgetTester tester) async {
      await pumpApp(
        tester,
        const OrganizerPledgesScreen(),
        overrides: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          Provider<ApiService>.value(value: mockApi),
        ],
      );
    }

    testWidgets('shows title and status filter chips', (tester) async {
      when(() => mockApi.getOrganizerPledges(
            status: any(named: 'status'),
            eventStatus: any(named: 'eventStatus'),
            genre: any(named: 'genre'),
            eventId: any(named: 'eventId'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await pumpPledges(tester);
      await tester.pumpAndSettle();

      expect(find.text('Pledges & Backers'), findsOneWidget);
      // Status chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pledged'), findsOneWidget);
    });

    testWidgets('shows empty state when no pledges', (tester) async {
      when(() => mockApi.getOrganizerPledges(
            status: any(named: 'status'),
            eventStatus: any(named: 'eventStatus'),
            genre: any(named: 'genre'),
            eventId: any(named: 'eventId'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await pumpPledges(tester);
      await tester.pumpAndSettle();

      expect(find.text('No pledges yet'), findsOneWidget);
    });
  });

  group('GlobalTicketSalesScreen', () {
    Future<void> pumpTicketSales(WidgetTester tester, {bool scannedOnly = false}) async {
      await pumpApp(
        tester,
        GlobalTicketSalesScreen(scannedOnly: scannedOnly),
        overrides: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          Provider<ApiService>.value(value: mockApi),
        ],
      );
    }

    testWidgets('shows All Ticket Sales title by default', (tester) async {
      when(() => mockApi.getOrganizerTicketSales(
            scannedOnly: any(named: 'scannedOnly'),
            eventStatus: any(named: 'eventStatus'),
            genre: any(named: 'genre'),
            eventId: any(named: 'eventId'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await pumpTicketSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('All Ticket Sales'), findsOneWidget);
    });

    testWidgets('shows scanned-only title when scannedOnly is true', (tester) async {
      when(() => mockApi.getOrganizerTicketSales(
            scannedOnly: any(named: 'scannedOnly'),
            eventStatus: any(named: 'eventStatus'),
            genre: any(named: 'genre'),
            eventId: any(named: 'eventId'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await pumpTicketSales(tester, scannedOnly: true);
      await tester.pumpAndSettle();

      expect(find.text('All Scanned Tickets'), findsOneWidget);
    });
  });

  group('GlobalRefundRequestsScreen', () {
    Future<void> pumpRefundRequests(WidgetTester tester) async {
      await pumpApp(
        tester,
        const GlobalRefundRequestsScreen(),
        overrides: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          Provider<ApiService>.value(value: mockApi),
        ],
      );
    }

    testWidgets('shows Refund Requests title', (tester) async {
      when(() => mockApi.getOrganizerRefundRequests())
          .thenAnswer((_) async => []);

      await pumpRefundRequests(tester);
      await tester.pumpAndSettle();

      expect(find.text('Refund Requests'), findsOneWidget);
    });
  });
}
