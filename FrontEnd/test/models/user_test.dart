import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/user.dart';
import '../helpers/fixtures.dart';

void main() {
  group('AppUser', () {
    test('fromJson parses all fields', () {
      final json = userJson(
        id: 42,
        email: 'alice@example.com',
        displayName: 'Alice',
        role: 'organizer',
        phone: '+1234567890',
        birthday: '1990-05-15',
        kycStatus: 'verified',
        kycVerified: true,
      );
      final user = AppUser.fromJson(json);

      expect(user.id, 42);
      expect(user.email, 'alice@example.com');
      expect(user.displayName, 'Alice');
      expect(user.role, UserRole.organizer);
      expect(user.phone, '+1234567890');
      expect(user.birthday, '1990-05-15');
      expect(user.kycStatus, 'verified');
      expect(user.kycVerified, true);
    });

    test('role enum parsing with unknown role falls back to customer', () {
      final json = userJson(role: 'unknown_role');
      final user = AppUser.fromJson(json);
      expect(user.role, UserRole.customer);
    });

    test('isAdmin/isOrganizer/isCustomer/isSponsor getters', () {
      expect(AppUser.fromJson(userJson(role: 'admin')).isAdmin, true);
      expect(AppUser.fromJson(userJson(role: 'admin')).isOrganizer, false);

      expect(AppUser.fromJson(userJson(role: 'organizer')).isOrganizer, true);
      expect(AppUser.fromJson(userJson(role: 'organizer')).isAdmin, false);

      expect(AppUser.fromJson(userJson(role: 'customer')).isCustomer, true);
      expect(AppUser.fromJson(userJson(role: 'sponsor')).isSponsor, true);
    });

    test('displayLabel returns displayName when present', () {
      final user = AppUser.fromJson(userJson(displayName: 'Bob'));
      expect(user.displayLabel, 'Bob');
    });

    test('displayLabel falls back to User when displayName is null', () {
      final user = AppUser.fromJson(userJson(displayName: null));
      expect(user.displayLabel, 'User');
    });

    test('initial returns first character uppercase', () {
      final user = AppUser.fromJson(userJson(displayName: 'alice'));
      expect(user.initial, 'A');
    });

    test('maskedEmail masks correctly', () {
      final user = AppUser.fromJson(userJson(email: 'alice@example.com'));
      expect(user.maskedEmail, 'al***@example.com');
    });

    test('maskedEmail handles short local part', () {
      final user = AppUser.fromJson(userJson(email: 'a@example.com'));
      expect(user.maskedEmail, 'a***@example.com');
    });

    test('maskedEmail handles empty email', () {
      final user = AppUser.fromJson(userJson(email: ''));
      expect(user.maskedEmail, '?');
    });

    test('nullable birthday handled correctly', () {
      final user = AppUser.fromJson(userJson(birthday: null));
      expect(user.birthday, isNull);
    });

    test('kycStatus defaults', () {
      final json = {'id': 1, 'email': 'test@test.com', 'role': 'customer'};
      final user = AppUser.fromJson(json);
      expect(user.kycStatus, 'not_started');
      expect(user.kycVerified, false);
    });
  });
}
