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

  group('OrganizerSponsorItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'sponsor_user_id': 42,
        'company_name': 'TechCo',
        'contact_name': 'Jane Doe',
        'logo_url': 'https://example.com/logo.png',
        'total_bids': 5,
        'total_amount_cents': 150000,
      };
      final item = OrganizerSponsorItem.fromJson(json);

      expect(item.sponsorUserId, 42);
      expect(item.companyName, 'TechCo');
      expect(item.contactName, 'Jane Doe');
      expect(item.logoUrl, 'https://example.com/logo.png');
      expect(item.totalBids, 5);
      expect(item.totalAmountCents, 150000);
      expect(item.totalAmountDisplay, '\$1500.00');
    });

    test('defaults for optional fields', () {
      final json = {'sponsor_user_id': 1};
      final item = OrganizerSponsorItem.fromJson(json);

      expect(item.companyName, '');
      expect(item.contactName, '');
      expect(item.logoUrl, isNull);
      expect(item.totalBids, 0);
      expect(item.totalAmountCents, 0);
    });
  });

  group('SponsorEventBid', () {
    test('fromJson parses all fields', () {
      final json = {
        'category': 'Gold Sponsor',
        'amount_cents': 50000,
        'status': 'accepted',
      };
      final bid = SponsorEventBid.fromJson(json);

      expect(bid.category, 'Gold Sponsor');
      expect(bid.amountCents, 50000);
      expect(bid.status, 'accepted');
    });

    test('defaults for missing fields', () {
      final bid = SponsorEventBid.fromJson({});

      expect(bid.category, '');
      expect(bid.amountCents, 0);
      expect(bid.status, '');
    });
  });

  group('SponsorEventItem', () {
    test('fromJson parses all fields including bids', () {
      final json = {
        'event_id': 10,
        'title': 'Music Fest',
        'status': 'approved',
        'start_time': '2025-06-15T18:00:00',
        'venue_name': 'Grand Arena',
        'venue_city': 'NYC',
        'bids': [
          {'category': 'Gold', 'amount_cents': 50000, 'status': 'accepted'},
          {'category': 'Silver', 'amount_cents': 20000, 'status': 'pending'},
        ],
        'total_amount_cents': 70000,
      };
      final item = SponsorEventItem.fromJson(json);

      expect(item.eventId, 10);
      expect(item.title, 'Music Fest');
      expect(item.status, 'approved');
      expect(item.startTime, '2025-06-15T18:00:00');
      expect(item.venueName, 'Grand Arena');
      expect(item.venueCity, 'NYC');
      expect(item.bids.length, 2);
      expect(item.bids[0].category, 'Gold');
      expect(item.bids[1].status, 'pending');
      expect(item.totalAmountCents, 70000);
    });

    test('defaults for optional fields', () {
      final json = {
        'event_id': 11,
        'title': 'Test',
        'status': 'draft',
        'total_amount_cents': 0,
      };
      final item = SponsorEventItem.fromJson(json);

      expect(item.startTime, isNull);
      expect(item.venueName, isNull);
      expect(item.venueCity, isNull);
      expect(item.bids, isEmpty);
    });
  });

  group('SponsorPaymentReceipt', () {
    test('fromJson parses all fields', () {
      final json = {
        'payment_id': 1,
        'receipt_number': 'REC-SP-001',
        'type': 'payment',
        'amount_cents': 50000,
        'platform_cut_cents': 5000,
        'net_to_organizer_cents': 45000,
        'subtotal_cents': 50000,
        'tax_cents': 2500,
        'tax_rate': 5.0,
        'status': 'completed',
        'created_at': '2025-02-01T10:00:00',
        'bid_id': 10,
        'bid_amount_cents': 50000,
        'bid_proposal': 'Our proposal',
        'category_name': 'Gold Sponsor',
        'event_id': 5,
        'event_title': 'Rock Concert',
        'sponsor_name': 'Acme Corp',
        'sponsor_email': 'acme@test.com',
      };
      final r = SponsorPaymentReceipt.fromJson(json);

      expect(r.paymentId, 1);
      expect(r.receiptNumber, 'REC-SP-001');
      expect(r.type, 'payment');
      expect(r.amountCents, 50000);
      expect(r.platformCutCents, 5000);
      expect(r.netToOrganizerCents, 45000);
      expect(r.subtotalCents, 50000);
      expect(r.taxCents, 2500);
      expect(r.taxRate, 5.0);
      expect(r.status, 'completed');
      expect(r.createdAt, '2025-02-01T10:00:00');
      expect(r.bidId, 10);
      expect(r.bidAmountCents, 50000);
      expect(r.bidProposal, 'Our proposal');
      expect(r.categoryName, 'Gold Sponsor');
      expect(r.eventId, 5);
      expect(r.eventTitle, 'Rock Concert');
      expect(r.sponsorName, 'Acme Corp');
      expect(r.sponsorEmail, 'acme@test.com');
      expect(r.amountDisplay, '\$500.00');
      expect(r.netDisplay, '\$450.00');
    });

    test('defaults for optional fields', () {
      final json = {
        'payment_id': 2,
        'bid_id': 11,
      };
      final r = SponsorPaymentReceipt.fromJson(json);

      expect(r.receiptNumber, '');
      expect(r.type, 'payment');
      expect(r.amountCents, 0);
      expect(r.status, '');
      expect(r.createdAt, isNull);
      expect(r.bidProposal, isNull);
      expect(r.categoryName, isNull);
      expect(r.eventId, isNull);
      expect(r.eventTitle, isNull);
      expect(r.sponsorName, isNull);
      expect(r.sponsorEmail, isNull);
    });
  });

  group('ScannedDelegate', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'name': 'Alice',
        'checked_in': true,
        'checked_in_at': '2025-02-01T18:30:00',
      };
      final d = ScannedDelegate.fromJson(json);

      expect(d.id, 1);
      expect(d.name, 'Alice');
      expect(d.checkedIn, true);
      expect(d.checkedInAt, '2025-02-01T18:30:00');
    });

    test('defaults for optional fields', () {
      final json = {'id': 2};
      final d = ScannedDelegate.fromJson(json);

      expect(d.name, '');
      expect(d.checkedIn, false);
      expect(d.checkedInAt, isNull);
    });
  });

  group('ScannedSponsorTicket', () {
    test('fromJson parses all fields including delegates', () {
      final json = {
        'id': 1,
        'event_id': 5,
        'receipt_number': 'ST-001',
        'company_name': 'Acme Corp',
        'contact_name': 'John',
        'scan_count': 2,
        'scanned_at': '2025-02-01T18:00:00',
        'total_delegates': 3,
        'checked_in_count': 1,
        'delegates': [
          {'id': 1, 'name': 'Alice', 'checked_in': true, 'checked_in_at': '2025-02-01T18:30:00'},
          {'id': 2, 'name': 'Bob', 'checked_in': false},
        ],
      };
      final t = ScannedSponsorTicket.fromJson(json);

      expect(t.id, 1);
      expect(t.eventId, 5);
      expect(t.receiptNumber, 'ST-001');
      expect(t.companyName, 'Acme Corp');
      expect(t.contactName, 'John');
      expect(t.scanCount, 2);
      expect(t.scannedAt, '2025-02-01T18:00:00');
      expect(t.totalDelegates, 3);
      expect(t.checkedInCount, 1);
      expect(t.delegates.length, 2);
      expect(t.delegates[0].name, 'Alice');
      expect(t.delegates[1].checkedIn, false);
    });

    test('defaults for optional fields', () {
      final json = {'id': 2, 'event_id': 3, 'receipt_number': 'ST-002'};
      final t = ScannedSponsorTicket.fromJson(json);

      expect(t.companyName, '');
      expect(t.contactName, '');
      expect(t.scanCount, 0);
      expect(t.scannedAt, isNull);
      expect(t.delegates, isEmpty);
    });
  });

  group('EventSponsor', () {
    test('fromJson parses all fields', () {
      final json = {
        'sponsor_user_id': 10,
        'company_name': 'BigCo',
        'logo_url': 'https://example.com/logo.png',
        'website_url': 'https://bigco.com',
      };
      final s = EventSponsor.fromJson(json);

      expect(s.sponsorUserId, 10);
      expect(s.companyName, 'BigCo');
      expect(s.logoUrl, 'https://example.com/logo.png');
      expect(s.websiteUrl, 'https://bigco.com');
    });

    test('defaults for optional fields', () {
      final json = {'sponsor_user_id': 11};
      final s = EventSponsor.fromJson(json);

      expect(s.companyName, '');
      expect(s.logoUrl, isNull);
      expect(s.websiteUrl, isNull);
    });
  });

  group('CategoryPrerequisite', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'name': 'Company Logo',
        'description': 'Upload your company logo',
        'is_required': true,
        'requires_document': true,
      };
      final p = CategoryPrerequisite.fromJson(json);

      expect(p.id, 1);
      expect(p.name, 'Company Logo');
      expect(p.description, 'Upload your company logo');
      expect(p.isRequired, true);
      expect(p.requiresDocument, true);
    });

    test('defaults for optional fields', () {
      final json = {'id': 2};
      final p = CategoryPrerequisite.fromJson(json);

      expect(p.name, '');
      expect(p.description, isNull);
      expect(p.isRequired, false);
      expect(p.requiresDocument, false);
    });
  });

  group('BidPrerequisiteUpload', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'bid_id': 10,
        'prerequisite_id': 5,
        'file_url': 'https://storage.example.com/file.pdf',
        'status': 'approved',
        'reviewed_at': '2025-02-10T12:00:00',
        'reviewer_note': 'Looks good',
      };
      final u = BidPrerequisiteUpload.fromJson(json);

      expect(u.id, 1);
      expect(u.bidId, 10);
      expect(u.prerequisiteId, 5);
      expect(u.fileUrl, 'https://storage.example.com/file.pdf');
      expect(u.status, 'approved');
      expect(u.reviewedAt, '2025-02-10T12:00:00');
      expect(u.reviewerNote, 'Looks good');
    });

    test('defaults for optional fields', () {
      final json = {
        'id': 2,
        'bid_id': 11,
        'prerequisite_id': 6,
      };
      final u = BidPrerequisiteUpload.fromJson(json);

      expect(u.fileUrl, '');
      expect(u.status, 'pending');
      expect(u.reviewedAt, isNull);
      expect(u.reviewerNote, isNull);
    });
  });

  // ─── New Phase 2 model classes ───

  group('SponsorCategoryTemplate', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 5,
        'name': 'Gold Template',
        'description': 'Premium sponsor template',
        'image_url': 'https://example.com/gold.png',
        'total_spots': 3,
        'min_bid_cents': 50000,
        'sort_order': 1,
      };
      final t = SponsorCategoryTemplate.fromJson(json);

      expect(t.id, 5);
      expect(t.name, 'Gold Template');
      expect(t.description, 'Premium sponsor template');
      expect(t.imageUrl, 'https://example.com/gold.png');
      expect(t.totalSpots, 3);
      expect(t.minBidCents, 50000);
      expect(t.sortOrder, 1);
    });

    test('defaults for optional fields', () {
      final json = {'id': 6};
      final t = SponsorCategoryTemplate.fromJson(json);

      expect(t.name, '');
      expect(t.description, isNull);
      expect(t.imageUrl, isNull);
      expect(t.totalSpots, 0);
      expect(t.minBidCents, 0);
      expect(t.sortOrder, 0);
    });
  });

  group('TemplatePrerequisite', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 3,
        'name': 'Company Logo',
        'description': 'Upload high-res logo',
        'is_required': true,
        'requires_document': true,
      };
      final p = TemplatePrerequisite.fromJson(json);

      expect(p.id, 3);
      expect(p.name, 'Company Logo');
      expect(p.description, 'Upload high-res logo');
      expect(p.isRequired, true);
      expect(p.requiresDocument, true);
    });

    test('defaults for optional fields', () {
      final json = {'id': 4};
      final p = TemplatePrerequisite.fromJson(json);

      expect(p.name, '');
      expect(p.description, isNull);
      expect(p.isRequired, false);
      expect(p.requiresDocument, false);
    });
  });

  group('FileUploadResult', () {
    test('fromJson parses all fields with file_url key', () {
      final json = {
        'id': 7,
        'file_url': 'https://storage.example.com/doc.pdf',
        'status': 'approved',
      };
      final f = FileUploadResult.fromJson(json);

      expect(f.id, 7);
      expect(f.fileUrl, 'https://storage.example.com/doc.pdf');
      expect(f.status, 'approved');
    });

    test('fromJson falls back to url key', () {
      final json = {
        'url': 'https://storage.example.com/alt.pdf',
      };
      final f = FileUploadResult.fromJson(json);

      expect(f.id, isNull);
      expect(f.fileUrl, 'https://storage.example.com/alt.pdf');
      expect(f.status, isNull);
    });

    test('defaults when both url keys missing', () {
      final f = FileUploadResult.fromJson({});
      expect(f.fileUrl, '');
    });
  });

  group('ChatImageUpload', () {
    test('fromJson parses all fields', () {
      final json = {
        'url': 'https://storage.example.com/chat/img.png',
        'file_name': 'screenshot.png',
      };
      final c = ChatImageUpload.fromJson(json);

      expect(c.url, 'https://storage.example.com/chat/img.png');
      expect(c.fileName, 'screenshot.png');
    });

    test('defaults for missing fields', () {
      final c = ChatImageUpload.fromJson({});
      expect(c.url, '');
      expect(c.fileName, isNull);
    });
  });

  group('SponsorBidEvent', () {
    test('fromJson parses event and bid_summary', () {
      final json = eventJson(id: 42, title: 'Music Festival');
      json['bid_summary'] = {
        'pending': 3,
        'accepted': 2,
        'rejected': 1,
        'paid': 4,
      };
      final sbe = SponsorBidEvent.fromJson(json);

      expect(sbe.event.id, 42);
      expect(sbe.event.title, 'Music Festival');
      expect(sbe.pending, 3);
      expect(sbe.accepted, 2);
      expect(sbe.rejected, 1);
      expect(sbe.paid, 4);
      expect(sbe.totalBids, 10);
    });

    test('defaults when bid_summary is missing', () {
      final json = eventJson(id: 1, title: 'Test');
      final sbe = SponsorBidEvent.fromJson(json);

      expect(sbe.pending, 0);
      expect(sbe.accepted, 0);
      expect(sbe.rejected, 0);
      expect(sbe.paid, 0);
      expect(sbe.totalBids, 0);
    });
  });

  group('SponsorshipCategory myBids typed parsing', () {
    test('fromJson parses myBids as List<SponsorBid>', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'name': 'Gold',
        'total_spots': 5,
        'min_bid_cents': 10000,
        'my_bid_count': 2,
        'my_bids': [
          sponsorBidJson(id: 10, amountCents: 20000, status: 'pending'),
          sponsorBidJson(id: 11, amountCents: 30000, status: 'accepted'),
        ],
      };
      final cat = SponsorshipCategory.fromJson(json);

      expect(cat.myBids.length, 2);
      expect(cat.myBids[0], isA<SponsorBid>());
      expect(cat.myBids[0].id, 10);
      expect(cat.myBids[0].amountCents, 20000);
      expect(cat.myBids[1].status, 'accepted');
    });

    test('myBids defaults to empty list when not provided', () {
      final json = {
        'id': 2,
        'event_id': 1,
        'name': 'Silver',
        'total_spots': 3,
        'min_bid_cents': 5000,
      };
      final cat = SponsorshipCategory.fromJson(json);
      expect(cat.myBids, isEmpty);
    });
  });
}
