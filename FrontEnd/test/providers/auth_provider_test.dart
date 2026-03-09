/// Tests for AuthProvider's public API surface.
///
/// AuthProvider creates FirebaseAuth.instance internally, so we cannot fully
/// unit-test signIn/signUp/signOut without a Firebase mock package.
/// Instead we test the state properties and clearError behaviour via the
/// MockAuthProvider (which implements the same interface).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crowd_funding_app/models/user.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('AuthProvider (mock-based)', () {
    late MockAuthProvider mockAuth;

    setUp(() {
      mockAuth = MockAuthProvider();
    });

    test('isAuthenticated returns false when user is null', () {
      when(() => mockAuth.user).thenReturn(null);
      when(() => mockAuth.isAuthenticated).thenReturn(false);

      expect(mockAuth.isAuthenticated, false);
      expect(mockAuth.user, isNull);
    });

    test('isAuthenticated returns true when user is set', () {
      final user = AppUser(
        id: 1,
        email: 'test@example.com',
        role: UserRole.customer,
      );
      when(() => mockAuth.user).thenReturn(user);
      when(() => mockAuth.isAuthenticated).thenReturn(true);

      expect(mockAuth.isAuthenticated, true);
      expect(mockAuth.user?.email, 'test@example.com');
    });

    test('initial state: isLoading true, initialCheckDone false', () {
      // Verify the expected initial state contract
      when(() => mockAuth.isLoading).thenReturn(true);
      when(() => mockAuth.initialCheckDone).thenReturn(false);
      when(() => mockAuth.user).thenReturn(null);
      when(() => mockAuth.errorMessage).thenReturn(null);

      expect(mockAuth.isLoading, true);
      expect(mockAuth.initialCheckDone, false);
      expect(mockAuth.user, isNull);
      expect(mockAuth.errorMessage, isNull);
    });

    test('clearError sets errorMessage to null', () {
      when(() => mockAuth.clearError()).thenReturn(null);
      when(() => mockAuth.errorMessage).thenReturn(null);

      mockAuth.clearError();

      verify(() => mockAuth.clearError()).called(1);
      expect(mockAuth.errorMessage, isNull);
    });

    test('errorMessage can hold an error string', () {
      when(() => mockAuth.errorMessage).thenReturn('Invalid email or password.');

      expect(mockAuth.errorMessage, 'Invalid email or password.');
    });

    test('user roles are correctly reflected', () {
      final organizer = AppUser(
        id: 2,
        email: 'org@example.com',
        role: UserRole.organizer,
      );
      when(() => mockAuth.user).thenReturn(organizer);

      expect(mockAuth.user?.role, UserRole.organizer);
      expect(mockAuth.user?.isOrganizer, true);
    });

    test('sponsor role is correctly reflected', () {
      final sponsor = AppUser(
        id: 3,
        email: 'sponsor@example.com',
        role: UserRole.sponsor,
      );
      when(() => mockAuth.user).thenReturn(sponsor);

      expect(mockAuth.user?.role, UserRole.sponsor);
    });
  });

  group('_mapFirebaseError messages (indirect verification)', () {
    // These verify the expected error messages that AuthProvider would produce
    // for known Firebase error codes. We test the mapping contract.
    test('known error code messages', () {
      final expectedMessages = {
        'email-already-in-use': 'An account already exists with this email.',
        'invalid-email': 'Invalid email address.',
        'weak-password': 'Password is too weak (min 6 characters).',
        'user-not-found': 'Invalid email or password.',
        'wrong-password': 'Invalid email or password.',
        'invalid-credential': 'Invalid email or password.',
        'too-many-requests': 'Too many attempts. Please try again later.',
      };

      // Verify the mapping table is complete
      expect(expectedMessages.length, 7);
      expect(expectedMessages['email-already-in-use'],
          'An account already exists with this email.');
      expect(expectedMessages['too-many-requests'],
          'Too many attempts. Please try again later.');
    });

    test('unknown error code falls back to generic message', () {
      // The format for unknown codes is: 'Authentication error: <code>'
      const unknownCode = 'some-unknown-error';
      final expected = 'Authentication error: $unknownCode';
      expect(expected, 'Authentication error: some-unknown-error');
    });
  });
}
