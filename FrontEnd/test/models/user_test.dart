import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/user.dart';
import '../helpers/fixtures.dart';

void main() {
  group('AppUser', () {
    test('fromJson parses all fields', () {
      final json = userJson(
        id: 42,
        email: 'alice@example.com',
        displayName: 'Alice',
        role: 'organizer',
        phone: '+1234567890',
        birthday: '1990-05-15',
        kycStatus: 'verified',
        kycVerified: true,
      );
      final user = AppUser.fromJson(json);

      expect(user.id, 42);
      expect(user.email, 'alice@example.com');
      expect(user.displayName, 'Alice');
      expect(user.role, UserRole.organizer);
      expect(user.phone, '+1234567890');
      expect(user.birthday, '1990-05-15');
      expect(user.kycStatus, 'verified');
      expect(user.kycVerified, true);
    });

    test('role enum parsing with unknown role falls back to customer', () {
      final json = userJson(role: 'unknown_role');
      final user = AppUser.fromJson(json);
      expect(user.role, UserRole.customer);
    });

    test('isAdmin/isOrganizer/isCustomer/isSponsor getters', () {
      expect(AppUser.fromJson(userJson(role: 'admin')).isAdmin, true);
      expect(AppUser.fromJson(userJson(role: 'admin')).isOrganizer, false);

      expect(AppUser.fromJson(userJson(role: 'organizer')).isOrganizer, true);
      expect(AppUser.fromJson(userJson(role: 'organizer')).isAdmin, false);

      expect(AppUser.fromJson(userJson(role: 'customer')).isCustomer, true);
      expect(AppUser.fromJson(userJson(role: 'sponsor')).isSponsor, true);
    });

    test('displayLabel returns displayName when present', () {
      final user = AppUser.fromJson(userJson(displayName: 'Bob'));
      expect(user.displayLabel, 'Bob');
    });

    test('displayLabel falls back to User when displayName is null', () {
      final user = AppUser.fromJson(userJson(displayName: null));
      expect(user.displayLabel, 'User');
    });

    test('initial returns first character uppercase', () {
      final user = AppUser.fromJson(userJson(displayName: 'alice'));
      expect(user.initial, 'A');
    });

    test('maskedEmail masks correctly', () {
      final user = AppUser.fromJson(userJson(email: 'alice@example.com'));
      expect(user.maskedEmail, 'al***@example.com');
    });

    test('maskedEmail handles short local part', () {
      final user = AppUser.fromJson(userJson(email: 'a@example.com'));
      expect(user.maskedEmail, 'a***@example.com');
    });

    test('maskedEmail handles empty email', () {
      final user = AppUser.fromJson(userJson(email: ''));
      expect(user.maskedEmail, '?');
    });

    test('nullable birthday handled correctly', () {
      final user = AppUser.fromJson(userJson(birthday: null));
      expect(user.birthday, isNull);
    });

    test('kycStatus defaults', () {
      final json = {'id': 1, 'email': 'test@test.com', 'role': 'customer'};
      final user = AppUser.fromJson(json);
      expect(user.kycStatus, 'not_started');
      expect(user.kycVerified, false);
    });
  });

  // ─── PaymentInfo ───

  group('PaymentInfo', () {
    test('fromJson parses all fields', () {
      final pi = PaymentInfo.fromJson({
        'mode': 'manual',
        'card_holder_name': 'Alice Smith',
        'card_last_four': '4242',
        'card_brand': 'visa',
        'billing_address': '123 Main St',
        'has_payment_method': true,
        'stripe_customer_id': 'cus_abc',
        'stripe_configured': true,
      });
      expect(pi.mode, 'manual');
      expect(pi.cardHolderName, 'Alice Smith');
      expect(pi.cardLastFour, '4242');
      expect(pi.cardBrand, 'visa');
      expect(pi.billingAddress, '123 Main St');
      expect(pi.hasPaymentMethod, true);
      expect(pi.stripeCustomerId, 'cus_abc');
      expect(pi.stripeConfigured, true);
    });

    test('fromJson handles nulls and defaults', () {
      final pi = PaymentInfo.fromJson({});
      expect(pi.mode, isNull);
      expect(pi.cardHolderName, isNull);
      expect(pi.cardLastFour, isNull);
      expect(pi.hasPaymentMethod, false);
      expect(pi.stripeConfigured, isNull);
    });
  });

  // ─── BankAccount ───

  group('BankAccount', () {
    test('fromJson parses all fields', () {
      final ba = BankAccount.fromJson({
        'mode': 'manual',
        'institution_number': '001',
        'transit_number': '12345',
        'account_last_four': '6789',
        'account_holder_masked': 'A***e',
        'verified': true,
        'verification_status': 'verified',
        'rejection_reason': null,
        'payout_schedule': 'monthly',
        'payout_day': 15,
        'min_payout_cents': 5000,
        'has_bank_account': true,
        'decryption_failed': false,
        'stripe_connect_account_id': 'acct_xyz',
        'stripe_connected': true,
      });
      expect(ba.mode, 'manual');
      expect(ba.institutionNumber, '001');
      expect(ba.transitNumber, '12345');
      expect(ba.accountLastFour, '6789');
      expect(ba.accountHolderMasked, 'A***e');
      expect(ba.verified, true);
      expect(ba.verificationStatus, 'verified');
      expect(ba.rejectionReason, isNull);
      expect(ba.payoutSchedule, 'monthly');
      expect(ba.payoutDay, 15);
      expect(ba.minPayoutCents, 5000);
      expect(ba.hasBankAccount, true);
      expect(ba.decryptionFailed, false);
      expect(ba.stripeConnectAccountId, 'acct_xyz');
      expect(ba.stripeConnected, true);
    });

    test('fromJson handles defaults', () {
      final ba = BankAccount.fromJson({});
      expect(ba.verified, false);
      expect(ba.verificationStatus, 'pending');
      expect(ba.payoutSchedule, 'weekly');
      expect(ba.payoutDay, 1);
      expect(ba.minPayoutCents, 2500);
      expect(ba.hasBankAccount, false);
      expect(ba.decryptionFailed, false);
    });
  });

  // ─── TrustInfo ───

  group('TrustInfo', () {
    test('fromJson parses all fields', () {
      final ti = TrustInfo.fromJson({
        'trust_score': 85.5,
        'label': 'Trusted',
        'completed_events': 10,
        'published_events': 12,
      });
      expect(ti.trustScore, 85.5);
      expect(ti.label, 'Trusted');
      expect(ti.completedEvents, 10);
      expect(ti.publishedEvents, 12);
    });

    test('fromJson handles defaults', () {
      final ti = TrustInfo.fromJson({});
      expect(ti.trustScore, 0.0);
      expect(ti.label, 'New');
      expect(ti.completedEvents, 0);
      expect(ti.publishedEvents, 0);
    });

    test('fromJson handles integer trust_score', () {
      final ti = TrustInfo.fromJson({'trust_score': 90});
      expect(ti.trustScore, 90.0);
    });
  });

  // ─── PublicSponsorInfo ───

  group('PublicSponsorInfo', () {
    test('fromJson parses all fields', () {
      final ps = PublicSponsorInfo.fromJson({
        'id': 5,
        'company_name': 'Acme Corp',
        'contact_name': 'Bob',
        'profession': 'Marketing',
        'logo_url': 'https://example.com/logo.png',
        'description': 'A great company',
        'website_url': 'https://acme.com',
      });
      expect(ps.id, 5);
      expect(ps.companyName, 'Acme Corp');
      expect(ps.contactName, 'Bob');
      expect(ps.profession, 'Marketing');
      expect(ps.logoUrl, 'https://example.com/logo.png');
      expect(ps.description, 'A great company');
      expect(ps.websiteUrl, 'https://acme.com');
    });

    test('fromJson handles all nulls', () {
      final ps = PublicSponsorInfo.fromJson({});
      expect(ps.id, isNull);
      expect(ps.companyName, isNull);
      expect(ps.websiteUrl, isNull);
    });
  });

  // ─── EventMetrics ───

  group('EventMetrics', () {
    test('fromJson parses all fields', () {
      final em = EventMetrics.fromJson({
        'completed': 5,
        'cancelled': 2,
        'live': 3,
        'approved': 1,
        'selling_tickets': 4,
        'total': 15,
      });
      expect(em.completed, 5);
      expect(em.cancelled, 2);
      expect(em.live, 3);
      expect(em.approved, 1);
      expect(em.sellingTickets, 4);
      expect(em.total, 15);
    });

    test('fromJson defaults to zero', () {
      final em = EventMetrics.fromJson({});
      expect(em.completed, 0);
      expect(em.cancelled, 0);
      expect(em.live, 0);
      expect(em.approved, 0);
      expect(em.sellingTickets, 0);
      expect(em.total, 0);
    });
  });

  // ─── PublicProfile ───

  group('PublicProfile', () {
    test('fromJson parses all fields with nested objects', () {
      final pp = PublicProfile.fromJson({
        'id': 10,
        'display_name': 'Alice',
        'role': 'organizer',
        'address': 'Toronto, ON',
        'years_of_experience': 5,
        'created_at': '2024-01-01T00:00:00Z',
        'trust': {
          'trust_score': 92.0,
          'label': 'Highly Trusted',
          'completed_events': 20,
          'published_events': 25,
        },
        'sponsor_profile': {
          'id': 3,
          'company_name': 'Acme',
        },
        'event_metrics': {
          'completed': 8,
          'total': 10,
        },
      });
      expect(pp.id, 10);
      expect(pp.displayName, 'Alice');
      expect(pp.role, 'organizer');
      expect(pp.address, 'Toronto, ON');
      expect(pp.yearsOfExperience, 5);
      expect(pp.createdAt, '2024-01-01T00:00:00Z');
      expect(pp.trust, isNotNull);
      expect(pp.trust!.trustScore, 92.0);
      expect(pp.trust!.label, 'Highly Trusted');
      expect(pp.sponsorProfile, isNotNull);
      expect(pp.sponsorProfile!.companyName, 'Acme');
      expect(pp.eventMetrics, isNotNull);
      expect(pp.eventMetrics!.completed, 8);
    });

    test('fromJson handles null nested objects', () {
      final pp = PublicProfile.fromJson({
        'id': 1,
        'role': 'customer',
      });
      expect(pp.trust, isNull);
      expect(pp.sponsorProfile, isNull);
      expect(pp.eventMetrics, isNull);
      expect(pp.displayName, isNull);
      expect(pp.role, 'customer');
    });

    test('fromJson defaults role to empty string', () {
      final pp = PublicProfile.fromJson({'id': 1});
      expect(pp.role, '');
    });
  });

  // ─── SponsorPublicProfile ───

  group('SponsorPublicProfile', () {
    test('fromJson parses all fields', () {
      final sp = SponsorPublicProfile.fromJson({
        'id': 7,
        'display_name': 'Bob Corp',
        'company_name': 'Bob Inc',
        'contact_name': 'Bob',
        'profession': 'Finance',
        'logo_url': 'https://example.com/bob.png',
        'description': 'Finance company',
        'website_url': 'https://bob.com',
        'member_since': '2023-06-01',
        'total_bids': 20,
        'accepted_bids': 15,
        'events_sponsored': 8,
      });
      expect(sp.id, 7);
      expect(sp.displayName, 'Bob Corp');
      expect(sp.companyName, 'Bob Inc');
      expect(sp.contactName, 'Bob');
      expect(sp.profession, 'Finance');
      expect(sp.logoUrl, 'https://example.com/bob.png');
      expect(sp.description, 'Finance company');
      expect(sp.websiteUrl, 'https://bob.com');
      expect(sp.memberSince, '2023-06-01');
      expect(sp.totalBids, 20);
      expect(sp.acceptedBids, 15);
      expect(sp.eventsSponsored, 8);
    });

    test('fromJson handles defaults', () {
      final sp = SponsorPublicProfile.fromJson({'id': 1});
      expect(sp.totalBids, 0);
      expect(sp.acceptedBids, 0);
      expect(sp.eventsSponsored, 0);
      expect(sp.displayName, isNull);
      expect(sp.companyName, isNull);
    });
  });

  // ─── KycDocument ───

  group('KycDocument', () {
    test('fromJson parses all fields', () {
      final doc = KycDocument.fromJson({
        'id': 42,
        'document_type': 'id_front',
        'file_url': 'https://example.com/doc.jpg',
        'mime_type': 'image/jpeg',
        'original_filename': 'my_id.jpg',
        'status': 'approved',
        'rejection_reason': null,
        'submitted_at': '2024-03-01T12:00:00Z',
      });
      expect(doc.id, 42);
      expect(doc.documentType, 'id_front');
      expect(doc.fileUrl, 'https://example.com/doc.jpg');
      expect(doc.mimeType, 'image/jpeg');
      expect(doc.originalFilename, 'my_id.jpg');
      expect(doc.status, 'approved');
      expect(doc.rejectionReason, isNull);
      expect(doc.submittedAt, '2024-03-01T12:00:00Z');
    });

    test('fromJson handles defaults', () {
      final doc = KycDocument.fromJson({
        'id': 1,
      });
      expect(doc.documentType, '');
      expect(doc.status, 'pending');
      expect(doc.fileUrl, isNull);
      expect(doc.originalFilename, isNull);
    });

    test('fromJson with rejection reason', () {
      final doc = KycDocument.fromJson({
        'id': 2,
        'document_type': 'proof_of_address',
        'status': 'rejected',
        'rejection_reason': 'Image is blurry',
      });
      expect(doc.status, 'rejected');
      expect(doc.rejectionReason, 'Image is blurry');
    });
  });

  // ─── KycStatus ───

  group('KycStatus', () {
    test('fromJson parses all fields with documents', () {
      final ks = KycStatus.fromJson({
        'kyc_status': 'submitted',
        'kyc_verified': false,
        'kyc_verified_at': null,
        'kyc_required_for_role': true,
        'documents': [
          {'id': 1, 'document_type': 'id_front', 'status': 'pending'},
          {'id': 2, 'document_type': 'proof_of_address', 'status': 'pending'},
        ],
      });
      expect(ks.kycStatus, 'submitted');
      expect(ks.kycVerified, false);
      expect(ks.kycVerifiedAt, isNull);
      expect(ks.kycRequiredForRole, true);
      expect(ks.documents, hasLength(2));
      expect(ks.documents[0].documentType, 'id_front');
      expect(ks.documents[1].documentType, 'proof_of_address');
    });

    test('fromJson handles defaults', () {
      final ks = KycStatus.fromJson({});
      expect(ks.kycStatus, 'not_started');
      expect(ks.kycVerified, false);
      expect(ks.kycRequiredForRole, false);
      expect(ks.documents, isEmpty);
    });

    test('fromJson handles verified state', () {
      final ks = KycStatus.fromJson({
        'kyc_status': 'verified',
        'kyc_verified': true,
        'kyc_verified_at': '2024-02-15T10:30:00Z',
      });
      expect(ks.kycStatus, 'verified');
      expect(ks.kycVerified, true);
      expect(ks.kycVerifiedAt, '2024-02-15T10:30:00Z');
    });
  });

  // ─── KycPendingUser ───

  group('KycPendingUser', () {
    test('fromJson parses all fields', () {
      final u = KycPendingUser.fromJson({
        'user_id': 99,
        'email': 'pending@example.com',
        'display_name': 'Pending User',
        'role': 'organizer',
        'kyc_status': 'submitted',
        'submitted_at': '2024-03-01T08:00:00Z',
        'document_count': 3,
      });
      expect(u.userId, 99);
      expect(u.email, 'pending@example.com');
      expect(u.displayName, 'Pending User');
      expect(u.role, 'organizer');
      expect(u.kycStatus, 'submitted');
      expect(u.submittedAt, '2024-03-01T08:00:00Z');
      expect(u.documentCount, 3);
    });

    test('fromJson handles defaults', () {
      final u = KycPendingUser.fromJson({
        'user_id': 1,
        'email': 'test@test.com',
        'role': 'customer',
        'kyc_status': 'submitted',
      });
      expect(u.displayName, isNull);
      expect(u.submittedAt, isNull);
      expect(u.documentCount, 0);
    });

    test('displayLabel returns displayName when present', () {
      final u = KycPendingUser.fromJson({
        'user_id': 1,
        'email': 'test@test.com',
        'display_name': 'Alice',
        'role': 'organizer',
        'kyc_status': 'submitted',
      });
      expect(u.displayLabel, 'Alice');
    });

    test('displayLabel falls back to email when displayName is null', () {
      final u = KycPendingUser.fromJson({
        'user_id': 1,
        'email': 'bob@example.com',
        'role': 'organizer',
        'kyc_status': 'submitted',
      });
      expect(u.displayLabel, 'bob@example.com');
    });

    test('initial returns first character uppercase', () {
      final u = KycPendingUser.fromJson({
        'user_id': 1,
        'email': 'charlie@example.com',
        'display_name': 'charlie',
        'role': 'organizer',
        'kyc_status': 'submitted',
      });
      expect(u.initial, 'C');
    });

    test('initial from email when no displayName', () {
      final u = KycPendingUser.fromJson({
        'user_id': 1,
        'email': 'delta@example.com',
        'role': 'organizer',
        'kyc_status': 'submitted',
      });
      expect(u.initial, 'D');
    });
  });

  // ─── KycDocumentUpload ───

  group('KycDocumentUpload', () {
    test('fromJson parses all fields', () {
      final json = {
        'document_id': 42,
        'file_url': 'https://storage.example.com/kyc/doc.jpg',
        'status': 'approved',
        'document_type': 'id_front',
      };
      final u = KycDocumentUpload.fromJson(json);

      expect(u.documentId, 42);
      expect(u.fileUrl, 'https://storage.example.com/kyc/doc.jpg');
      expect(u.status, 'approved');
      expect(u.documentType, 'id_front');
    });

    test('fromJson falls back to id key for documentId', () {
      final json = {
        'id': 99,
        'file_url': 'https://storage.example.com/kyc/alt.jpg',
        'status': 'pending',
        'document_type': 'proof_of_address',
      };
      final u = KycDocumentUpload.fromJson(json);
      expect(u.documentId, 99);
    });

    test('all fields nullable', () {
      final u = KycDocumentUpload.fromJson({});
      expect(u.documentId, isNull);
      expect(u.fileUrl, isNull);
      expect(u.status, isNull);
      expect(u.documentType, isNull);
    });
  });
}
