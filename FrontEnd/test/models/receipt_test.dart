import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/receipt.dart';

void main() {
  group('TicketReceipt', () {
    test('fromJson parses all fields', () {
      final json = {
        'sale_id': 42,
        'user_id': 7,
        'receipt_number': 'REC-TK-001',
        'ticket_code': 'TKT-XYZ',
        'status': 'active',
        'attendee_name': 'Jane Doe',
        'event_id': 3,
        'event_title': 'Big Concert',
        'event_start_time': '2025-06-15T18:00:00',
        'event_end_time': '2025-06-15T22:00:00',
        'organizer_name': 'Org Co',
        'organizer_email': 'org@example.com',
        'organizer_phone': '+1234567890',
        'venue_name': 'Main Hall',
        'venue_address': '123 Main St',
        'tier_name': 'VIP',
        'tier_price_cents': 15000,
        'amount_paid_cents': 14000,
        'discount_applied_cents': 1000,
        'commission_cents': 700,
        'net_to_organizer_cents': 13300,
        'subtotal_cents': 14000,
        'tax_cents': 1400,
        'tax_rate': 0.1,
        'tax_jurisdiction': 'CA',
        'extra_perks': 'Backstage pass',
        'encrypted_qr_payload': 'abc123',
        'purchased_at': '2025-05-01T10:00:00',
        'scanned_at': '2025-06-15T18:30:00',
      };
      final r = TicketReceipt.fromJson(json);

      expect(r.saleId, 42);
      expect(r.userId, 7);
      expect(r.receiptNumber, 'REC-TK-001');
      expect(r.ticketCode, 'TKT-XYZ');
      expect(r.status, 'active');
      expect(r.attendeeName, 'Jane Doe');
      expect(r.eventId, 3);
      expect(r.eventTitle, 'Big Concert');
      expect(r.eventStartTime, DateTime.parse('2025-06-15T18:00:00'));
      expect(r.eventEndTime, DateTime.parse('2025-06-15T22:00:00'));
      expect(r.organizerName, 'Org Co');
      expect(r.venueName, 'Main Hall');
      expect(r.tierName, 'VIP');
      expect(r.tierPriceCents, 15000);
      expect(r.amountPaidCents, 14000);
      expect(r.discountAppliedCents, 1000);
      expect(r.commissionCents, 700);
      expect(r.subtotalCents, 14000);
      expect(r.taxCents, 1400);
      expect(r.taxRate, 0.1);
      expect(r.extraPerks, 'Backstage pass');
      expect(r.purchasedAt, DateTime.parse('2025-05-01T10:00:00'));
      expect(r.scannedAt, DateTime.parse('2025-06-15T18:30:00'));
    });

    test('amountFormatted', () {
      final r = TicketReceipt.fromJson({
        'sale_id': 1, 'user_id': 1, 'event_id': 1,
        'amount_paid_cents': 7550, 'discount_applied_cents': 0,
        'tier_name': 'G', 'tier_price_cents': 7550,
        'purchased_at': '2025-01-01T00:00:00',
      });
      expect(r.amountFormatted, '\$75.50');
    });

    test('nullable fields default correctly', () {
      final r = TicketReceipt.fromJson({
        'sale_id': 1, 'user_id': 1, 'event_id': 1,
        'amount_paid_cents': 0, 'discount_applied_cents': 0,
        'tier_name': 'G', 'tier_price_cents': 0,
        'purchased_at': '2025-01-01T00:00:00',
      });
      expect(r.attendeeName, isNull);
      expect(r.eventStartTime, isNull);
      expect(r.scannedAt, isNull);
      expect(r.extraPerks, isNull);
      expect(r.commissionCents, 0);
      expect(r.taxCents, 0);
    });
  });

  group('TicketSummaryItem', () {
    test('fromJson parses all fields', () {
      final item = TicketSummaryItem.fromJson({
        'sale_id': 5,
        'ticket_code': 'TKT-999',
        'receipt_number': 'REC-999',
        'encrypted_qr_payload': 'payload',
        'status': 'active',
        'scanned_at': '2025-03-01T12:00:00',
      });
      expect(item.saleId, 5);
      expect(item.ticketCode, 'TKT-999');
      expect(item.receiptNumber, 'REC-999');
      expect(item.status, 'active');
      expect(item.scannedAt, DateTime.parse('2025-03-01T12:00:00'));
    });
  });

  group('PurchaseGroupReceipt', () {
    test('fromJson parses all fields including tickets', () {
      final json = {
        'purchase_group_id': 'PG-001',
        'event_id': 3,
        'event_title': 'Big Show',
        'tier_name': 'VIP',
        'tier_price_cents': 15000,
        'quantity': 2,
        'total_amount_paid_cents': 28000,
        'total_discount_applied_cents': 2000,
        'total_commission_cents': 1400,
        'total_net_to_organizer_cents': 26600,
        'tickets': [
          {'sale_id': 1, 'ticket_code': 'TKT-1', 'status': 'active'},
          {'sale_id': 2, 'ticket_code': 'TKT-2', 'status': 'active'},
        ],
        'purchased_at': '2025-05-01T10:00:00',
      };
      final r = PurchaseGroupReceipt.fromJson(json);

      expect(r.purchaseGroupId, 'PG-001');
      expect(r.eventId, 3);
      expect(r.eventTitle, 'Big Show');
      expect(r.quantity, 2);
      expect(r.totalAmountPaidCents, 28000);
      expect(r.tickets.length, 2);
      expect(r.tickets[0].ticketCode, 'TKT-1');
    });

    test('totalAmountFormatted', () {
      final r = PurchaseGroupReceipt.fromJson({
        'purchase_group_id': 'PG-1',
        'event_id': 1,
        'tier_name': 'G',
        'tier_price_cents': 5000,
        'quantity': 1,
        'total_amount_paid_cents': 12345,
        'total_discount_applied_cents': 0,
        'tickets': [],
        'purchased_at': '2025-01-01T00:00:00',
      });
      expect(r.totalAmountFormatted, '\$123.45');
    });
  });

  group('PledgeReceipt', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 10,
        'receipt_number': 'REC-PL-001',
        'event_id': 5,
        'event_title': 'Fundraiser',
        'user_id': 3,
        'backer_name': 'John',
        'amount_cents': 5000,
        'reserved_spots': 2,
        'tier_reservations': [
          {'tier_id': 1, 'tier_name': 'VIP', 'spots': 2},
        ],
        'platform_cut_cents': 250,
        'net_to_organizer_cents': 4750,
        'funding_commission_percent': 5,
        'subtotal_cents': 5000,
        'tax_cents': 500,
        'tax_rate': 0.1,
        'status': 'pledged',
        'is_guest': false,
        'created_at': '2025-04-01T10:00:00',
      };
      final r = PledgeReceipt.fromJson(json);

      expect(r.id, 10);
      expect(r.receiptNumber, 'REC-PL-001');
      expect(r.eventTitle, 'Fundraiser');
      expect(r.amountCents, 5000);
      expect(r.reservedSpots, 2);
      expect(r.tierReservations.length, 1);
      expect(r.tierReservations[0].tierName, 'VIP');
      expect(r.platformCutCents, 250);
      expect(r.status, 'pledged');
      expect(r.isGuest, false);
    });

    test('amountFormatted', () {
      final r = PledgeReceipt.fromJson({
        'id': 1, 'event_id': 1, 'event_title': 'E', 'user_id': 1,
        'amount_cents': 9999, 'status': 'pledged',
        'created_at': '2025-01-01T00:00:00',
      });
      expect(r.amountFormatted, '\$99.99');
    });
  });

  group('TierReservation', () {
    test('fromJson', () {
      final tr = TierReservation.fromJson({
        'tier_id': 3, 'tier_name': 'Gold', 'spots': 5,
      });
      expect(tr.tierId, 3);
      expect(tr.tierName, 'Gold');
      expect(tr.spots, 5);
    });
  });
}
