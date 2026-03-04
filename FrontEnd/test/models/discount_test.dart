import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/discount.dart';

void main() {
  group('EventDiscount', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'event_id': 5,
        'name': 'Early Bird',
        'discount_type': 'ticket_percent',
        'value': 10,
        'target': 'all',
        'milestone_percent': 50,
        'milestone_discount_value': 5,
        'created_at': '2025-01-15T10:00:00',
      };
      final d = EventDiscount.fromJson(json);

      expect(d.id, 1);
      expect(d.eventId, 5);
      expect(d.name, 'Early Bird');
      expect(d.discountType, 'ticket_percent');
      expect(d.value, 10);
      expect(d.target, 'all');
      expect(d.milestonePercent, 50);
      expect(d.milestoneDiscountValue, 5);
      expect(d.createdAt, DateTime.parse('2025-01-15T10:00:00'));
    });

    test('nullable milestone fields', () {
      final json = {
        'id': 2,
        'event_id': 3,
        'name': 'Pledge Discount',
        'discount_type': 'pledge_percent',
        'value': 5,
        'target': 'pledgers',
        'created_at': '2025-01-15T10:00:00',
      };
      final d = EventDiscount.fromJson(json);

      expect(d.milestonePercent, isNull);
      expect(d.milestoneDiscountValue, isNull);
    });
  });

  group('UserDiscount', () {
    test('fromJson parses all fields', () {
      final json = {
        'discount_id': 10,
        'discount_type': 'ticket_percent',
        'value': 15,
        'target': 'all',
      };
      final d = UserDiscount.fromJson(json);

      expect(d.discountId, 10);
      expect(d.discountType, 'ticket_percent');
      expect(d.value, 15);
      expect(d.target, 'all');
    });
  });

  group('MyDiscounts', () {
    test('fromJson parses available_discounts list', () {
      final json = {
        'available_discounts': [
          {'discount_id': 1, 'discount_type': 'ticket_percent', 'value': 10, 'target': 'all'},
          {'discount_id': 2, 'discount_type': 'pledge_percent', 'value': 5, 'target': 'pledgers'},
        ],
      };
      final d = MyDiscounts.fromJson(json);

      expect(d.availableDiscounts.length, 2);
      expect(d.availableDiscounts[0].discountId, 1);
      expect(d.availableDiscounts[1].target, 'pledgers');
    });

    test('empty list when no discounts', () {
      final d = MyDiscounts.fromJson({});
      expect(d.availableDiscounts, isEmpty);
    });
  });

  group('DiscountStrategy', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'organizer_id': 10,
        'name': 'VIP Special',
        'discount_type': 'ticket_percent',
        'value': 20,
        'target': 'all',
        'created_at': '2025-01-10T10:00:00',
        'updated_at': '2025-01-11T12:00:00',
      };
      final d = DiscountStrategy.fromJson(json);

      expect(d.id, 1);
      expect(d.organizerId, 10);
      expect(d.name, 'VIP Special');
      expect(d.discountType, 'ticket_percent');
      expect(d.value, 20);
      expect(d.target, 'all');
      expect(d.createdAt, DateTime.parse('2025-01-10T10:00:00'));
      expect(d.updatedAt, DateTime.parse('2025-01-11T12:00:00'));
    });
  });

  group('EventDiscountStrategy', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 5,
        'name': 'Loyalty Reward',
        'discount_type': 'pledge_percent',
        'value': 10,
        'target': 'pledgers',
        'auto_apply': true,
      };
      final d = EventDiscountStrategy.fromJson(json);

      expect(d.id, 5);
      expect(d.name, 'Loyalty Reward');
      expect(d.discountType, 'pledge_percent');
      expect(d.value, 10);
      expect(d.target, 'pledgers');
      expect(d.autoApply, true);
    });

    test('autoApply defaults to false', () {
      final json = {
        'id': 6,
        'name': 'Test',
        'discount_type': 'ticket_percent',
        'value': 5,
        'target': 'all',
      };
      final d = EventDiscountStrategy.fromJson(json);
      expect(d.autoApply, false);
    });
  });

  group('ClaimableDiscount', () {
    test('fromJson parses all fields', () {
      final json = {
        'link_id': 42,
        'strategy_id': 5,
        'name': 'Early Bird',
        'discount_type': 'ticket_percent',
        'value': 15,
        'target': 'all',
        'claimed': true,
      };
      final d = ClaimableDiscount.fromJson(json);

      expect(d.linkId, 42);
      expect(d.strategyId, 5);
      expect(d.name, 'Early Bird');
      expect(d.discountType, 'ticket_percent');
      expect(d.value, 15);
      expect(d.target, 'all');
      expect(d.claimed, true);
    });

    test('claimed defaults to false', () {
      final json = {
        'link_id': 43,
        'strategy_id': 6,
        'name': 'Test',
        'discount_type': 'ticket_percent',
        'value': 10,
        'target': 'all',
      };
      final d = ClaimableDiscount.fromJson(json);
      expect(d.claimed, false);
    });
  });

  group('EarlyBirdDiscount', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 10,
        'event_id': 3,
        'discount_type': 'ticket_percent',
        'value': 15,
        'target': 'pledgers',
        'auto_apply': true,
        'is_active': true,
        'starts_at': '2025-06-01T00:00:00',
        'ends_at': '2025-06-30T23:59:59',
      };
      final d = EarlyBirdDiscount.fromJson(json);

      expect(d.id, 10);
      expect(d.eventId, 3);
      expect(d.discountType, 'ticket_percent');
      expect(d.value, 15);
      expect(d.target, 'pledgers');
      expect(d.autoApply, true);
      expect(d.isActive, true);
      expect(d.startsAt, '2025-06-01T00:00:00');
      expect(d.endsAt, '2025-06-30T23:59:59');
    });

    test('defaults for optional/nullable fields', () {
      final json = {
        'id': 11,
        'event_id': 4,
      };
      final d = EarlyBirdDiscount.fromJson(json);

      expect(d.discountType, '');
      expect(d.value, 0);
      expect(d.target, 'all');
      expect(d.autoApply, true);
      expect(d.isActive, false);
      expect(d.startsAt, isNull);
      expect(d.endsAt, isNull);
    });
  });
}
