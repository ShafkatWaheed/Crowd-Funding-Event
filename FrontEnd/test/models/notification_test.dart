import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/notification_model.dart';

void main() {
  group('NotificationPayload', () {
    test('fromMap parses int values', () {
      final p = NotificationPayload.fromMap({
        'type': 'ticket_purchased',
        'event_id': 5,
        'bid_id': 10,
        'category_id': 3,
        'ticket_sale_id': 42,
        'pledge_id': 7,
      });
      expect(p.type, 'ticket_purchased');
      expect(p.eventId, 5);
      expect(p.bidId, 10);
      expect(p.categoryId, 3);
      expect(p.ticketSaleId, 42);
      expect(p.pledgeId, 7);
    });

    test('fromMap parses string values (FCM format)', () {
      final p = NotificationPayload.fromMap({
        'type': 'bid_received',
        'event_id': '12',
        'bid_id': '99',
      });
      expect(p.type, 'bid_received');
      expect(p.eventId, 12);
      expect(p.bidId, 99);
    });

    test('fromMap handles missing fields', () {
      final p = NotificationPayload.fromMap({});
      expect(p.type, '');
      expect(p.eventId, isNull);
      expect(p.bidId, isNull);
      expect(p.categoryId, isNull);
      expect(p.ticketSaleId, isNull);
      expect(p.pledgeId, isNull);
    });

    test('const default constructor', () {
      const p = NotificationPayload();
      expect(p.type, '');
      expect(p.eventId, isNull);
    });
  });

  group('AppNotification', () {
    test('fromJson wraps data in NotificationPayload', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'type': 'ticket_purchased',
        'title': 'Ticket Bought',
        'message': 'You bought a ticket',
        'data': {'event_id': 5, 'ticket_sale_id': 10},
        'is_read': false,
        'created_at': '2025-06-01T12:00:00',
      });
      expect(n.data, isA<NotificationPayload>());
      expect(n.data.eventId, 5);
      expect(n.data.ticketSaleId, 10);
    });

    test('fromJson with null data', () {
      final n = AppNotification.fromJson({
        'id': 2,
        'type': 'test',
        'title': 'Test',
        'message': 'msg',
        'is_read': true,
        'created_at': '2025-06-01T12:00:00',
      });
      expect(n.data.type, 'test');  // parent type injected into payload
      expect(n.data.eventId, isNull);
    });
  });
}
