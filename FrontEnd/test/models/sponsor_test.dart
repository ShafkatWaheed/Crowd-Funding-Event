import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/sponsor.dart';
import '../helpers/fixtures.dart';

void main() {
  group('SponsorProfile', () {
    test('fromJson parses all fields', () {
      final json = sponsorProfileJson(
        id: 3,
        userId: 7,
        companyName: 'TechCo',
        contactName: 'Jane',
        profession: 'Engineering',
        logoUrl: 'https://example.com/logo.png',
        description: 'A tech company',
      );
      final profile = SponsorProfile.fromJson(json);

      expect(profile.id, 3);
      expect(profile.userId, 7);
      expect(profile.companyName, 'TechCo');
      expect(profile.contactName, 'Jane');
      expect(profile.profession, 'Engineering');
      expect(profile.logoUrl, 'https://example.com/logo.png');
      expect(profile.description, 'A tech company');
    });

    test('nullable fields default to empty strings', () {
      final json = {'id': 1, 'user_id': 1};
      final profile = SponsorProfile.fromJson(json);
      expect(profile.companyName, '');
      expect(profile.contactName, '');
      expect(profile.profession, '');
      expect(profile.logoUrl, isNull);
    });
  });

  group('SponsorshipCategory', () {
    test('fromJson parses all fields', () {
      final json = sponsorshipCategoryJson(
        id: 2,
        eventId: 5,
        name: 'Platinum',
        totalSpots: 3,
        filledSpots: 1,
        minBidCents: 50000,
      );
      final cat = SponsorshipCategory.fromJson(json);

      expect(cat.id, 2);
      expect(cat.eventId, 5);
      expect(cat.name, 'Platinum');
      expect(cat.totalSpots, 3);
      expect(cat.filledSpots, 1);
      expect(cat.minBidCents, 50000);
    });

    test('availableSpots computed correctly', () {
      final cat = SponsorshipCategory.fromJson(
        sponsorshipCategoryJson(totalSpots: 5, filledSpots: 2),
      );
      expect(cat.availableSpots, 3);
    });

    test('minBidDisplay formats correctly', () {
      final cat = SponsorshipCategory.fromJson(
        sponsorshipCategoryJson(minBidCents: 10000),
      );
      expect(cat.minBidDisplay, '\$100.00');
    });

    test('canPlaceMoreBids', () {
      final json = sponsorshipCategoryJson(totalSpots: 3, filledSpots: 1);
      json['my_bid_count'] = 0;
      final cat = SponsorshipCategory.fromJson(json);
      expect(cat.canPlaceMoreBids, true);
    });
  });

  group('SponsorBid', () {
    test('fromJson parses all fields', () {
      final json = sponsorBidJson(
        id: 5,
        categoryId: 2,
        sponsorUserId: 7,
        amountCents: 25000,
        proposalText: 'Our proposal',
        status: 'accepted',
      );
      final bid = SponsorBid.fromJson(json);

      expect(bid.id, 5);
      expect(bid.categoryId, 2);
      expect(bid.sponsorUserId, 7);
      expect(bid.amountCents, 25000);
      expect(bid.proposalText, 'Our proposal');
      expect(bid.status, 'accepted');
    });

    test('status getters', () {
      expect(SponsorBid.fromJson(sponsorBidJson(status: 'pending')).isPending, true);
      expect(SponsorBid.fromJson(sponsorBidJson(status: 'accepted')).isAccepted, true);
      expect(SponsorBid.fromJson(sponsorBidJson(status: 'paid')).isPaid, true);
    });

    test('amountDisplay', () {
      final bid = SponsorBid.fromJson(sponsorBidJson(amountCents: 15000));
      expect(bid.amountDisplay, '\$150.00');
    });

    test('nested sponsorProfile parsed when present', () {
      final json = sponsorBidJson();
      json['sponsor_profile'] = sponsorProfileJson(companyName: 'TestCo');
      final bid = SponsorBid.fromJson(json);
      expect(bid.sponsorProfile, isNotNull);
      expect(bid.sponsorProfile!.companyName, 'TestCo');
    });

    test('sponsorProfile null when not in JSON', () {
      final bid = SponsorBid.fromJson(sponsorBidJson());
      expect(bid.sponsorProfile, isNull);
    });
  });

  group('SponsorPayment', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'bid_id': 5,
        'amount_cents': 25000,
        'platform_cut_cents': 2500,
        'net_to_organizer_cents': 22500,
        'receipt_number': 'SP-REC-001',
        'status': 'completed',
      };
      final payment = SponsorPayment.fromJson(json);

      expect(payment.id, 1);
      expect(payment.bidId, 5);
      expect(payment.amountCents, 25000);
      expect(payment.platformCutCents, 2500);
      expect(payment.netToOrganizerCents, 22500);
      expect(payment.receiptNumber, 'SP-REC-001');
      expect(payment.status, 'completed');
    });
  });

  group('SponsorTicketPrereq', () {
    test('fromJson parses and isUploaded getter', () {
      final uploaded = SponsorTicketPrereq.fromJson({
        'id': 1,
        'name': 'Logo',
        'is_required': true,
        'upload_status': 'approved',
      });
      expect(uploaded.isUploaded, true);

      final notUploaded = SponsorTicketPrereq.fromJson({
        'id': 2,
        'name': 'Banner',
        'is_required': false,
      });
      expect(notUploaded.isUploaded, false);
    });
  });

  group('SponsorTicketCategory', () {
    test('fromJson and computed getters', () {
      final json = {
        'name': 'Gold',
        'amount_cents': 50000,
        'status': 'paid',
        'prerequisites': [
          {'id': 1, 'name': 'Logo', 'is_required': true},
        ],
      };
      final cat = SponsorTicketCategory.fromJson(json);
      expect(cat.name, 'Gold');
      expect(cat.amountDisplay, '\$500.00');
      expect(cat.isPaid, true);
      expect(cat.isRefunded, false);
      expect(cat.prerequisites.length, 1);
    });
  });

  group('SponsorTicketModel', () {
    test('fromJson and amount getters', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'sponsor_user_id': 5,
        'receipt_number': 'ST-001',
        'categories': [
          {'name': 'Gold', 'amount_cents': 50000, 'status': 'paid'},
          {'name': 'Silver', 'amount_cents': 20000, 'status': 'refunded'},
        ],
      };
      final ticket = SponsorTicketModel.fromJson(json);
      expect(ticket.totalAmountCents, 70000);
      expect(ticket.activeTotalCents, 50000);
      expect(ticket.refundedTotalCents, 20000);
      expect(ticket.hasRefunds, true);
      expect(ticket.totalAmountDisplay, '\$700.00');
    });
  });
}
