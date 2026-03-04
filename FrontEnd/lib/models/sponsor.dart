import 'event.dart';

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
  final List<SponsorBid> myBids;
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
      myBids: (json['my_bids'] as List?)?.map((e) => SponsorBid.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
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
  final int? bidId;
  final int? paymentId;
  final String? paymentReceiptNumber;
  final String? paymentStatus;
  final String? paymentCreatedAt;

  SponsorTicketCategory({
    required this.name,
    required this.amountCents,
    required this.status,
    this.prerequisites = const [],
    this.bidId,
    this.paymentId,
    this.paymentReceiptNumber,
    this.paymentStatus,
    this.paymentCreatedAt,
  });

  String get amountDisplay =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';

  bool get isRefunded => status == 'refunded';
  bool get isPaid => status == 'paid';

  factory SponsorTicketCategory.fromJson(Map<String, dynamic> json) {
    return SponsorTicketCategory(
      name: json['name'] ?? '',
      amountCents: json['amount_cents'] ?? 0,
      status: json['status'] ?? '',
      prerequisites: (json['prerequisites'] as List<dynamic>?)
              ?.map((p) => SponsorTicketPrereq.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      bidId: json['bid_id'],
      paymentId: json['payment_id'],
      paymentReceiptNumber: json['payment_receipt_number'],
      paymentStatus: json['payment_status'],
      paymentCreatedAt: json['payment_created_at'],
    );
  }
}

class SponsorDelegate {
  final int id;
  final int sponsorTicketId;
  final String name;
  final String? email;
  final String? phone;
  final bool checkedIn;
  final String? checkedInAt;
  final String? createdAt;

  SponsorDelegate({
    required this.id,
    required this.sponsorTicketId,
    required this.name,
    this.email,
    this.phone,
    this.checkedIn = false,
    this.checkedInAt,
    this.createdAt,
  });

  factory SponsorDelegate.fromJson(Map<String, dynamic> json) {
    return SponsorDelegate(
      id: json['id'],
      sponsorTicketId: json['sponsor_ticket_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      checkedIn: json['checked_in'] ?? false,
      checkedInAt: json['checked_in_at'],
      createdAt: json['created_at'],
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

  int get activeTotalCents =>
      categories.where((c) => !c.isRefunded).fold(0, (sum, c) => sum + c.amountCents);

  int get refundedTotalCents =>
      categories.where((c) => c.isRefunded).fold(0, (sum, c) => sum + c.amountCents);

  bool get hasRefunds => categories.any((c) => c.isRefunded);

  String get totalAmountDisplay =>
      '\$${(totalAmountCents / 100).toStringAsFixed(2)}';

  String get activeTotalDisplay =>
      '\$${(activeTotalCents / 100).toStringAsFixed(2)}';

  String get refundedTotalDisplay =>
      '\$${(refundedTotalCents / 100).toStringAsFixed(2)}';

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

class OrganizerSponsorItem {
  final int sponsorUserId;
  final String companyName;
  final String contactName;
  final String? logoUrl;
  final int totalBids;
  final int totalAmountCents;

  OrganizerSponsorItem({
    required this.sponsorUserId,
    required this.companyName,
    required this.contactName,
    this.logoUrl,
    required this.totalBids,
    required this.totalAmountCents,
  });

  factory OrganizerSponsorItem.fromJson(Map<String, dynamic> json) =>
      OrganizerSponsorItem(
        sponsorUserId: json['sponsor_user_id'] as int,
        companyName: (json['company_name'] as String?) ?? '',
        contactName: (json['contact_name'] as String?) ?? '',
        logoUrl: json['logo_url'] as String?,
        totalBids: (json['total_bids'] as int?) ?? 0,
        totalAmountCents: (json['total_amount_cents'] as int?) ?? 0,
      );

  String get totalAmountDisplay =>
      '\$${(totalAmountCents / 100).toStringAsFixed(2)}';
}

class SponsorEventBid {
  final String category;
  final int amountCents;
  final String status;

  SponsorEventBid({
    required this.category,
    required this.amountCents,
    required this.status,
  });

  factory SponsorEventBid.fromJson(Map<String, dynamic> json) =>
      SponsorEventBid(
        category: (json['category'] as String?) ?? '',
        amountCents: (json['amount_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
      );
}

class SponsorEventItem {
  final int eventId;
  final String title;
  final String status;
  final String? startTime;
  final String? venueName;
  final String? venueCity;
  final List<SponsorEventBid> bids;
  final int totalAmountCents;

  SponsorEventItem({
    required this.eventId,
    required this.title,
    required this.status,
    this.startTime,
    this.venueName,
    this.venueCity,
    this.bids = const [],
    required this.totalAmountCents,
  });

  factory SponsorEventItem.fromJson(Map<String, dynamic> json) =>
      SponsorEventItem(
        eventId: json['event_id'] as int,
        title: (json['title'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        startTime: json['start_time'] as String?,
        venueName: json['venue_name'] as String?,
        venueCity: json['venue_city'] as String?,
        bids: (json['bids'] as List?)
                ?.map((e) => SponsorEventBid.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        totalAmountCents: (json['total_amount_cents'] as int?) ?? 0,
      );
}

class SponsorPaymentReceipt {
  final int paymentId;
  final String receiptNumber;
  final String type;
  final int amountCents;
  final int platformCutCents;
  final int netToOrganizerCents;
  final int subtotalCents;
  final int taxCents;
  final double taxRate;
  final String status;
  final String? createdAt;
  final int bidId;
  final int bidAmountCents;
  final String? bidProposal;
  final String? categoryName;
  final int? eventId;
  final String? eventTitle;
  final String? sponsorName;
  final String? sponsorEmail;

  SponsorPaymentReceipt({
    required this.paymentId,
    required this.receiptNumber,
    required this.type,
    required this.amountCents,
    required this.platformCutCents,
    required this.netToOrganizerCents,
    required this.subtotalCents,
    required this.taxCents,
    required this.taxRate,
    required this.status,
    this.createdAt,
    required this.bidId,
    required this.bidAmountCents,
    this.bidProposal,
    this.categoryName,
    this.eventId,
    this.eventTitle,
    this.sponsorName,
    this.sponsorEmail,
  });

  factory SponsorPaymentReceipt.fromJson(Map<String, dynamic> json) =>
      SponsorPaymentReceipt(
        paymentId: json['payment_id'] as int,
        receiptNumber: (json['receipt_number'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'payment',
        amountCents: (json['amount_cents'] as int?) ?? 0,
        platformCutCents: (json['platform_cut_cents'] as int?) ?? 0,
        netToOrganizerCents: (json['net_to_organizer_cents'] as int?) ?? 0,
        subtotalCents: (json['subtotal_cents'] as int?) ?? 0,
        taxCents: (json['tax_cents'] as int?) ?? 0,
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
        status: (json['status'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
        bidId: json['bid_id'] as int,
        bidAmountCents: (json['bid_amount_cents'] as int?) ?? 0,
        bidProposal: json['bid_proposal'] as String?,
        categoryName: json['category_name'] as String?,
        eventId: json['event_id'] as int?,
        eventTitle: json['event_title'] as String?,
        sponsorName: json['sponsor_name'] as String?,
        sponsorEmail: json['sponsor_email'] as String?,
      );

  String get amountDisplay =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';

  String get netDisplay =>
      '\$${(netToOrganizerCents / 100).toStringAsFixed(2)}';
}

class ScannedDelegate {
  final int id;
  final String name;
  final bool checkedIn;
  final String? checkedInAt;

  ScannedDelegate({
    required this.id,
    required this.name,
    this.checkedIn = false,
    this.checkedInAt,
  });

  factory ScannedDelegate.fromJson(Map<String, dynamic> json) =>
      ScannedDelegate(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        checkedIn: (json['checked_in'] as bool?) ?? false,
        checkedInAt: json['checked_in_at'] as String?,
      );
}

class ScannedSponsorTicket {
  final int id;
  final int eventId;
  final String receiptNumber;
  final String companyName;
  final String contactName;
  final int scanCount;
  final String? scannedAt;
  final int totalDelegates;
  final int checkedInCount;
  final List<ScannedDelegate> delegates;

  ScannedSponsorTicket({
    required this.id,
    required this.eventId,
    required this.receiptNumber,
    required this.companyName,
    required this.contactName,
    this.scanCount = 0,
    this.scannedAt,
    this.totalDelegates = 0,
    this.checkedInCount = 0,
    this.delegates = const [],
  });

  factory ScannedSponsorTicket.fromJson(Map<String, dynamic> json) =>
      ScannedSponsorTicket(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        receiptNumber: (json['receipt_number'] as String?) ?? '',
        companyName: (json['company_name'] as String?) ?? '',
        contactName: (json['contact_name'] as String?) ?? '',
        scanCount: (json['scan_count'] as int?) ?? 0,
        scannedAt: json['scanned_at'] as String?,
        totalDelegates: (json['total_delegates'] as int?) ?? 0,
        checkedInCount: (json['checked_in_count'] as int?) ?? 0,
        delegates: (json['delegates'] as List?)
                ?.map((e) => ScannedDelegate.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

class EventSponsor {
  final int sponsorUserId;
  final String companyName;
  final String? logoUrl;
  final String? websiteUrl;

  EventSponsor({
    required this.sponsorUserId,
    required this.companyName,
    this.logoUrl,
    this.websiteUrl,
  });

  factory EventSponsor.fromJson(Map<String, dynamic> json) => EventSponsor(
        sponsorUserId: json['sponsor_user_id'] as int,
        companyName: (json['company_name'] as String?) ?? '',
        logoUrl: json['logo_url'] as String?,
        websiteUrl: json['website_url'] as String?,
      );
}

class CategoryPrerequisite {
  final int id;
  final String name;
  final String? description;
  final bool isRequired;
  final bool requiresDocument;

  CategoryPrerequisite({
    required this.id,
    required this.name,
    this.description,
    this.isRequired = false,
    this.requiresDocument = false,
  });

  factory CategoryPrerequisite.fromJson(Map<String, dynamic> json) =>
      CategoryPrerequisite(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        description: json['description'] as String?,
        isRequired: (json['is_required'] as bool?) ?? false,
        requiresDocument: (json['requires_document'] as bool?) ?? false,
      );
}

class BidPrerequisiteUpload {
  final int id;
  final int bidId;
  final int prerequisiteId;
  final String fileUrl;
  final String status;
  final String? reviewedAt;
  final String? reviewerNote;

  BidPrerequisiteUpload({
    required this.id,
    required this.bidId,
    required this.prerequisiteId,
    required this.fileUrl,
    required this.status,
    this.reviewedAt,
    this.reviewerNote,
  });

  factory BidPrerequisiteUpload.fromJson(Map<String, dynamic> json) =>
      BidPrerequisiteUpload(
        id: json['id'] as int,
        bidId: json['bid_id'] as int,
        prerequisiteId: json['prerequisite_id'] as int,
        fileUrl: (json['file_url'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        reviewedAt: json['reviewed_at'] as String?,
        reviewerNote: json['reviewer_note'] as String?,
      );
}

// ─── Sponsor Category Templates ───

class SponsorCategoryTemplate {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int totalSpots;
  final int minBidCents;
  final int sortOrder;

  SponsorCategoryTemplate({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.totalSpots,
    required this.minBidCents,
    this.sortOrder = 0,
  });

  factory SponsorCategoryTemplate.fromJson(Map<String, dynamic> json) =>
      SponsorCategoryTemplate(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        totalSpots: (json['total_spots'] as int?) ?? 0,
        minBidCents: (json['min_bid_cents'] as int?) ?? 0,
        sortOrder: (json['sort_order'] as int?) ?? 0,
      );
}

class TemplatePrerequisite {
  final int id;
  final String name;
  final String? description;
  final bool isRequired;
  final bool requiresDocument;

  TemplatePrerequisite({
    required this.id,
    required this.name,
    this.description,
    this.isRequired = false,
    this.requiresDocument = false,
  });

  factory TemplatePrerequisite.fromJson(Map<String, dynamic> json) =>
      TemplatePrerequisite(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        description: json['description'] as String?,
        isRequired: (json['is_required'] as bool?) ?? false,
        requiresDocument: (json['requires_document'] as bool?) ?? false,
      );
}

// ─── Upload Results ───

class FileUploadResult {
  final int? id;
  final String fileUrl;
  final String? status;

  FileUploadResult({this.id, required this.fileUrl, this.status});

  factory FileUploadResult.fromJson(Map<String, dynamic> json) =>
      FileUploadResult(
        id: json['id'] as int?,
        fileUrl: ((json['file_url'] ?? json['url']) as String?) ?? '',
        status: json['status'] as String?,
      );
}

class ChatImageUpload {
  final String url;
  final String? fileName;

  ChatImageUpload({required this.url, this.fileName});

  factory ChatImageUpload.fromJson(Map<String, dynamic> json) =>
      ChatImageUpload(
        url: (json['url'] as String?) ?? '',
        fileName: json['file_name'] as String?,
      );
}

// ─── Sponsor Bid Event (aggregated view) ───

class SponsorBidEvent {
  final Event event;
  final int pending;
  final int accepted;
  final int rejected;
  final int paid;

  SponsorBidEvent({
    required this.event,
    this.pending = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.paid = 0,
  });

  int get totalBids => pending + accepted + rejected + paid;

  factory SponsorBidEvent.fromJson(Map<String, dynamic> json) {
    final summary =
        (json['bid_summary'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SponsorBidEvent(
      event: Event.fromJson(json),
      pending: (summary['pending'] as int?) ?? 0,
      accepted: (summary['accepted'] as int?) ?? 0,
      rejected: (summary['rejected'] as int?) ?? 0,
      paid: (summary['paid'] as int?) ?? 0,
    );
  }
}

// ─── Typed Request Classes ───

/// Request body for creating or updating a sponsor profile.
class SponsorProfileRequest {
  final String companyName;
  final String contactName;
  final String profession;
  final String? logoUrl;
  final String? description;
  final String? websiteUrl;

  const SponsorProfileRequest({
    required this.companyName,
    required this.contactName,
    required this.profession,
    this.logoUrl,
    this.description,
    this.websiteUrl,
  });

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'contact_name': contactName,
        'profession': profession,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (description != null) 'description': description,
        if (websiteUrl != null) 'website_url': websiteUrl,
      };
}

/// Request body for creating a sponsorship category.
class CreateSponsorshipCategoryRequest {
  final String name;
  final String? description;
  final int totalSpots;
  final int minBidCents;
  final int? sortOrder;

  const CreateSponsorshipCategoryRequest({
    required this.name,
    this.description,
    required this.totalSpots,
    required this.minBidCents,
    this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'total_spots': totalSpots,
        'min_bid_cents': minBidCents,
        if (sortOrder != null) 'sort_order': sortOrder,
      };
}

/// Request body for updating an existing sponsorship category.
class UpdateSponsorshipCategoryRequest {
  final String name;
  final String? description;
  final int totalSpots;
  final int minBidCents;

  const UpdateSponsorshipCategoryRequest({
    required this.name,
    this.description,
    required this.totalSpots,
    required this.minBidCents,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'total_spots': totalSpots,
        'min_bid_cents': minBidCents,
      };
}

/// Request body for placing a sponsor bid.
class PlaceBidRequest {
  final int amountCents;
  final String? proposalText;

  const PlaceBidRequest({
    required this.amountCents,
    this.proposalText,
  });

  Map<String, dynamic> toJson() => {
        'amount_cents': amountCents,
        if (proposalText != null) 'proposal_text': proposalText,
      };
}

/// Request body for updating an existing sponsor bid.
class UpdateBidRequest {
  final int? amountCents;
  final String? proposalText;

  const UpdateBidRequest({
    this.amountCents,
    this.proposalText,
  });

  Map<String, dynamic> toJson() => {
        if (amountCents != null) 'amount_cents': amountCents,
        if (proposalText != null) 'proposal_text': proposalText,
      };
}

/// Request body for creating a sponsor category template.
class CreateSponsorCategoryTemplateRequest {
  final String name;
  final String? description;
  final int totalSpots;
  final int minBidCents;

  const CreateSponsorCategoryTemplateRequest({
    required this.name,
    this.description,
    required this.totalSpots,
    required this.minBidCents,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'total_spots': totalSpots,
        'min_bid_cents': minBidCents,
      };
}

/// Request body for updating a sponsor category template.
class UpdateSponsorCategoryTemplateRequest {
  final String name;
  final String? description;
  final int totalSpots;
  final int minBidCents;

  const UpdateSponsorCategoryTemplateRequest({
    required this.name,
    this.description,
    required this.totalSpots,
    required this.minBidCents,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'total_spots': totalSpots,
        'min_bid_cents': minBidCents,
      };
}
