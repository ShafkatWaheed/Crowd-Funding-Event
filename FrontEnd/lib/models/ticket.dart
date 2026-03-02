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
  });

  factory TicketTier.fromJson(Map<String, dynamic> json) {
    return TicketTier(
      id: json['id'],
      eventId: json['event_id'],
      name: json['name'],
      description: json['description'],
      priceCents: json['price_cents'],
      maxReservedSpots: json['max_reserved_spots'] ?? 0,
      ticketsSold: json['tickets_sold'] ?? 0,
      spotsReserved: json['spots_reserved'] ?? 0,
      displayOrder: json['display_order'] ?? 0,
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
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      ticketTierId: json['ticket_tier_id'],
      purchaseGroupId: json['purchase_group_id'],
      ticketCode: json['ticket_code'],
      receiptNumber: json['receipt_number'],
      tierName: json['tier_name'],
      eventTitle: json['event_title'],
      eventStatus: json['event_status'],
      attendeeDisplayName: json['attendee_display_name'],
      scannedByDisplayName: json['scanned_by_display_name'],
      amountPaidCents: json['amount_paid_cents'],
      discountAppliedCents: json['discount_applied_cents'] ?? 0,
      commissionCents: json['commission_cents'] ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] ?? 0,
      extraPerks: json['extra_perks'],
      status: json['status'],
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
