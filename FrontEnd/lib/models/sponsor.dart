class SponsorProfile {
  final int id;
  final int userId;
  final String companyName;
  final String contactName;
  final String profession;
  final String? logoUrl;
  final String? description;
  final String? websiteUrl;

  SponsorProfile({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.contactName,
    required this.profession,
    this.logoUrl,
    this.description,
    this.websiteUrl,
  });

  factory SponsorProfile.fromJson(Map<String, dynamic> json) {
    return SponsorProfile(
      id: json['id'],
      userId: json['user_id'],
      companyName: json['company_name'] ?? '',
      contactName: json['contact_name'] ?? '',
      profession: json['profession'] ?? '',
      logoUrl: json['logo_url'],
      description: json['description'],
      websiteUrl: json['website_url'],
    );
  }
}


class SponsorshipCategory {
  final int id;
  final int eventId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int totalSpots;
  final int filledSpots;
  final int minBidCents;
  final int sortOrder;
  final int bidCount;
  final List<int> bidAmounts;
  final int myBidCount;
  final List<Map<String, dynamic>> myBids;
  final int prereqCount;

  SponsorshipCategory({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.totalSpots,
    this.filledSpots = 0,
    required this.minBidCents,
    this.sortOrder = 0,
    this.bidCount = 0,
    this.bidAmounts = const [],
    this.myBidCount = 0,
    this.myBids = const [],
    this.prereqCount = 0,
  });

  factory SponsorshipCategory.fromJson(Map<String, dynamic> json) {
    return SponsorshipCategory(
      id: json['id'],
      eventId: json['event_id'],
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      totalSpots: json['total_spots'] ?? 0,
      filledSpots: json['filled_spots'] ?? 0,
      minBidCents: json['min_bid_cents'] ?? 0,
      sortOrder: json['sort_order'] ?? 0,
      bidCount: json['bid_count'] ?? 0,
      bidAmounts: (json['bid_amounts'] as List?)?.map((e) => e as int).toList() ?? [],
      myBidCount: json['my_bid_count'] ?? 0,
      myBids: (json['my_bids'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      prereqCount: json['prereq_count'] ?? 0,
    );
  }

  int get availableSpots => totalSpots - filledSpots;
  bool get canPlaceMoreBids => myBidCount < totalSpots && availableSpots > 0;
  String get minBidDisplay => '\$${(minBidCents / 100).toStringAsFixed(2)}';
}


class SponsorBid {
  final int id;
  final int categoryId;
  final int sponsorUserId;
  final int amountCents;
  final String? proposalText;
  final String status;
  final SponsorProfile? sponsorProfile;

  SponsorBid({
    required this.id,
    required this.categoryId,
    required this.sponsorUserId,
    required this.amountCents,
    this.proposalText,
    required this.status,
    this.sponsorProfile,
  });

  factory SponsorBid.fromJson(Map<String, dynamic> json) {
    return SponsorBid(
      id: json['id'],
      categoryId: json['category_id'],
      sponsorUserId: json['sponsor_user_id'],
      amountCents: json['amount_cents'] ?? 0,
      proposalText: json['proposal_text'],
      status: json['status'] ?? 'pending',
      sponsorProfile: json['sponsor_profile'] != null
          ? SponsorProfile.fromJson(json['sponsor_profile'])
          : null,
    );
  }

  String get amountDisplay => '\$${(amountCents / 100).toStringAsFixed(2)}';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isPaid => status == 'paid';
}


class SponsorPayment {
  final int id;
  final int bidId;
  final int amountCents;
  final int platformCutCents;
  final int netToOrganizerCents;
  final String receiptNumber;
  final String status;

  SponsorPayment({
    required this.id,
    required this.bidId,
    required this.amountCents,
    required this.platformCutCents,
    required this.netToOrganizerCents,
    required this.receiptNumber,
    required this.status,
  });

  factory SponsorPayment.fromJson(Map<String, dynamic> json) {
    return SponsorPayment(
      id: json['id'],
      bidId: json['bid_id'],
      amountCents: json['amount_cents'] ?? 0,
      platformCutCents: json['platform_cut_cents'] ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] ?? 0,
      receiptNumber: json['receipt_number'] ?? '',
      status: json['status'] ?? 'completed',
    );
  }
}


class SponsorTicketPrereq {
  final int id;
  final String name;
  final bool isRequired;
  final String? uploadStatus;

  SponsorTicketPrereq({
    required this.id,
    required this.name,
    required this.isRequired,
    this.uploadStatus,
  });

  bool get isUploaded => uploadStatus != null;

  factory SponsorTicketPrereq.fromJson(Map<String, dynamic> json) {
    return SponsorTicketPrereq(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isRequired: json['is_required'] ?? false,
      uploadStatus: json['upload_status'],
    );
  }
}

class SponsorTicketCategory {
  final String name;
  final int amountCents;
  final String status;
  final List<SponsorTicketPrereq> prerequisites;

  SponsorTicketCategory({
    required this.name,
    required this.amountCents,
    required this.status,
    this.prerequisites = const [],
  });

  String get amountDisplay =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';

  factory SponsorTicketCategory.fromJson(Map<String, dynamic> json) {
    return SponsorTicketCategory(
      name: json['name'] ?? '',
      amountCents: json['amount_cents'] ?? 0,
      status: json['status'] ?? '',
      prerequisites: (json['prerequisites'] as List<dynamic>?)
              ?.map((p) => SponsorTicketPrereq.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SponsorTicketModel {
  final int id;
  final int eventId;
  final int sponsorUserId;
  final String receiptNumber;
  final String? encryptedQrPayload;
  final String? scannedAt;
  final String? createdAt;
  final List<SponsorTicketCategory> categories;
  final List<String> categoryNames;
  final int categoryCount;
  final String? eventTitle;
  final String? eventStatus;
  final String? eventStartTime;
  final String? venueName;
  final String? venueAddress;
  final String? venueCity;
  final int scanCount;

  SponsorTicketModel({
    required this.id,
    required this.eventId,
    required this.sponsorUserId,
    required this.receiptNumber,
    this.encryptedQrPayload,
    this.scannedAt,
    this.createdAt,
    this.categories = const [],
    this.categoryNames = const [],
    this.categoryCount = 0,
    this.eventTitle,
    this.eventStatus,
    this.eventStartTime,
    this.venueName,
    this.venueAddress,
    this.venueCity,
    this.scanCount = 0,
  });

  int get totalAmountCents =>
      categories.fold(0, (sum, c) => sum + c.amountCents);

  String get totalAmountDisplay =>
      '\$${(totalAmountCents / 100).toStringAsFixed(2)}';

  factory SponsorTicketModel.fromJson(Map<String, dynamic> json) {
    return SponsorTicketModel(
      id: json['id'],
      eventId: json['event_id'],
      sponsorUserId: json['sponsor_user_id'],
      receiptNumber: json['receipt_number'] ?? '',
      encryptedQrPayload: json['encrypted_qr_payload'],
      scannedAt: json['scanned_at'],
      createdAt: json['created_at'],
      categories: (json['categories'] as List?)
              ?.map((e) => SponsorTicketCategory.fromJson(e))
              .toList() ??
          [],
      categoryNames: (json['category_names'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      categoryCount: json['category_count'] ?? 0,
      eventTitle: json['event_title'],
      eventStatus: json['event_status'],
      eventStartTime: json['event_start_time'],
      venueName: json['venue_name'],
      venueAddress: json['venue_address'],
      venueCity: json['venue_city'],
      scanCount: json['scan_count'] ?? 0,
    );
  }
}
