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
import '../../lib/screens/sponsor/sponsor_onboarding_screen.dart';
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

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
    when(() => mockAuth.refreshUser()).thenAnswer((_) async {});
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorOnboardingScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo)),
      ],
    );
  }

  group('SponsorOnboardingScreen', () {
    testWidgets('shows loading spinner during initial load', (tester) async {
      final profileCompleter = Completer<SponsorProfile>();
      when(() => mockSponsorRepo.getSponsorProfile())
          .thenAnswer((_) => profileCompleter.future);

      await pumpOnboarding(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete with error (no existing profile) to avoid pending timer issues
      profileCompleter.completeError(Exception('Not found'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows create mode when no existing profile', (tester) async {
      when(() => mockSponsorRepo.getSponsorProfile())
          .thenThrow(Exception('Not found'));

      await pumpOnboarding(tester);
      await tester.pumpAndSettle();

      expect(find.text('Become a Sponsor'), findsOneWidget);
      expect(find.text('Create Sponsor Profile'), findsOneWidget);
      expect(find.text('Company Name *'), findsOneWidget);
      expect(find.text('Contact Name *'), findsOneWidget);
    });

    testWidgets('shows form fields with correct labels', (tester) async {
      when(() => mockSponsorRepo.getSponsorProfile())
          .thenThrow(Exception('Not found'));

      await pumpOnboarding(tester);
      await tester.pumpAndSettle();

      expect(find.text('Company Name *'), findsOneWidget);
      expect(find.text('Contact Name *'), findsOneWidget);
      expect(find.text('Profession / Industry *'), findsOneWidget);
      expect(find.text('Logo URL'), findsOneWidget);
      expect(find.text('Company Description'), findsOneWidget);
      expect(find.text('Website URL'), findsOneWidget);
    });
  });
}
