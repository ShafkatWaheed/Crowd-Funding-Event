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
  final String? organizerName;
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
  final int maxReservedSpotsPerUser;
  final int commonDiscountPercent;
  final int pledgeDiscountPercent;
  final int? totalPledgedCents;
  final int? fundingDaysLeft;
  final int totalReservedSpots;
  final int ticketsSoldCount;
  final String? cancellationReason;
  final int registrationCount;
  final String? genre;
  final bool communityRules;
  final bool postsEnabled;
  final int? refundDeadlineDays;
  final DateTime? eventDateDeadline;
  final int? ticketStrategyId;
  final String? ticketStrategyName;
  final int likeCount;
  final int dislikeCount;
  final Map<String, dynamic>? pendingExtension;
  final Map<String, dynamic>? pendingCancellation;
  final double organizerTrustScore;
  final String organizerTrustLabel;
  final int organizerCompletedEvents;
  final int organizerPublishedEvents;
  // Parking & Transport
  final String? parkingInfo;
  final String? transitInfo;
  final String? rideshareInfo;
  final String? accessibilityInfo;
  final bool hasSchedule;
  final String? directionsUrl;
  final String? firstImageUrl;
  final Venue? venue;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.organizerId,
    this.organizerName,
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
    this.maxReservedSpotsPerUser = 0,
    required this.commonDiscountPercent,
    required this.pledgeDiscountPercent,
    this.totalPledgedCents,
    this.fundingDaysLeft,
    this.totalReservedSpots = 0,
    this.ticketsSoldCount = 0,
    this.cancellationReason,
    this.registrationCount = 0,
    this.genre,
    this.communityRules = false,
    this.postsEnabled = true,
    this.refundDeadlineDays,
    this.eventDateDeadline,
    this.ticketStrategyId,
    this.ticketStrategyName,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.pendingExtension,
    this.pendingCancellation,
    this.organizerTrustScore = 0.0,
    this.organizerTrustLabel = 'New',
    this.organizerCompletedEvents = 0,
    this.organizerPublishedEvents = 0,
    this.parkingInfo,
    this.transitInfo,
    this.rideshareInfo,
    this.accessibilityInfo,
    this.hasSchedule = false,
    this.directionsUrl,
    this.firstImageUrl,
    this.venue,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      organizerId: json['organizer_id'],
      organizerName: json['organizer_name'],
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
      maxReservedSpotsPerUser: json['max_reserved_spots_per_user'] ?? 0,
      commonDiscountPercent: json['common_discount_percent'] ?? 0,
      pledgeDiscountPercent: json['pledge_discount_percent'] ?? 0,
      totalPledgedCents: json['total_pledged_cents'],
      fundingDaysLeft: json['funding_days_left'],
      totalReservedSpots: json['total_reserved_spots'] ?? 0,
      ticketsSoldCount: json['tickets_sold_count'] ?? 0,
      cancellationReason: json['cancellation_reason'],
      registrationCount: json['registration_count'] ?? 0,
      genre: json['genre'],
      communityRules: json['community_rules'] ?? false,
      postsEnabled: json['posts_enabled'] ?? true,
      refundDeadlineDays: json['refund_deadline_days'],
      eventDateDeadline: json['event_date_deadline'] != null
          ? DateTime.parse(json['event_date_deadline'])
          : null,
      ticketStrategyId: json['ticket_strategy_id'],
      ticketStrategyName: json['ticket_strategy_name'],
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
      pendingExtension: json['pending_extension'] != null
          ? Map<String, dynamic>.from(json['pending_extension'])
          : null,
      pendingCancellation: json['pending_cancellation'] != null
          ? Map<String, dynamic>.from(json['pending_cancellation'])
          : null,
      organizerTrustScore: (json['organizer_trust']?['trust_score'] ?? 0.0).toDouble(),
      organizerTrustLabel: json['organizer_trust']?['label'] ?? 'New',
      organizerCompletedEvents: json['organizer_trust']?['completed_events'] ?? 0,
      organizerPublishedEvents: json['organizer_trust']?['published_events'] ?? 0,
      parkingInfo: json['parking_info'],
      transitInfo: json['transit_info'],
      rideshareInfo: json['rideshare_info'],
      accessibilityInfo: json['accessibility_info'],
      hasSchedule: json['has_schedule'] ?? false,
      directionsUrl: json['directions_url'],
      firstImageUrl: json['first_image_url'],
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

  /// Human-readable time remaining until funding deadline.
  /// Returns e.g. "2d 5h left", "3h 42m left", "18m left", or "Ended".
  String get fundingTimeLeftFormatted {
    if (fundingEndAt == null) return '';
    final now = DateTime.now().toUtc();
    final end = fundingEndAt!.toUtc();
    final diff = end.difference(now);
    if (diff.isNegative || diff.inSeconds == 0) return 'Ended';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h left';
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '${minutes}m left';
  }

  /// Whether funding time is still remaining.
  bool get fundingHasTimeLeft {
    if (fundingEndAt == null) return false;
    return DateTime.now().toUtc().isBefore(fundingEndAt!.toUtc());
  }

  /// Whether pledging is allowed (only during approved/funding phase).
  bool get canPledge => status == EventStatus.approved && fundingEndAt != null;

  /// Whether any transport/parking info is set.
  bool get hasTransportInfo =>
      (parkingInfo != null && parkingInfo!.isNotEmpty) ||
      (transitInfo != null && transitInfo!.isNotEmpty) ||
      (rideshareInfo != null && rideshareInfo!.isNotEmpty) ||
      (accessibilityInfo != null && accessibilityInfo!.isNotEmpty);

  /// Whether registering / unregistering is allowed.
  /// Whether registering / unregistering is allowed.
  bool get canUnregister =>
      status == EventStatus.approved ||
      status == EventStatus.draft ||
      status == EventStatus.waiting_event_date ||
      status == EventStatus.selling_tickets ||
      status == EventStatus.live;
}
