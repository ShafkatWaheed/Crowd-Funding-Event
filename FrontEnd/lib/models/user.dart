enum UserRole { admin, organizer, customer, sponsor }

class AppUser {
  final int id;
  final String email;
  final String? displayName;
  final String? phone;
  final UserRole role;
  final String? address;
  final String? birthday;
  final int? yearsOfExperience;
  final String kycStatus;
  final bool kycVerified;
  final String? kycVerifiedAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    required this.role,
    this.address,
    this.birthday,
    this.yearsOfExperience,
    this.kycStatus = 'not_started',
    this.kycVerified = false,
    this.kycVerifiedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'] ?? '',
      displayName: json['display_name'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.customer,
      ),
      address: json['address'],
      birthday: json['birthday'],
      yearsOfExperience: json['years_of_experience'],
      kycStatus: json['kyc_status'] ?? 'not_started',
      kycVerified: json['kyc_verified'] ?? false,
      kycVerifiedAt: json['kyc_verified_at'],
    );
  }

  /// Preferred display: name if available, otherwise generic fallback.
  String get displayLabel => displayName ?? 'User';

  /// First initial for avatar.
  String get initial => displayLabel.substring(0, 1).toUpperCase();

  /// Mask email: show first 2 chars + *** + @domain
  String get maskedEmail {
    if (email.isEmpty) return '?';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    final visible = local.length >= 2 ? local.substring(0, 2) : local;
    return '$visible***@$domain';
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isOrganizer => role == UserRole.organizer;
  bool get isCustomer => role == UserRole.customer;
  bool get isSponsor => role == UserRole.sponsor;
}

// ─── Payment Info ───

class PaymentInfo {
  final String? mode;
  final String? cardHolderName;
  final String? cardLastFour;
  final String? cardBrand;
  final String? billingAddress;
  final bool hasPaymentMethod;
  final String? stripeCustomerId;
  final bool? stripeConfigured;

  PaymentInfo({
    this.mode,
    this.cardHolderName,
    this.cardLastFour,
    this.cardBrand,
    this.billingAddress,
    this.hasPaymentMethod = false,
    this.stripeCustomerId,
    this.stripeConfigured,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
        mode: json['mode'] as String?,
        cardHolderName: json['card_holder_name'] as String?,
        cardLastFour: json['card_last_four'] as String?,
        cardBrand: json['card_brand'] as String?,
        billingAddress: json['billing_address'] as String?,
        hasPaymentMethod: (json['has_payment_method'] as bool?) ?? false,
        stripeCustomerId: json['stripe_customer_id'] as String?,
        stripeConfigured: json['stripe_configured'] as bool?,
      );
}

// ─── Bank Account ───

class BankAccount {
  final String? mode;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountLastFour;
  final String? accountHolderMasked;
  final bool verified;
  final String verificationStatus;
  final String? rejectionReason;
  final String payoutSchedule;
  final int payoutDay;
  final int minPayoutCents;
  final bool hasBankAccount;
  final bool decryptionFailed;
  final String? stripeConnectAccountId;
  final bool? stripeConnected;

  BankAccount({
    this.mode,
    this.institutionNumber,
    this.transitNumber,
    this.accountLastFour,
    this.accountHolderMasked,
    this.verified = false,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.payoutSchedule = 'weekly',
    this.payoutDay = 1,
    this.minPayoutCents = 2500,
    this.hasBankAccount = false,
    this.decryptionFailed = false,
    this.stripeConnectAccountId,
    this.stripeConnected,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        mode: json['mode'] as String?,
        institutionNumber: json['institution_number'] as String?,
        transitNumber: json['transit_number'] as String?,
        accountLastFour: json['account_last_four'] as String?,
        accountHolderMasked: json['account_holder_masked'] as String?,
        verified: (json['verified'] as bool?) ?? false,
        verificationStatus:
            (json['verification_status'] as String?) ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        payoutSchedule: (json['payout_schedule'] as String?) ?? 'weekly',
        payoutDay: (json['payout_day'] as int?) ?? 1,
        minPayoutCents: (json['min_payout_cents'] as int?) ?? 2500,
        hasBankAccount: (json['has_bank_account'] as bool?) ?? false,
        decryptionFailed: (json['decryption_failed'] as bool?) ?? false,
        stripeConnectAccountId:
            json['stripe_connect_account_id'] as String?,
        stripeConnected: json['stripe_connected'] as bool?,
      );
}

// ─── Public Profile ───

class TrustInfo {
  final double trustScore;
  final String label;
  final int completedEvents;
  final int publishedEvents;

  TrustInfo({
    required this.trustScore,
    required this.label,
    required this.completedEvents,
    required this.publishedEvents,
  });

  factory TrustInfo.fromJson(Map<String, dynamic> json) => TrustInfo(
        trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.0,
        label: (json['label'] as String?) ?? 'New',
        completedEvents: (json['completed_events'] as int?) ?? 0,
        publishedEvents: (json['published_events'] as int?) ?? 0,
      );
}

class PublicSponsorInfo {
  final int? id;
  final String? companyName;
  final String? contactName;
  final String? profession;
  final String? logoUrl;
  final String? description;
  final String? websiteUrl;

  PublicSponsorInfo({
    this.id,
    this.companyName,
    this.contactName,
    this.profession,
    this.logoUrl,
    this.description,
    this.websiteUrl,
  });

  factory PublicSponsorInfo.fromJson(Map<String, dynamic> json) =>
      PublicSponsorInfo(
        id: json['id'] as int?,
        companyName: json['company_name'] as String?,
        contactName: json['contact_name'] as String?,
        profession: json['profession'] as String?,
        logoUrl: json['logo_url'] as String?,
        description: json['description'] as String?,
        websiteUrl: json['website_url'] as String?,
      );
}

class EventMetrics {
  final int completed;
  final int cancelled;
  final int live;
  final int approved;
  final int sellingTickets;
  final int total;

  EventMetrics({
    this.completed = 0,
    this.cancelled = 0,
    this.live = 0,
    this.approved = 0,
    this.sellingTickets = 0,
    this.total = 0,
  });

  factory EventMetrics.fromJson(Map<String, dynamic> json) => EventMetrics(
        completed: (json['completed'] as int?) ?? 0,
        cancelled: (json['cancelled'] as int?) ?? 0,
        live: (json['live'] as int?) ?? 0,
        approved: (json['approved'] as int?) ?? 0,
        sellingTickets: (json['selling_tickets'] as int?) ?? 0,
        total: (json['total'] as int?) ?? 0,
      );
}

class PublicProfile {
  final int id;
  final String? displayName;
  final String role;
  final String? address;
  final int? yearsOfExperience;
  final String? createdAt;
  final TrustInfo? trust;
  final PublicSponsorInfo? sponsorProfile;
  final EventMetrics? eventMetrics;

  PublicProfile({
    required this.id,
    this.displayName,
    required this.role,
    this.address,
    this.yearsOfExperience,
    this.createdAt,
    this.trust,
    this.sponsorProfile,
    this.eventMetrics,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: json['id'] as int,
        displayName: json['display_name'] as String?,
        role: (json['role'] as String?) ?? '',
        address: json['address'] as String?,
        yearsOfExperience: json['years_of_experience'] as int?,
        createdAt: json['created_at'] as String?,
        trust: json['trust'] != null
            ? TrustInfo.fromJson(
                Map<String, dynamic>.from(json['trust'] as Map))
            : null,
        sponsorProfile: json['sponsor_profile'] != null
            ? PublicSponsorInfo.fromJson(
                Map<String, dynamic>.from(json['sponsor_profile'] as Map))
            : null,
        eventMetrics: json['event_metrics'] != null
            ? EventMetrics.fromJson(
                Map<String, dynamic>.from(json['event_metrics'] as Map))
            : null,
      );
}

// ─── Sponsor Public Profile ───

class SponsorPublicProfile {
  final int id;
  final String? displayName;
  final String? companyName;
  final String? contactName;
  final String? profession;
  final String? logoUrl;
  final String? description;
  final String? websiteUrl;
  final String? memberSince;
  final int totalBids;
  final int acceptedBids;
  final int eventsSponsored;

  SponsorPublicProfile({
    required this.id,
    this.displayName,
    this.companyName,
    this.contactName,
    this.profession,
    this.logoUrl,
    this.description,
    this.websiteUrl,
    this.memberSince,
    this.totalBids = 0,
    this.acceptedBids = 0,
    this.eventsSponsored = 0,
  });

  factory SponsorPublicProfile.fromJson(Map<String, dynamic> json) =>
      SponsorPublicProfile(
        id: json['id'] as int,
        displayName: json['display_name'] as String?,
        companyName: json['company_name'] as String?,
        contactName: json['contact_name'] as String?,
        profession: json['profession'] as String?,
        logoUrl: json['logo_url'] as String?,
        description: json['description'] as String?,
        websiteUrl: json['website_url'] as String?,
        memberSince: json['member_since'] as String?,
        totalBids: (json['total_bids'] as int?) ?? 0,
        acceptedBids: (json['accepted_bids'] as int?) ?? 0,
        eventsSponsored: (json['events_sponsored'] as int?) ?? 0,
      );
}

// ─── KYC ───

class KycDocument {
  final int id;
  final String documentType;
  final String? fileUrl;
  final String? mimeType;
  final String? originalFilename;
  final String status;
  final String? rejectionReason;
  final String? submittedAt;

  KycDocument({
    required this.id,
    required this.documentType,
    this.fileUrl,
    this.mimeType,
    this.originalFilename,
    this.status = 'pending',
    this.rejectionReason,
    this.submittedAt,
  });

  factory KycDocument.fromJson(Map<String, dynamic> json) => KycDocument(
        id: json['id'] as int,
        documentType: (json['document_type'] as String?) ?? '',
        fileUrl: json['file_url'] as String?,
        mimeType: json['mime_type'] as String?,
        originalFilename: json['original_filename'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        submittedAt: json['submitted_at'] as String?,
      );
}

class KycStatus {
  final String kycStatus;
  final bool kycVerified;
  final String? kycVerifiedAt;
  final bool kycRequiredForRole;
  final List<KycDocument> documents;

  KycStatus({
    required this.kycStatus,
    this.kycVerified = false,
    this.kycVerifiedAt,
    this.kycRequiredForRole = false,
    this.documents = const [],
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) => KycStatus(
        kycStatus: (json['kyc_status'] as String?) ?? 'not_started',
        kycVerified: (json['kyc_verified'] as bool?) ?? false,
        kycVerifiedAt: json['kyc_verified_at'] as String?,
        kycRequiredForRole: (json['kyc_required_for_role'] as bool?) ?? false,
        documents: (json['documents'] as List?)
                ?.map((e) =>
                    KycDocument.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

class KycPendingUser {
  final int userId;
  final String email;
  final String? displayName;
  final String role;
  final String kycStatus;
  final String? submittedAt;
  final int documentCount;

  KycPendingUser({
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    required this.kycStatus,
    this.submittedAt,
    this.documentCount = 0,
  });

  factory KycPendingUser.fromJson(Map<String, dynamic> json) =>
      KycPendingUser(
        userId: json['user_id'] as int,
        email: (json['email'] as String?) ?? '',
        displayName: json['display_name'] as String?,
        role: (json['role'] as String?) ?? '',
        kycStatus: (json['kyc_status'] as String?) ?? '',
        submittedAt: json['submitted_at'] as String?,
        documentCount: (json['document_count'] as int?) ?? 0,
      );

  String get displayLabel => displayName ?? email;
  String get initial => displayLabel.substring(0, 1).toUpperCase();
}

// ─── KYC Document Upload Result ───

class KycDocumentUpload {
  final int? documentId;
  final String? fileUrl;
  final String? status;
  final String? documentType;

  KycDocumentUpload({this.documentId, this.fileUrl, this.status, this.documentType});

  factory KycDocumentUpload.fromJson(Map<String, dynamic> json) =>
      KycDocumentUpload(
        documentId: (json['document_id'] ?? json['id']) as int?,
        fileUrl: json['file_url'] as String?,
        status: json['status'] as String?,
        documentType: json['document_type'] as String?,
      );
}

class KycSubmitResult {
  final String kycStatus;
  final String? message;

  KycSubmitResult({required this.kycStatus, this.message});

  factory KycSubmitResult.fromJson(Map<String, dynamic> json) =>
      KycSubmitResult(
        kycStatus: (json['kyc_status'] as String?) ?? '',
        message: json['message'] as String?,
      );
}

class KycVerifyResult {
  final int userId;
  final String kycStatus;

  KycVerifyResult({required this.userId, required this.kycStatus});

  factory KycVerifyResult.fromJson(Map<String, dynamic> json) =>
      KycVerifyResult(
        userId: json['user_id'] as int,
        kycStatus: (json['kyc_status'] as String?) ?? '',
      );
}
