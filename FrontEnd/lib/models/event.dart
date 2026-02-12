import 'venue.dart';

// ignore_for_file: constant_identifier_names
enum EventStatus {
  draft,
  pending_approval,
  approved,
  selling_tickets,
  waiting_event_date,
  live,
  completed,
  cancelled,
}

enum RegistrationType { open, closed }

class Event {
  final int id;
  final int organizerId;
  final int venueId;
  final String title;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? lat;
  final double? lng;
  final int? fundingGoalCents;
  final DateTime? fundingEndAt;
  final int minPledgeCents;
  final EventStatus status;
  final RegistrationType registrationType;
  final int maxCapacity;
  final int commonDiscountPercent;
  final int pledgeDiscountPercent;
  final int? totalPledgedCents;
  final int? fundingDaysLeft;
  final String? cancellationReason;
  final int registrationCount;
  final String? genre;
  final bool postsEnabled;
  final int? refundDeadlineDays;
  final DateTime? eventDateDeadline;
  final int? ticketStrategyId;
  final int likeCount;
  final int dislikeCount;
  final Venue? venue;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.organizerId,
    required this.venueId,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.lat,
    this.lng,
    this.fundingGoalCents,
    this.fundingEndAt,
    required this.minPledgeCents,
    required this.status,
    required this.registrationType,
    required this.maxCapacity,
    required this.commonDiscountPercent,
    required this.pledgeDiscountPercent,
    this.totalPledgedCents,
    this.fundingDaysLeft,
    this.cancellationReason,
    this.registrationCount = 0,
    this.genre,
    this.postsEnabled = true,
    this.refundDeadlineDays,
    this.eventDateDeadline,
    this.ticketStrategyId,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.venue,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      organizerId: json['organizer_id'],
      venueId: json['venue_id'],
      title: json['title'],
      description: json['description'],
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      fundingGoalCents: json['funding_goal_cents'],
      fundingEndAt: json['funding_end_at'] != null
          ? DateTime.parse(json['funding_end_at'])
          : null,
      minPledgeCents: json['min_pledge_cents'] ?? 0,
      status: EventStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => EventStatus.draft,
      ),
      registrationType: RegistrationType.values.firstWhere(
        (r) => r.name == json['registration_type'],
        orElse: () => RegistrationType.open,
      ),
      maxCapacity: json['max_capacity'] ?? 0,
      commonDiscountPercent: json['common_discount_percent'] ?? 0,
      pledgeDiscountPercent: json['pledge_discount_percent'] ?? 0,
      totalPledgedCents: json['total_pledged_cents'],
      fundingDaysLeft: json['funding_days_left'],
      cancellationReason: json['cancellation_reason'],
      registrationCount: json['registration_count'] ?? 0,
      genre: json['genre'],
      postsEnabled: json['posts_enabled'] ?? true,
      refundDeadlineDays: json['refund_deadline_days'],
      eventDateDeadline: json['event_date_deadline'] != null
          ? DateTime.parse(json['event_date_deadline'])
          : null,
      ticketStrategyId: json['ticket_strategy_id'],
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
      venue: json['venue'] != null ? Venue.fromJson(json['venue']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  double get fundingProgress {
    if (fundingGoalCents == null || fundingGoalCents == 0) return 0;
    return (totalPledgedCents ?? 0) / fundingGoalCents!;
  }

  String get fundingGoalFormatted {
    if (fundingGoalCents == null) return 'N/A';
    return '\$${(fundingGoalCents! / 100).toStringAsFixed(2)}';
  }

  String get totalPledgedFormatted {
    return '\$${((totalPledgedCents ?? 0) / 100).toStringAsFixed(2)}';
  }

  bool get isFunding =>
      fundingGoalCents != null &&
      fundingEndAt != null &&
      DateTime.now().isBefore(fundingEndAt!);

  /// Whether the refund window is still open (now is before event start minus deadline days).
  bool get isRefundEligible {
    if (startTime == null || refundDeadlineDays == null) return true;
    final cutoff = startTime!.subtract(Duration(days: refundDeadlineDays!));
    return DateTime.now().toUtc().isBefore(cutoff);
  }

  /// Whether pledging is allowed (only during approved/funding phase).
  bool get canPledge => status == EventStatus.approved && fundingEndAt != null;

  /// Whether unregistering is allowed (not in post-funding states).
  bool get canUnregister => status == EventStatus.approved || status == EventStatus.draft;
}
