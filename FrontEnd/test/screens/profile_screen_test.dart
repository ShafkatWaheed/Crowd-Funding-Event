import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/profile/profile_screen.dart';
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

    // Stub KYC status (called by KycSection in initState) — use a completer
    // that resolves instantly to avoid pending timers.
    when(() => mockApi.getKycStatus()).thenAnswer((_) async => {
          'status': 'not_started',
          'documents': <dynamic>[],
        });
  });

  /// Pump ProfileScreen with the given user role.
  Future<void> pumpProfile(
    WidgetTester tester, {
    UserRole role = UserRole.customer,
    String email = 'alice@example.com',
    String displayName = 'Alice',
  }) async {
    final user = makeUser(
      role: role,
      email: email,
      displayName: displayName,
    );
    when(() => mockAuth.user).thenReturn(user);

    // For sponsor users, stub getSponsorProfile (called in initState)
    if (role == UserRole.sponsor) {
      when(() => mockApi.getSponsorProfile()).thenAnswer((_) async => {
            'company_name': 'Acme Corp',
            'contact_name': 'Alice',
            'profession': 'Marketing',
            'logo_url': null,
            'description': null,
            'website_url': null,
          });
    }

    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );
    // Let all animations and async operations complete
    await tester.pumpAndSettle();
  }

  group('ProfileScreen', () {
    testWidgets('renders profile fields (email and display name)',
        (tester) async {
      await pumpProfile(tester,
          email: 'alice@example.com', displayName: 'Alice');

      // The ProfileHeaderCard renders the display name
      expect(find.text('Alice'), findsWidgets);
      // Email is shown in the header card and the personal info read-only field
      expect(find.text('alice@example.com'), findsWidgets);
      // The appbar title
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('save button exists', (tester) async {
      await pumpProfile(tester);

      // The save button shows 'Save Changes' text
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('KYC section visible for non-admin users', (tester) async {
      await pumpProfile(tester, role: UserRole.customer);

      // Identity Verification is the title of the KYC section card
      expect(find.text('Identity Verification'), findsOneWidget);
    });

    testWidgets('edit fields exist for personal information', (tester) async {
      await pumpProfile(tester,
          role: UserRole.customer, displayName: 'Bob');

      // PersonalInfoSection contains TextFormField inputs
      expect(find.text('Personal Information'), findsOneWidget);
      // The name controller should be pre-filled
      expect(find.text('Bob'), findsWidgets);
      // Email field is rendered as read-only
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('sponsor section not visible for customer role',
        (tester) async {
      await pumpProfile(tester, role: UserRole.customer);

      // ProfileSponsorSection renders 'Company Details' title
      // For a customer, the sponsor section should NOT be present
      expect(find.text('Company Details'), findsNothing);
    });

    testWidgets('renders user initial in avatar', (tester) async {
      await pumpProfile(tester, displayName: 'Charlie');

      // ProfileHeaderCard uses user.initial which is the first character
      // of the display name uppercased
      expect(find.text('C'), findsWidgets);
      // Verify CircleAvatar is rendered in the header
      expect(find.byType(CircleAvatar), findsWidgets);
    });
  });
}
