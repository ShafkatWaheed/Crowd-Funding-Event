import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/funding.dart';
import '../helpers/fixtures.dart';

void main() {
  group('Pledge', () {
    test('fromJson parses all fields', () {
      final json = pledgeJson(
        id: 10,
        eventId: 5,
        userId: 3,
        amountCents: 5000,
        status: 'pledged',
        isGuest: false,
        receiptNumber: 'REC-123',
        eventTitle: 'Cool Event',
      );
      final pledge = Pledge.fromJson(json);

      expect(pledge.id, 10);
      expect(pledge.eventId, 5);
      expect(pledge.userId, 3);
      expect(pledge.amountCents, 5000);
      expect(pledge.status, PledgeStatus.pledged);
      expect(pledge.isGuest, false);
      expect(pledge.receiptNumber, 'REC-123');
      expect(pledge.eventTitle, 'Cool Event');
    });

    test('PledgeStatus enum parsing', () {
      expect(Pledge.fromJson(pledgeJson(status: 'pledged')).status, PledgeStatus.pledged);
      expect(Pledge.fromJson(pledgeJson(status: 'collected')).status, PledgeStatus.collected);
      expect(Pledge.fromJson(pledgeJson(status: 'refunded')).status, PledgeStatus.refunded);
    });

    test('unknown status falls back to pledged', () {
      final pledge = Pledge.fromJson(pledgeJson(status: 'unknown'));
      expect(pledge.status, PledgeStatus.pledged);
    });

    test('amountFormatted formats correctly', () {
      final pledge = Pledge.fromJson(pledgeJson(amountCents: 12345));
      expect(pledge.amountFormatted, '\$123.45');
    });

    test('isGuest flag', () {
      final guest = Pledge.fromJson(pledgeJson(isGuest: true));
      expect(guest.isGuest, true);
    });

    test('createdAt parsed correctly', () {
      final pledge = Pledge.fromJson(pledgeJson(createdAt: '2025-06-15T18:30:00'));
      expect(pledge.createdAt, DateTime.parse('2025-06-15T18:30:00'));
    });
  });

  group('FundingSummary', () {
    test('fromJson parses all fields', () {
      final json = fundingSummaryJson(
        goalCents: 200000,
        totalPledgedCents: 150000,
        backersCount: 50,
        totalReservedSpots: 20,
        fundingEndAt: '2025-07-01T00:00:00',
      );
      final summary = FundingSummary.fromJson(json);

      expect(summary.goalCents, 200000);
      expect(summary.totalPledgedCents, 150000);
      expect(summary.backersCount, 50);
      expect(summary.totalReservedSpots, 20);
      expect(summary.fundingEndAt, DateTime.parse('2025-07-01T00:00:00'));
    });

    test('progress computed correctly', () {
      final summary = FundingSummary.fromJson(fundingSummaryJson(
        goalCents: 100000,
        totalPledgedCents: 75000,
      ));
      expect(summary.progress, 0.75);
    });

    test('progress zero when goal is zero', () {
      final summary = FundingSummary.fromJson(fundingSummaryJson(goalCents: 0));
      expect(summary.progress, 0);
    });

    test('goalFormatted', () {
      final summary = FundingSummary.fromJson(fundingSummaryJson(goalCents: 100000));
      expect(summary.goalFormatted, '\$1000.00');
    });

    test('totalPledgedFormatted', () {
      final summary = FundingSummary.fromJson(fundingSummaryJson(totalPledgedCents: 50000));
      expect(summary.totalPledgedFormatted, '\$500.00');
    });

    test('nullable fundingEndAt', () {
      final summary = FundingSummary.fromJson(fundingSummaryJson(fundingEndAt: null));
      expect(summary.fundingEndAt, isNull);
    });
  });

  group('PledgePreview', () {
    test('fromJson parses all fields', () {
      final preview = PledgePreview.fromJson({
        'amount_cents': 5000,
        'reserved_spots': 2,
        'cost_per_spot_cents': 2500,
        'platform_cut_cents': 250,
        'net_to_organizer_cents': 4750,
        'funding_commission_percent': 5,
        'available_spots_for_user': 3,
        'event_total_reserved_spots': 10,
        'link_funding_to_tiers': true,
        'tier_availability': [
          {'tier_id': 1, 'tier_name': 'VIP', 'price_cents': 5000, 'max_reserved_spots': 10, 'reserved_so_far': 3, 'available': 7},
        ],
      });

      expect(preview.amountCents, 5000);
      expect(preview.reservedSpots, 2);
      expect(preview.costPerSpotCents, 2500);
      expect(preview.platformCutCents, 250);
      expect(preview.fundingCommissionPercent, 5);
      expect(preview.availableSpotsForUser, 3);
      expect(preview.linkFundingToTiers, true);
      expect(preview.tierAvailability.length, 1);
      expect(preview.tierAvailability[0].tierName, 'VIP');
      expect(preview.tierAvailability[0].available, 7);
    });

    test('amountFormatted', () {
      final preview = PledgePreview.fromJson({'amount_cents': 12345});
      expect(preview.amountFormatted, '\$123.45');
    });

    test('defaults when fields missing', () {
      final preview = PledgePreview.fromJson({});
      expect(preview.amountCents, 0);
      expect(preview.reservedSpots, 0);
      expect(preview.linkFundingToTiers, false);
      expect(preview.tierAvailability, isEmpty);
    });
  });

  group('TierAvailability', () {
    test('fromJson parses all fields', () {
      final ta = TierAvailability.fromJson({
        'tier_id': 3,
        'tier_name': 'Gold',
        'price_cents': 8000,
        'max_reserved_spots': 20,
        'reserved_so_far': 5,
        'available': 15,
      });
      expect(ta.tierId, 3);
      expect(ta.tierName, 'Gold');
      expect(ta.priceCents, 8000);
      expect(ta.maxReservedSpots, 20);
      expect(ta.reservedSoFar, 5);
      expect(ta.available, 15);
    });
  });

  group('RefundStatus', () {
    test('fromJson parses all fields', () {
      final rs = RefundStatus.fromJson({
        'status': 'in_progress',
        'processing_count': 3,
        'completed_count': 7,
        'failed_count': 1,
      });
      expect(rs.status, 'in_progress');
      expect(rs.processingCount, 3);
      expect(rs.completedCount, 7);
      expect(rs.failedCount, 1);
    });

    test('defaults when fields missing', () {
      final rs = RefundStatus.fromJson({});
      expect(rs.status, 'none');
      expect(rs.processingCount, 0);
      expect(rs.completedCount, 0);
      expect(rs.failedCount, 0);
    });
  });

  group('TierReservationInput', () {
    test('constructor and toJson', () {
      final t = TierReservationInput(tierId: 3, tierName: 'VIP', spots: 2);
      expect(t.tierId, 3);
      expect(t.tierName, 'VIP');
      expect(t.spots, 2);

      final json = t.toJson();
      expect(json['tier_id'], 3);
      expect(json['spots'], 2);
      expect(json.containsKey('tier_name'), false);
    });

    test('tierName nullable', () {
      final t = TierReservationInput(tierId: 1, spots: 1);
      expect(t.tierName, isNull);
    });
  });

  group('UnpledgeResult', () {
    test('fromJson parses all fields', () {
      final r = UnpledgeResult.fromJson({
        'refunded_cents': 10000,
        'guest_non_refundable_cents': 2000,
        'status': 'refund_initiated',
        'unpledged_amount_cents': 12000,
        'remaining_pledges': 3,
        'refund_initiated': true,
      });
      expect(r.refundedCents, 10000);
      expect(r.guestNonRefundableCents, 2000);
      expect(r.status, 'refund_initiated');
      expect(r.unpledgedAmountCents, 12000);
      expect(r.remainingPledges, 3);
      expect(r.refundInitiated, true);
    });

    test('defaults when fields missing', () {
      final r = UnpledgeResult.fromJson({});
      expect(r.refundedCents, 0);
      expect(r.guestNonRefundableCents, 0);
      expect(r.status, 'completed');
      expect(r.unpledgedAmountCents, 0);
      expect(r.remainingPledges, 0);
      expect(r.refundInitiated, false);
    });
  });
}
