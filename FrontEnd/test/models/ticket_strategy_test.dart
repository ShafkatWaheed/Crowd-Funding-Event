import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/ticket_strategy.dart';
import '../helpers/fixtures.dart';

void main() {
  group('TicketStrategyTier', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 2,
        'name': 'VIP',
        'description': 'Front row access',
        'price_cents': 15000,
        'display_order': 1,
      };
      final tier = TicketStrategyTier.fromJson(json);

      expect(tier.id, 2);
      expect(tier.name, 'VIP');
      expect(tier.description, 'Front row access');
      expect(tier.priceCents, 15000);
      expect(tier.displayOrder, 1);
    });

    test('isFree and priceFormatted', () {
      final free = TicketStrategyTier.fromJson({
        'id': 1, 'name': 'Free', 'price_cents': 0,
      });
      expect(free.isFree, true);
      expect(free.priceFormatted, 'FREE');

      final paid = TicketStrategyTier.fromJson({
        'id': 2, 'name': 'Paid', 'price_cents': 7500,
      });
      expect(paid.isFree, false);
      expect(paid.priceFormatted, '\$75.00');
    });
  });

  group('TicketStrategy', () {
    test('fromJson parses all fields and sorts tiers', () {
      final json = ticketStrategyJson(
        id: 5,
        organizerId: 10,
        name: 'Festival Package',
        tiers: [
          {'id': 2, 'name': 'VIP', 'price_cents': 15000, 'display_order': 1},
          {'id': 1, 'name': 'General', 'price_cents': 5000, 'display_order': 0},
        ],
      );
      final strategy = TicketStrategy.fromJson(json);

      expect(strategy.id, 5);
      expect(strategy.organizerId, 10);
      expect(strategy.name, 'Festival Package');
      expect(strategy.tiers.length, 2);
      // Sorted by display_order
      expect(strategy.tiers[0].name, 'General');
      expect(strategy.tiers[1].name, 'VIP');
    });

    test('tiersSummary with tiers', () {
      final strategy = TicketStrategy.fromJson(ticketStrategyJson());
      expect(strategy.tiersSummary, contains('2 tiers'));
      expect(strategy.tiersSummary, contains('General'));
      expect(strategy.tiersSummary, contains('VIP'));
    });

    test('tiersSummary with no tiers', () {
      final json = ticketStrategyJson(tiers: []);
      final strategy = TicketStrategy.fromJson(json);
      expect(strategy.tiersSummary, 'No tiers');
    });

    test('tiersSummary singular tier', () {
      final json = ticketStrategyJson(tiers: [
        {'id': 1, 'name': 'Solo', 'price_cents': 1000, 'display_order': 0},
      ]);
      final strategy = TicketStrategy.fromJson(json);
      expect(strategy.tiersSummary, startsWith('1 tier'));
    });

    test('dates parsed correctly', () {
      final strategy = TicketStrategy.fromJson(ticketStrategyJson(
        createdAt: '2025-03-01T10:00:00',
        updatedAt: '2025-03-15T14:30:00',
      ));
      expect(strategy.createdAt, DateTime.parse('2025-03-01T10:00:00'));
      expect(strategy.updatedAt, DateTime.parse('2025-03-15T14:30:00'));
    });
  });
}
