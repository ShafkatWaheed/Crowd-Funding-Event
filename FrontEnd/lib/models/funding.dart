enum PledgeStatus { pledged, collected, refunded }

class Pledge {
  final int id;
  final int eventId;
  final int userId;
  final int amountCents;
  final PledgeStatus status;
  final DateTime createdAt;
  // Included in /me/pledges response
  final String? eventTitle;

  Pledge({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.eventTitle,
  });

  factory Pledge.fromJson(Map<String, dynamic> json) {
    return Pledge(
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      amountCents: json['amount_cents'],
      status: PledgeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PledgeStatus.pledged,
      ),
      createdAt: DateTime.parse(json['created_at']),
      eventTitle: json['event_title'],
    );
  }

  String get amountFormatted =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';
}

class FundingSummary {
  final int goalCents;
  final int totalPledgedCents;
  final int pledgeCount;
  final DateTime? fundingEndAt;

  FundingSummary({
    required this.goalCents,
    required this.totalPledgedCents,
    required this.pledgeCount,
    this.fundingEndAt,
  });

  factory FundingSummary.fromJson(Map<String, dynamic> json) {
    return FundingSummary(
      goalCents: json['goal_cents'] ?? 0,
      totalPledgedCents: json['total_pledged_cents'] ?? 0,
      pledgeCount: json['pledge_count'] ?? 0,
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
