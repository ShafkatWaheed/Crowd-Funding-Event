class TicketStrategyTier {
  final int id;
  final String name;
  final String? description;
  final int priceCents;
  final int displayOrder;

  TicketStrategyTier({
    required this.id,
    required this.name,
    this.description,
    required this.priceCents,
    this.displayOrder = 0,
  });

  factory TicketStrategyTier.fromJson(Map<String, dynamic> json) {
    return TicketStrategyTier(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      priceCents: json['price_cents'],
      displayOrder: json['display_order'] ?? 0,
    );
  }

  bool get isFree => priceCents == 0;
  String get priceFormatted =>
      isFree ? 'FREE' : '\$${(priceCents / 100).toStringAsFixed(2)}';
}


class TicketStrategy {
  final int id;
  final int organizerId;
  final String name;
  final List<TicketStrategyTier> tiers;
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketStrategy({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.tiers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketStrategy.fromJson(Map<String, dynamic> json) {
    return TicketStrategy(
      id: json['id'],
      organizerId: json['organizer_id'],
      name: json['name'],
      tiers: (json['tiers'] as List? ?? [])
          .map((t) => TicketStrategyTier.fromJson(t))
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Summary line: "3 tiers: General ($10), VIP ($50), ..."
  String get tiersSummary {
    if (tiers.isEmpty) return 'No tiers';
    final items = tiers.map((t) => '${t.name} (${t.priceFormatted})').join(', ');
    return '${tiers.length} tier${tiers.length == 1 ? '' : 's'}: $items';
  }
}
