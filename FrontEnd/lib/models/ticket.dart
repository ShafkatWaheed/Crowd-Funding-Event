class TicketTier {
  final int id;
  final int eventId;
  final String name;
  final int priceCents;
  final int displayOrder;

  TicketTier({
    required this.id,
    required this.eventId,
    required this.name,
    required this.priceCents,
    required this.displayOrder,
  });

  factory TicketTier.fromJson(Map<String, dynamic> json) {
    return TicketTier(
      id: json['id'],
      eventId: json['event_id'],
      name: json['name'],
      priceCents: json['price_cents'],
      displayOrder: json['display_order'] ?? 0,
    );
  }

  bool get isFree => priceCents == 0;
  String get priceFormatted => isFree ? 'FREE' : '\$${(priceCents / 100).toStringAsFixed(2)}';
}

class TicketSale {
  final int id;
  final int eventId;
  final int userId;
  final int ticketTierId;
  final String ticketCode;
  final String? receiptNumber;
  final String? tierName;
  final String? eventTitle;
  final int amountPaidCents;
  final int discountAppliedCents;
  final String? extraPerks;
  final String status;
  final DateTime? scannedAt;
  final DateTime createdAt;

  TicketSale({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.ticketTierId,
    required this.ticketCode,
    this.receiptNumber,
    this.tierName,
    this.eventTitle,
    required this.amountPaidCents,
    required this.discountAppliedCents,
    this.extraPerks,
    required this.status,
    this.scannedAt,
    required this.createdAt,
  });

  factory TicketSale.fromJson(Map<String, dynamic> json) {
    return TicketSale(
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      ticketTierId: json['ticket_tier_id'],
      ticketCode: json['ticket_code'],
      receiptNumber: json['receipt_number'],
      tierName: json['tier_name'],
      eventTitle: json['event_title'],
      amountPaidCents: json['amount_paid_cents'],
      discountAppliedCents: json['discount_applied_cents'] ?? 0,
      extraPerks: json['extra_perks'],
      status: json['status'],
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get amountPaidFormatted =>
      '\$${(amountPaidCents / 100).toStringAsFixed(2)}';

  bool get isScanned => scannedAt != null;
}
