import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/bid_management_screen.dart';
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

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  Future<void> pumpBidManagement(WidgetTester tester, {
    String? categoryName,
  }) async {
    await pumpApp(
      tester,
      BidManagementScreen(
        eventId: 1,
        categoryId: 1,
        categoryName: categoryName,
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<SponsorRepository>.value(value: mockSponsorRepo),
      ],
    );
  }

  group('BidManagementScreen', () {
    testWidgets('shows category name in AppBar', (tester) async {
      final bidsCompleter = Completer<List<dynamic>>();
      when(() => mockSponsorRepo.listBids(1, 1))
          .thenAnswer((_) => bidsCompleter.future);

      await pumpBidManagement(tester, categoryName: 'Gold Sponsor');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bids: Gold Sponsor'), findsOneWidget);

      bidsCompleter.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows generic title when no category name', (tester) async {
      final bidsCompleter = Completer<List<dynamic>>();
      when(() => mockSponsorRepo.listBids(1, 1))
          .thenAnswer((_) => bidsCompleter.future);

      await pumpBidManagement(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bid Management'), findsOneWidget);

      bidsCompleter.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no bids', (tester) async {
      when(() => mockSponsorRepo.listBids(1, 1))
          .thenAnswer((_) async => []);

      await pumpBidManagement(tester);
      await tester.pumpAndSettle();

      expect(find.text('No bids yet.'), findsOneWidget);
    });
  });
}
