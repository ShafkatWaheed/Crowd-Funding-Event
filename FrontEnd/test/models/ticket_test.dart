import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/ticket.dart';
import '../helpers/fixtures.dart';

void main() {
  group('TicketTier', () {
    test('fromJson parses all fields', () {
      final json = ticketTierJson(
        id: 3,
        eventId: 7,
        name: 'VIP',
        priceCents: 15000,
        maxReservedSpots: 5,
        displayOrder: 2,
      );
      final tier = TicketTier.fromJson(json);

      expect(tier.id, 3);
      expect(tier.eventId, 7);
      expect(tier.name, 'VIP');
      expect(tier.priceCents, 15000);
      expect(tier.maxReservedSpots, 5);
      expect(tier.displayOrder, 2);
    });

    test('isFree when priceCents is 0', () {
      final free = TicketTier.fromJson(ticketTierJson(priceCents: 0));
      expect(free.isFree, true);
    });

    test('isFree false when priceCents > 0', () {
      final paid = TicketTier.fromJson(ticketTierJson(priceCents: 5000));
      expect(paid.isFree, false);
    });

    test('priceFormatted shows FREE for zero price', () {
      final free = TicketTier.fromJson(ticketTierJson(priceCents: 0));
      expect(free.priceFormatted, 'FREE');
    });

    test('priceFormatted shows dollar amount for non-zero', () {
      final paid = TicketTier.fromJson(ticketTierJson(priceCents: 5000));
      expect(paid.priceFormatted, '\$50.00');
    });

    test('nullable maxReservedSpots defaults to 0', () {
      final json = {'id': 1, 'event_id': 1, 'name': 'G', 'price_cents': 100};
      final tier = TicketTier.fromJson(json);
      expect(tier.maxReservedSpots, 0);
    });
  });

  group('TicketSale', () {
    test('fromJson parses all fields', () {
      final json = ticketSaleJson(
        id: 5,
        eventId: 3,
        userId: 10,
        ticketTierId: 2,
        ticketCode: 'TKT-ABC',
        receiptNumber: 'REC-XYZ',
        tierName: 'VIP',
        eventTitle: 'Big Show',
        amountPaidCents: 15000,
        discountAppliedCents: 500,
        status: 'active',
      );
      final sale = TicketSale.fromJson(json);

      expect(sale.id, 5);
      expect(sale.eventId, 3);
      expect(sale.userId, 10);
      expect(sale.ticketTierId, 2);
      expect(sale.ticketCode, 'TKT-ABC');
      expect(sale.receiptNumber, 'REC-XYZ');
      expect(sale.tierName, 'VIP');
      expect(sale.eventTitle, 'Big Show');
      expect(sale.amountPaidCents, 15000);
      expect(sale.discountAppliedCents, 500);
      expect(sale.status, 'active');
    });

    test('amountPaidFormatted', () {
      final sale = TicketSale.fromJson(ticketSaleJson(amountPaidCents: 7550));
      expect(sale.amountPaidFormatted, '\$75.50');
    });

    test('isScanned when scannedAt is present', () {
      final scanned = TicketSale.fromJson(
        ticketSaleJson(scannedAt: '2025-03-01T12:00:00'),
      );
      expect(scanned.isScanned, true);
    });

    test('isScanned false when scannedAt is null', () {
      final notScanned = TicketSale.fromJson(ticketSaleJson(scannedAt: null));
      expect(notScanned.isScanned, false);
    });

    test('createdAt parsed correctly', () {
      final sale = TicketSale.fromJson(
        ticketSaleJson(createdAt: '2025-02-15T14:30:00'),
      );
      expect(sale.createdAt, DateTime.parse('2025-02-15T14:30:00'));
    });

    test('nullable fields default correctly', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'user_id': 1,
        'ticket_tier_id': 1,
        'ticket_code': 'T1',
        'amount_paid_cents': 0,
        'status': 'active',
        'created_at': '2025-01-01T00:00:00',
      };
      final sale = TicketSale.fromJson(json);
      expect(sale.receiptNumber, isNull);
      expect(sale.tierName, isNull);
      expect(sale.eventTitle, isNull);
      expect(sale.discountAppliedCents, 0);
      expect(sale.commissionCents, 0);
    });
  });
}
