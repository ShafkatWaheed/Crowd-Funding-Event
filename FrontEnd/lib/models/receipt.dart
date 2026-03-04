// Receipt models for tickets and pledges.

class TicketReceipt {
  final int saleId;
  final int userId;
  final String receiptNumber;
  final String ticketCode;
  final String status;
  final String? attendeeName;
  final int eventId;
  final String eventTitle;
  final DateTime? eventStartTime;
  final DateTime? eventEndTime;
  final String? organizerName;
  final String? organizerEmail;
  final String? organizerPhone;
  final String? venueName;
  final String? venueAddress;
  final String tierName;
  final int tierPriceCents;
  final int amountPaidCents;
  final int discountAppliedCents;
  final int commissionCents;
  final int netToOrganizerCents;
  final int subtotalCents;
  final int taxCents;
  final double taxRate;
  final String? taxJurisdiction;
  final String? extraPerks;
  final String? encryptedQrPayload;
  final DateTime purchasedAt;
  final DateTime? scannedAt;

  TicketReceipt({
    required this.saleId,
    required this.userId,
    required this.receiptNumber,
    required this.ticketCode,
    required this.status,
    this.attendeeName,
    required this.eventId,
    required this.eventTitle,
    this.eventStartTime,
    this.eventEndTime,
    this.organizerName,
    this.organizerEmail,
    this.organizerPhone,
    this.venueName,
    this.venueAddress,
    required this.tierName,
    required this.tierPriceCents,
    required this.amountPaidCents,
    required this.discountAppliedCents,
    this.commissionCents = 0,
    this.netToOrganizerCents = 0,
    this.subtotalCents = 0,
    this.taxCents = 0,
    this.taxRate = 0.0,
    this.taxJurisdiction,
    this.extraPerks,
    this.encryptedQrPayload,
    required this.purchasedAt,
    this.scannedAt,
  });

  factory TicketReceipt.fromJson(Map<String, dynamic> json) {
    return TicketReceipt(
      saleId: json['sale_id'] as int,
      userId: json['user_id'] as int,
      receiptNumber: json['receipt_number'] as String? ?? '',
      ticketCode: json['ticket_code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      attendeeName: json['attendee_name'] as String?,
      eventId: json['event_id'] as int,
      eventTitle: json['event_title'] as String? ?? '',
      eventStartTime: json['event_start_time'] != null
          ? DateTime.parse(json['event_start_time'] as String)
          : null,
      eventEndTime: json['event_end_time'] != null
          ? DateTime.parse(json['event_end_time'] as String)
          : null,
      organizerName: json['organizer_name'] as String?,
      organizerEmail: json['organizer_email'] as String?,
      organizerPhone: json['organizer_phone'] as String?,
      venueName: json['venue_name'] as String?,
      venueAddress: json['venue_address'] as String?,
      tierName: json['tier_name'] as String? ?? '',
      tierPriceCents: json['tier_price_cents'] as int? ?? 0,
      amountPaidCents: json['amount_paid_cents'] as int? ?? 0,
      discountAppliedCents: json['discount_applied_cents'] as int? ?? 0,
      commissionCents: json['commission_cents'] as int? ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] as int? ?? 0,
      subtotalCents: json['subtotal_cents'] as int? ?? 0,
      taxCents: json['tax_cents'] as int? ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxJurisdiction: json['tax_jurisdiction'] as String?,
      extraPerks: json['extra_perks'] as String?,
      encryptedQrPayload: json['encrypted_qr_payload'] as String?,
      purchasedAt: DateTime.parse(json['purchased_at'] as String),
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : null,
    );
  }

  String get amountFormatted =>
      '\$${(amountPaidCents / 100).toStringAsFixed(2)}';
}

class TicketSummaryItem {
  final int saleId;
  final String ticketCode;
  final String? receiptNumber;
  final String? encryptedQrPayload;
  final String status;
  final DateTime? scannedAt;

  TicketSummaryItem({
    required this.saleId,
    required this.ticketCode,
    this.receiptNumber,
    this.encryptedQrPayload,
    required this.status,
    this.scannedAt,
  });

  factory TicketSummaryItem.fromJson(Map<String, dynamic> json) {
    return TicketSummaryItem(
      saleId: json['sale_id'] as int,
      ticketCode: json['ticket_code'] as String? ?? '',
      receiptNumber: json['receipt_number'] as String?,
      encryptedQrPayload: json['encrypted_qr_payload'] as String?,
      status: json['status'] as String? ?? '',
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : null,
    );
  }
}

class PurchaseGroupReceipt {
  final String purchaseGroupId;
  final int eventId;
  final String eventTitle;
  final DateTime? eventStartTime;
  final DateTime? eventEndTime;
  final String? organizerName;
  final String? organizerEmail;
  final String? organizerPhone;
  final String? venueName;
  final String? venueAddress;
  final String? attendeeName;
  final String tierName;
  final int tierPriceCents;
  final int quantity;
  final int totalAmountPaidCents;
  final int totalDiscountAppliedCents;
  final int totalCommissionCents;
  final int totalNetToOrganizerCents;
  final int totalSubtotalCents;
  final int totalTaxCents;
  final double taxRate;
  final String? taxJurisdiction;
  final List<TicketSummaryItem> tickets;
  final DateTime purchasedAt;

  PurchaseGroupReceipt({
    required this.purchaseGroupId,
    required this.eventId,
    required this.eventTitle,
    this.eventStartTime,
    this.eventEndTime,
    this.organizerName,
    this.organizerEmail,
    this.organizerPhone,
    this.venueName,
    this.venueAddress,
    this.attendeeName,
    required this.tierName,
    required this.tierPriceCents,
    required this.quantity,
    required this.totalAmountPaidCents,
    required this.totalDiscountAppliedCents,
    this.totalCommissionCents = 0,
    this.totalNetToOrganizerCents = 0,
    this.totalSubtotalCents = 0,
    this.totalTaxCents = 0,
    this.taxRate = 0.0,
    this.taxJurisdiction,
    required this.tickets,
    required this.purchasedAt,
  });

  factory PurchaseGroupReceipt.fromJson(Map<String, dynamic> json) {
    return PurchaseGroupReceipt(
      purchaseGroupId: json['purchase_group_id'] as String,
      eventId: json['event_id'] as int,
      eventTitle: json['event_title'] as String? ?? '',
      eventStartTime: json['event_start_time'] != null
          ? DateTime.parse(json['event_start_time'] as String)
          : null,
      eventEndTime: json['event_end_time'] != null
          ? DateTime.parse(json['event_end_time'] as String)
          : null,
      organizerName: json['organizer_name'] as String?,
      organizerEmail: json['organizer_email'] as String?,
      organizerPhone: json['organizer_phone'] as String?,
      venueName: json['venue_name'] as String?,
      venueAddress: json['venue_address'] as String?,
      attendeeName: json['attendee_name'] as String?,
      tierName: json['tier_name'] as String? ?? '',
      tierPriceCents: json['tier_price_cents'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 0,
      totalAmountPaidCents: json['total_amount_paid_cents'] as int? ?? 0,
      totalDiscountAppliedCents:
          json['total_discount_applied_cents'] as int? ?? 0,
      totalCommissionCents: json['total_commission_cents'] as int? ?? 0,
      totalNetToOrganizerCents:
          json['total_net_to_organizer_cents'] as int? ?? 0,
      totalSubtotalCents: json['total_subtotal_cents'] as int? ?? 0,
      totalTaxCents: json['total_tax_cents'] as int? ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxJurisdiction: json['tax_jurisdiction'] as String?,
      tickets: (json['tickets'] as List<dynamic>?)
              ?.map((t) =>
                  TicketSummaryItem.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      purchasedAt: DateTime.parse(json['purchased_at'] as String),
    );
  }

  String get totalAmountFormatted =>
      '\$${(totalAmountPaidCents / 100).toStringAsFixed(2)}';
}

class PledgeReceipt {
  final int id;
  final String? receiptNumber;
  final int eventId;
  final String eventTitle;
  final int userId;
  final String? backerName;
  final int amountCents;
  final int reservedSpots;
  final List<TierReservation> tierReservations;
  final int platformCutCents;
  final int netToOrganizerCents;
  final int fundingCommissionPercent;
  final int subtotalCents;
  final int taxCents;
  final double taxRate;
  final String status;
  final bool isGuest;
  final DateTime createdAt;

  PledgeReceipt({
    required this.id,
    this.receiptNumber,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    this.backerName,
    required this.amountCents,
    this.reservedSpots = 0,
    this.tierReservations = const [],
    this.platformCutCents = 0,
    this.netToOrganizerCents = 0,
    this.fundingCommissionPercent = 0,
    this.subtotalCents = 0,
    this.taxCents = 0,
    this.taxRate = 0.0,
    required this.status,
    this.isGuest = false,
    required this.createdAt,
  });

  factory PledgeReceipt.fromJson(Map<String, dynamic> json) {
    return PledgeReceipt(
      id: json['id'] as int,
      receiptNumber: json['receipt_number'] as String?,
      eventId: json['event_id'] as int,
      eventTitle: json['event_title'] as String? ?? '',
      userId: json['user_id'] as int,
      backerName: json['backer_name'] as String?,
      amountCents: json['amount_cents'] as int? ?? 0,
      reservedSpots: json['reserved_spots'] as int? ?? 0,
      tierReservations: (json['tier_reservations'] as List<dynamic>?)
              ?.map((t) =>
                  TierReservation.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      platformCutCents: json['platform_cut_cents'] as int? ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] as int? ?? 0,
      fundingCommissionPercent:
          json['funding_commission_percent'] as int? ?? 0,
      subtotalCents: json['subtotal_cents'] as int? ?? 0,
      taxCents: json['tax_cents'] as int? ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      isGuest: json['is_guest'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get amountFormatted =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';
}

class TierReservation {
  final int tierId;
  final String tierName;
  final int spots;

  TierReservation({
    required this.tierId,
    required this.tierName,
    required this.spots,
  });

  factory TierReservation.fromJson(Map<String, dynamic> json) {
    return TierReservation(
      tierId: json['tier_id'] as int,
      tierName: json['tier_name'] as String? ?? '',
      spots: json['spots'] as int? ?? 0,
    );
  }
}
