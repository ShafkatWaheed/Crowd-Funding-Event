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

  group('TicketPricePreview', () {
    test('fromJson parses all fields', () {
      final preview = TicketPricePreview.fromJson({
        'tier_price_cents': 10000,
        'common_discount_cents': 500,
        'selective_discount_cents': 300,
        'pledge_discount_cents': 200,
        'event_discount_cents': 100,
        'total_discount_cents': 1100,
        'final_price_cents': 8900,
        'commission_cents': 445,
        'net_to_organizer_cents': 8455,
        'ticket_commission_percent': 5,
      });

      expect(preview.tierPriceCents, 10000);
      expect(preview.commonDiscountCents, 500);
      expect(preview.selectiveDiscountCents, 300);
      expect(preview.pledgeDiscountCents, 200);
      expect(preview.eventDiscountCents, 100);
      expect(preview.totalDiscountCents, 1100);
      expect(preview.finalPriceCents, 8900);
      expect(preview.commissionCents, 445);
      expect(preview.netToOrganizerCents, 8455);
      expect(preview.ticketCommissionPercent, 5);
    });

    test('finalPriceFormatted', () {
      final preview = TicketPricePreview.fromJson({
        'final_price_cents': 7550,
      });
      expect(preview.finalPriceFormatted, '\$75.50');
    });

    test('defaults when fields missing', () {
      final preview = TicketPricePreview.fromJson({});
      expect(preview.tierPriceCents, 0);
      expect(preview.finalPriceCents, 0);
      expect(preview.commissionCents, 0);
    });
  });

  group('TicketSalesStats', () {
    test('fromJson parses all fields', () {
      final stats = TicketSalesStats.fromJson({
        'total_sold': 150,
        'total_scanned': 120,
      });
      expect(stats.totalSold, 150);
      expect(stats.totalScanned, 120);
    });

    test('defaults when fields missing', () {
      final stats = TicketSalesStats.fromJson({});
      expect(stats.totalSold, 0);
      expect(stats.totalScanned, 0);
    });
  });

  group('TicketScanResult', () {
    test('fromJson parses all fields', () {
      final result = TicketScanResult.fromJson({
        'already_scanned': true,
        'ticket': {
          'id': 1, 'event_id': 1, 'user_id': 1, 'ticket_tier_id': 1,
          'ticket_code': 'TKT-001', 'amount_paid_cents': 5000,
          'status': 'active', 'created_at': '2025-01-01T00:00:00',
        },
      });
      expect(result.alreadyScanned, true);
      expect(result.ticket.id, 1);
      expect(result.ticket.ticketCode, 'TKT-001');
    });

    test('alreadyScanned defaults to false', () {
      final result = TicketScanResult.fromJson({
        'ticket': {
          'id': 1, 'event_id': 1, 'user_id': 1, 'ticket_tier_id': 1,
          'ticket_code': 'TKT-001', 'amount_paid_cents': 5000,
          'status': 'active', 'created_at': '2025-01-01T00:00:00',
        },
      });
      expect(result.alreadyScanned, false);
    });
  });
}
