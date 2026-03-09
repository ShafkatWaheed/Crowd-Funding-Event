import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/notification_model.dart';

void main() {
  group('AppNotification', () {
    test('fromJson parses all fields', () {
      final n = AppNotification.fromJson({
        'id': 42,
        'type': 'event_approved',
        'title': 'Event Approved',
        'message': 'Your event has been approved!',
        'data': {'event_id': 5},
        'is_read': false,
        'created_at': '2025-03-01T12:00:00',
      });

      expect(n.id, 42);
      expect(n.type, 'event_approved');
      expect(n.title, 'Event Approved');
      expect(n.message, 'Your event has been approved!');
      expect(n.data.eventId, 5);
      expect(n.isRead, false);
      expect(n.createdAt, DateTime.parse('2025-03-01T12:00:00'));
    });

    test('defaults when optional fields missing', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'created_at': '2025-01-01T00:00:00',
      });
      expect(n.type, '');
      expect(n.title, '');
      expect(n.message, '');
      expect(n.data, isA<NotificationPayload>());
      expect(n.data.type, '');
      expect(n.data.eventId, isNull);
      expect(n.isRead, false);
    });

    test('copyWith updates isRead', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'type': 'test',
        'title': 'Test',
        'message': 'msg',
        'is_read': false,
        'created_at': '2025-01-01T00:00:00',
      });
      final updated = n.copyWith(isRead: true);
      expect(updated.isRead, true);
      expect(updated.id, 1);
      expect(updated.title, 'Test');
    });
  });
}
