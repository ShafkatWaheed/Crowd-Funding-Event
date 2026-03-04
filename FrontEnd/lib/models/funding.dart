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

class PledgePreview {
  final int amountCents;
  final int reservedSpots;
  final int costPerSpotCents;
  final int platformCutCents;
  final int netToOrganizerCents;
  final int fundingCommissionPercent;
  final int availableSpotsForUser;
  final int eventTotalReservedSpots;
  final bool linkFundingToTiers;
  final List<TierAvailability> tierAvailability;

  PledgePreview({
    required this.amountCents,
    required this.reservedSpots,
    this.costPerSpotCents = 0,
    this.platformCutCents = 0,
    this.netToOrganizerCents = 0,
    this.fundingCommissionPercent = 0,
    this.availableSpotsForUser = 0,
    this.eventTotalReservedSpots = 0,
    this.linkFundingToTiers = false,
    this.tierAvailability = const [],
  });

  factory PledgePreview.fromJson(Map<String, dynamic> json) {
    return PledgePreview(
      amountCents: json['amount_cents'] as int? ?? 0,
      reservedSpots: json['reserved_spots'] as int? ?? 0,
      costPerSpotCents: json['cost_per_spot_cents'] as int? ?? 0,
      platformCutCents: json['platform_cut_cents'] as int? ?? 0,
      netToOrganizerCents: json['net_to_organizer_cents'] as int? ?? 0,
      fundingCommissionPercent:
          json['funding_commission_percent'] as int? ?? 0,
      availableSpotsForUser: json['available_spots_for_user'] as int? ?? 0,
      eventTotalReservedSpots:
          json['event_total_reserved_spots'] as int? ?? 0,
      linkFundingToTiers: json['link_funding_to_tiers'] as bool? ?? false,
      tierAvailability: (json['tier_availability'] as List<dynamic>?)
              ?.map((t) =>
                  TierAvailability.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get amountFormatted =>
      '\$${(amountCents / 100).toStringAsFixed(2)}';
}

class TierAvailability {
  final int tierId;
  final String tierName;
  final int priceCents;
  final int maxReservedSpots;
  final int reservedSoFar;
  final int available;

  TierAvailability({
    required this.tierId,
    required this.tierName,
    required this.priceCents,
    required this.maxReservedSpots,
    required this.reservedSoFar,
    required this.available,
  });

  factory TierAvailability.fromJson(Map<String, dynamic> json) {
    return TierAvailability(
      tierId: json['tier_id'] as int,
      tierName: json['tier_name'] as String? ?? '',
      priceCents: json['price_cents'] as int? ?? 0,
      maxReservedSpots: json['max_reserved_spots'] as int? ?? 0,
      reservedSoFar: json['reserved_so_far'] as int? ?? 0,
      available: json['available'] as int? ?? 0,
    );
  }
}

class RefundStatus {
  final String status;
  final int processingCount;
  final int completedCount;
  final int failedCount;

  RefundStatus({
    required this.status,
    this.processingCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
  });

  factory RefundStatus.fromJson(Map<String, dynamic> json) {
    return RefundStatus(
      status: json['status'] as String? ?? 'none',
      processingCount: json['processing_count'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
    );
  }
}

// ─── Tier Reservation Input (for pledge forms) ───

class TierReservationInput {
  final int tierId;
  final String? tierName;
  final int spots;

  TierReservationInput({required this.tierId, this.tierName, required this.spots});

  Map<String, dynamic> toJson() => {'tier_id': tierId, 'spots': spots};
}

class UnpledgeResult {
  final int refundedCents;
  final int guestNonRefundableCents;
  final String status;
  final int unpledgedAmountCents;
  final int remainingPledges;
  final bool refundInitiated;

  UnpledgeResult({
    this.refundedCents = 0,
    this.guestNonRefundableCents = 0,
    this.status = 'completed',
    this.unpledgedAmountCents = 0,
    this.remainingPledges = 0,
    this.refundInitiated = false,
  });

  factory UnpledgeResult.fromJson(Map<String, dynamic> json) =>
      UnpledgeResult(
        refundedCents: (json['refunded_cents'] as int?) ?? 0,
        guestNonRefundableCents: (json['guest_non_refundable_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? 'completed',
        unpledgedAmountCents: (json['unpledged_amount_cents'] as int?) ?? 0,
        remainingPledges: (json['remaining_pledges'] as int?) ?? 0,
        refundInitiated: (json['refund_initiated'] as bool?) ?? false,
      );
}
