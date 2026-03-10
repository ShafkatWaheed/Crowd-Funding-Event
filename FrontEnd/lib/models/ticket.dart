// ─── Ticket Strategy Request Models ───

class CreateTicketStrategyTierInput {
  final String name;
  final String? description;
  final int priceCents;
  final int displayOrder;

  const CreateTicketStrategyTierInput({
    required this.name,
    this.description,
    required this.priceCents,
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price_cents': priceCents,
        'display_order': displayOrder,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

class CreateTicketStrategyRequest {
  final String name;
  final List<CreateTicketStrategyTierInput> tiers;

  const CreateTicketStrategyRequest({
    required this.name,
    required this.tiers,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'tiers': tiers.map((t) => t.toJson()).toList(),
      };
}

class UpdateTicketStrategyRequest {
  final String? name;
  final List<CreateTicketStrategyTierInput>? tiers;

  const UpdateTicketStrategyRequest({this.name, this.tiers});

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (tiers != null) 'tiers': tiers!.map((t) => t.toJson()).toList(),
      };
}

// ─── Ticket Tier Request Models ───

class CreateTicketTierRequest {
  final String name;
  final int priceCents;
  final int displayOrder;
  final String? description;
  final int? maxReservedSpots;
  final bool isFeatured;

  const CreateTicketTierRequest({
    required this.name,
    required this.priceCents,
    this.displayOrder = 0,
    this.description,
    this.maxReservedSpots,
    this.isFeatured = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price_cents': priceCents,
        'display_order': displayOrder,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (maxReservedSpots != null && maxReservedSpots! > 0) 'max_reserved_spots': maxReservedSpots,
        'is_featured': isFeatured,
      };
}

class UpdateTicketTierRequest {
  final String? name;
  final int? priceCents;
  final String? description;
  final int? maxReservedSpots;
  final bool? isFeatured;

  const UpdateTicketTierRequest({
    this.name,
    this.priceCents,
    this.description,
    this.maxReservedSpots,
    this.isFeatured,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (priceCents != null) 'price_cents': priceCents,
        if (description != null) 'description': description,
        if (maxReservedSpots != null) 'max_reserved_spots': maxReservedSpots,
        if (isFeatured != null) 'is_featured': isFeatured,
      };
}

class TicketTier {
  final int id;
  final int eventId;
  final String name;
  final String? description;
  final int priceCents;
  final int maxReservedSpots;
  final int ticketsSold;
  final int spotsReserved;
  final int displayOrder;
  final bool fromStrategy;
  final bool isFeatured;

  TicketTier({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.priceCents,
    this.maxReservedSpots = 0,
    this.ticketsSold = 0,
    this.spotsReserved = 0,
    required this.displayOrder,
    this.fromStrategy = false,
    this.isFeatured = false,
  });

  factory TicketTier.fromJson(Map<String, dynamic> json) {
    return TicketTier(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventId: (json['event_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      priceCents: (json['price_cents'] as num?)?.toInt() ?? 0,
      maxReservedSpots: json['max_reserved_spots'] ?? 0,
      ticketsSold: json['tickets_sold'] ?? 0,
      spotsReserved: json['spots_reserved'] ?? 0,
      displayOrder: json['display_order'] ?? 0,
      fromStrategy: json['from_strategy'] ?? false,
      isFeatured: json['is_featured'] ?? false,
    );
  }

  bool get isFree => priceCents == 0;
  String get priceFormatted => isFree ? 'FREE' : '\$${(priceCents / 100).toStringAsFixed(2)}';

  int get spotsLeft => maxReservedSpots > 0
      ? (maxReservedSpots - ticketsSold - spotsReserved)
      : 0;
}

class TicketSale {
  final int id;
  final int eventId;
  final int userId;
  final int ticketTierId;
  final String? purchaseGroupId;
  final String ticketCode;
  final String? receiptNumber;
  final String? tierName;
  final String? eventTitle;
  final String? eventStatus;
  final String? attendeeDisplayName;
  final String? scannedByDisplayName;
  final int amountPaidCents;
  final int discountAppliedCents;
  final int commissionCents;
  final int netToOrganizerCents;
  final String? extraPerks;
  final String status;
  final DateTime? scannedAt;
  final String? encryptedQrPayload;
  final DateTime createdAt;

  TicketSale({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.ticketTierId,
    this.purchaseGroupId,
    required this.ticketCode,
    this.receiptNumber,
    this.tierName,
    this.eventTitle,
    this.eventStatus,
    this.attendeeDisplayName,
    this.scannedByDisplayName,
    required this.amountPaidCents,
    required this.discountAppliedCents,
    this.commissionCents = 0,
    this.netToOrganizerCents = 0,
    this.extraPerks,
    required this.status,
    this.scannedAt,
    this.encryptedQrPayload,
    required this.createdAt,
  });

  factory TicketSale.fromJson(Map<String, dynamic> json) {
    return TicketSale(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventId: (json['event_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      ticketTierId: (json['ticket_tier_id'] as num?)?.toInt() ?? 0,
      purchaseGroupId: json['purchase_group_id'] as String?,
      ticketCode: json['ticket_code'] as String? ?? '',
      receiptNumber: json['receipt_number'] as String?,
      tierName: json['tier_name'] as String?,
      eventTitle: json['event_title'] as String?,
      eventStatus: json['event_status'] as String?,
      attendeeDisplayName: json['attendee_display_name'] as String?,
      scannedByDisplayName: json['scanned_by_display_name'] as String?,
      amountPaidCents: (json['amount_paid_cents'] as num?)?.toInt() ?? 0,
      discountAppliedCents: json['discount_applied_cents'] ?? 0,
      commissionCents: json['commission_cents'] ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] ?? 0,
      extraPerks: json['extra_perks'] as String?,
      status: json['status'] as String? ?? '',
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'])
          : null,
      encryptedQrPayload: json['encrypted_qr_payload'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'user_id': userId,
        'ticket_tier_id': ticketTierId,
        if (purchaseGroupId != null) 'purchase_group_id': purchaseGroupId,
        'ticket_code': ticketCode,
        if (receiptNumber != null) 'receipt_number': receiptNumber,
        if (tierName != null) 'tier_name': tierName,
        if (eventTitle != null) 'event_title': eventTitle,
        if (eventStatus != null) 'event_status': eventStatus,
        if (attendeeDisplayName != null) 'attendee_display_name': attendeeDisplayName,
        if (scannedByDisplayName != null) 'scanned_by_display_name': scannedByDisplayName,
        'amount_paid_cents': amountPaidCents,
        'discount_applied_cents': discountAppliedCents,
        'commission_cents': commissionCents,
        'net_to_organizer_cents': netToOrganizerCents,
        if (extraPerks != null) 'extra_perks': extraPerks,
        'status': status,
        if (scannedAt != null) 'scanned_at': scannedAt!.toIso8601String(),
        if (encryptedQrPayload != null) 'encrypted_qr_payload': encryptedQrPayload,
        'created_at': createdAt.toIso8601String(),
      };

  String get amountPaidFormatted =>
      '\$${(amountPaidCents / 100).toStringAsFixed(2)}';

  bool get isScanned => scannedAt != null;
}

class TicketPricePreview {
  final int tierPriceCents;
  final int commonDiscountCents;
  final int selectiveDiscountCents;
  final int pledgeDiscountCents;
  final int eventDiscountCents;
  final int milestoneDiscountCents;
  final int earlyBirdDiscountCents;
  final int totalDiscountCents;
  final int finalPriceCents;
  final int commissionCents;
  final int netToOrganizerCents;
  final int ticketCommissionPercent;
  final bool discountCapped;
  final int maxDiscountPercent;

  TicketPricePreview({
    required this.tierPriceCents,
    this.commonDiscountCents = 0,
    this.selectiveDiscountCents = 0,
    this.pledgeDiscountCents = 0,
    this.eventDiscountCents = 0,
    this.milestoneDiscountCents = 0,
    this.earlyBirdDiscountCents = 0,
    this.totalDiscountCents = 0,
    required this.finalPriceCents,
    this.commissionCents = 0,
    this.netToOrganizerCents = 0,
    this.ticketCommissionPercent = 0,
    this.discountCapped = false,
    this.maxDiscountPercent = 100,
  });

  factory TicketPricePreview.fromJson(Map<String, dynamic> json) {
    return TicketPricePreview(
      tierPriceCents: json['tier_price_cents'] as int? ?? 0,
      commonDiscountCents: json['common_discount_cents'] as int? ?? 0,
      selectiveDiscountCents: json['selective_discount_cents'] as int? ?? 0,
      pledgeDiscountCents: json['pledge_discount_cents'] as int? ?? 0,
      eventDiscountCents: json['event_discount_cents'] as int? ?? 0,
      milestoneDiscountCents: json['milestone_discount_cents'] as int? ?? 0,
      earlyBirdDiscountCents: json['early_bird_discount_cents'] as int? ?? 0,
      totalDiscountCents: json['total_discount_cents'] as int? ?? 0,
      finalPriceCents: json['final_price_cents'] as int? ?? 0,
      commissionCents: json['commission_cents'] as int? ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] as int? ?? 0,
      ticketCommissionPercent: json['ticket_commission_percent'] as int? ?? 0,
      discountCapped: json['discount_capped'] as bool? ?? false,
      maxDiscountPercent: json['max_discount_percent'] as int? ?? 100,
    );
  }

  String get finalPriceFormatted =>
      '\$${(finalPriceCents / 100).toStringAsFixed(2)}';
}

class TicketSalesStats {
  final int totalSold;
  final int totalScanned;

  TicketSalesStats({
    required this.totalSold,
    required this.totalScanned,
  });

  factory TicketSalesStats.fromJson(Map<String, dynamic> json) {
    return TicketSalesStats(
      totalSold: json['total_sold'] as int? ?? 0,
      totalScanned: json['total_scanned'] as int? ?? 0,
    );
  }
}

class TicketScanResult {
  final bool alreadyScanned;
  final TicketSale ticket;

  TicketScanResult({
    required this.alreadyScanned,
    required this.ticket,
  });

  factory TicketScanResult.fromJson(Map<String, dynamic> json) {
    return TicketScanResult(
      alreadyScanned: json['already_scanned'] as bool? ?? false,
      ticket: TicketSale.fromJson(json['ticket'] as Map<String, dynamic>),
    );
  }
}
