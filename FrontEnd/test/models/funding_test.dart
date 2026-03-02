import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/funding.dart';
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
        pledgeCount: 50,
        totalReservedSpots: 20,
        fundingEndAt: '2025-07-01T00:00:00',
      );
      final summary = FundingSummary.fromJson(json);

      expect(summary.goalCents, 200000);
      expect(summary.totalPledgedCents, 150000);
      expect(summary.pledgeCount, 50);
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
}
