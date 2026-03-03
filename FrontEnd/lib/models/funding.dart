enum PledgeStatus { pledged, collected, refunded }

class Pledge {
  final int id;
  final int eventId;
  final int userId;
  final int amountCents;
  final int reservedSpots;
  final String? receiptNumber;
  final int platformCutCents;
  final int netToOrganizerCents;
  final PledgeStatus status;
  final bool isGuest;
  final DateTime createdAt;
  // Included in /me/pledges and organizer/admin responses
  final String? eventTitle;
  final String? backerName;
  final String? userDisplayName;

  Pledge({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.amountCents,
    this.reservedSpots = 0,
    this.receiptNumber,
    this.platformCutCents = 0,
    this.netToOrganizerCents = 0,
    required this.status,
    this.isGuest = false,
    required this.createdAt,
    this.eventTitle,
    this.backerName,
    this.userDisplayName,
  });

  factory Pledge.fromJson(Map<String, dynamic> json) {
    return Pledge(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      userId: (json['user_id'] ?? 0) as int,
      amountCents: (json['amount_cents'] ?? 0) as int,
      reservedSpots: json['reserved_spots'] ?? 0,
      receiptNumber: json['receipt_number'],
      platformCutCents: json['platform_cut_cents'] ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] ?? 0,
      status: PledgeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PledgeStatus.pledged,
      ),
      isGuest: json['is_guest'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      eventTitle: json['event_title'],
      backerName: json['backer_name'],
      userDisplayName: json['user_display_name'],
    );
  }

  String get amountFormatted =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';
}

class FundingSummary {
  final int goalCents;
  final int totalPledgedCents;
  final int backersCount;
  final int totalReservedSpots;
  final int fundingCommissionPercent;
  final DateTime? fundingEndAt;

  FundingSummary({
    required this.goalCents,
    required this.totalPledgedCents,
    required this.backersCount,
    this.totalReservedSpots = 0,
    this.fundingCommissionPercent = 0,
    this.fundingEndAt,
  });

  factory FundingSummary.fromJson(Map<String, dynamic> json) {
    return FundingSummary(
      goalCents: json['goal_cents'] ?? 0,
      totalPledgedCents: json['total_pledged_cents'] ?? 0,
      backersCount: json['backers_count'] ?? 0,
      totalReservedSpots: json['total_reserved_spots'] ?? 0,
      fundingCommissionPercent: json['funding_commission_percent'] ?? 0,
      fundingEndAt: json['funding_end_at'] != null
          ? DateTime.parse(json['funding_end_at'])
          : null,
    );
  }

  double get progress =>
      goalCents > 0 ? totalPledgedCents / goalCents : 0;

  String get goalFormatted =>
      '\$${(goalCents / 100).toStringAsFixed(2)}';

  String get totalPledgedFormatted =>
      '\$${(totalPledgedCents / 100).toStringAsFixed(2)}';
}
