import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/sponsor_dashboard_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockSponsorRepository mockSponsorRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockSponsorRepo = MockSponsorRepository();

    // Default: sponsor user
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.sponsor));
  });

  /// Build a proper SponsorTicketModel-compatible JSON.
  Map<String, dynamic> _sponsorTicketJson({
    int id = 1,
    int eventId = 1,
    int sponsorUserId = 5,
    String receiptNumber = 'SPT-001',
    int categoryCount = 2,
    String? scannedAt,
  }) =>
      {
        'id': id,
        'event_id': eventId,
        'sponsor_user_id': sponsorUserId,
        'receipt_number': receiptNumber,
        'encrypted_qr_payload': null,
        'scanned_at': scannedAt,
        'created_at': '2025-01-20T10:00:00',
        'categories': <dynamic>[],
        'category_names': <dynamic>[],
        'category_count': categoryCount,
        'event_title': null,
        'event_status': null,
        'event_start_time': null,
        'venue_name': null,
        'venue_address': null,
        'venue_city': null,
        'scan_count': 0,
      };

  /// Stub sponsor profile and tickets for a successful load.
  void stubSponsorSuccess({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? tickets,
  }) {
    when(() => mockSponsorRepo.getSponsorProfile()).thenAnswer((_) async =>
        profile ??
        {
          'id': 1,
          'user_id': 5,
          'company_name': 'Acme Corp',
          'contact_name': 'John Doe',
          'profession': 'Marketing',
          'logo_url': null,
          'description': 'A sponsor company',
          'website_url': null,
        });
    when(() => mockSponsorRepo.getMySponsorTickets()).thenAnswer((_) async =>
        tickets ?? [_sponsorTicketJson()]);
  }

  Future<void> pumpSponsorDashboard(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorDashboardScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<SponsorRepository>.value(value: mockSponsorRepo),
      ],
    );
  }

  group('SponsorDashboardScreen', () {
    testWidgets('renders sponsor dashboard sections after load',
        (tester) async {
      stubSponsorSuccess();
      await pumpSponsorDashboard(tester);
      await tester.pumpAndSettle();

      // AppBar
      expect(find.text('Sponsor Dashboard'), findsOneWidget);
      // Profile card shows company name
      expect(find.text('Acme Corp'), findsOneWidget);
      // Quick Actions section
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Edit Sponsor Profile'), findsOneWidget);
      expect(find.text('My Sponsor Tickets'), findsOneWidget);
    });

    testWidgets('ticket list section exists with correct count',
        (tester) async {
      stubSponsorSuccess();
      await pumpSponsorDashboard(tester);
      await tester.pumpAndSettle();

      // Ticket section header shows count
      expect(find.text('Sponsor Tickets (1)'), findsOneWidget);
      // Individual ticket card shows event reference
      expect(find.text('Event #1'), findsOneWidget);
      expect(find.textContaining('SPT-001'), findsOneWidget);
    });

    testWidgets('loading state shows app bar while content loads',
        (tester) async {
      // Use completers to control when the futures resolve.
      final profileCompleter = Completer<Map<String, dynamic>>();
      final ticketsCompleter = Completer<List<dynamic>>();

      when(() => mockSponsorRepo.getSponsorProfile())
          .thenAnswer((_) => profileCompleter.future);
      when(() => mockSponsorRepo.getMySponsorTickets())
          .thenAnswer((_) => ticketsCompleter.future);

      await pumpSponsorDashboard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AppBar should be visible during loading
      expect(find.text('Sponsor Dashboard'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      // Complete the futures to avoid pending timer issues
      profileCompleter.complete({
        'id': 1,
        'user_id': 5,
        'company_name': 'Acme Corp',
        'contact_name': 'John Doe',
        'profession': 'Marketing',
        'logo_url': null,
        'description': null,
        'website_url': null,
      });
      ticketsCompleter.complete([]);
      await tester.pumpAndSettle();
    });
  });
}
