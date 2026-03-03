import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/sponsor.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/sponsor_provider.dart';
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

  /// Build a proper SponsorTicketModel instance.
  SponsorTicketModel makeSponsorTicket({
    int id = 1,
    int eventId = 1,
    int sponsorUserId = 5,
    String receiptNumber = 'SPT-001',
    int categoryCount = 2,
    String? scannedAt,
  }) =>
      SponsorTicketModel(
        id: id,
        eventId: eventId,
        sponsorUserId: sponsorUserId,
        receiptNumber: receiptNumber,
        scannedAt: scannedAt,
        createdAt: '2025-01-20T10:00:00',
        categories: [],
        categoryNames: [],
        categoryCount: categoryCount,
      );

  /// Build a default SponsorProfile instance.
  SponsorProfile defaultProfile() => SponsorProfile(
        id: 1,
        userId: 5,
        companyName: 'Acme Corp',
        contactName: 'John Doe',
        profession: 'Marketing',
        description: 'A sponsor company',
      );

  /// Stub sponsor profile and tickets for a successful load.
  void stubSponsorSuccess({
    SponsorProfile? profile,
    List<SponsorTicketModel>? tickets,
  }) {
    when(() => mockSponsorRepo.getSponsorProfile())
        .thenAnswer((_) async => profile ?? defaultProfile());
    when(() => mockSponsorRepo.getMySponsorTickets())
        .thenAnswer((_) async => tickets ?? [makeSponsorTicket()]);
  }

  Future<void> pumpSponsorDashboard(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorDashboardScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo)),
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
      final profileCompleter = Completer<SponsorProfile>();
      final ticketsCompleter = Completer<List<SponsorTicketModel>>();

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
      profileCompleter.complete(SponsorProfile(
        id: 1,
        userId: 5,
        companyName: 'Acme Corp',
        contactName: 'John Doe',
        profession: 'Marketing',
      ));
      ticketsCompleter.complete([]);
      await tester.pumpAndSettle();
    });
  });
}
