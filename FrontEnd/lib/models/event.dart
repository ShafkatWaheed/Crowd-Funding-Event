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
  under_review,
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
  final String? reviewNotes;
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
  final PendingExtension? pendingExtension;
  final PendingCancellation? pendingCancellation;
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
  final bool linkFundingToTiers;
  final int maxDiscountPercent;
  final bool ageRestricted;
  final int minAge;
  final String? directionsUrl;
  final String? firstImageUrl;
  final String? viewerCoOrganizerPermission;
  final bool? viewerIsRegistered;
  final String? viewerRegistrationStatus;
  final Venue? venue;
  final DateTime createdAt;
  // Policy fields
  final int? waitlistMaxSize;
  final bool waitlistAutoApprove;
  final int? eventMaxImages;
  final int? maxPostsPerDay;
  final int? maxCoOrganizers;

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
    this.reviewNotes,
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
    this.linkFundingToTiers = false,
    this.maxDiscountPercent = 100,
    this.ageRestricted = false,
    this.minAge = 18,
    this.directionsUrl,
    this.firstImageUrl,
    this.viewerCoOrganizerPermission,
    this.viewerIsRegistered,
    this.viewerRegistrationStatus,
    this.venue,
    required this.createdAt,
    this.waitlistMaxSize,
    this.waitlistAutoApprove = true,
    this.eventMaxImages,
    this.maxPostsPerDay,
    this.maxCoOrganizers,
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
      reviewNotes: json['review_notes'],
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
          ? PendingExtension.fromJson(Map<String, dynamic>.from(json['pending_extension'] as Map))
          : null,
      pendingCancellation: json['pending_cancellation'] != null
          ? PendingCancellation.fromJson(Map<String, dynamic>.from(json['pending_cancellation'] as Map))
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
      linkFundingToTiers: json['link_funding_to_tiers'] ?? false,
      maxDiscountPercent: json['max_discount_percent'] ?? 100,
      ageRestricted: json['age_restricted'] ?? false,
      minAge: json['min_age'] ?? 18,
      directionsUrl: json['directions_url'],
      firstImageUrl: json['first_image_url'],
      viewerCoOrganizerPermission: json['viewer_co_organizer_permission'],
      viewerIsRegistered: json['viewer_is_registered'],
      viewerRegistrationStatus: json['viewer_registration_status'],
      venue: json['venue'] != null ? Venue.fromJson(json['venue']) : null,
      createdAt: DateTime.parse(json['created_at']),
      waitlistMaxSize: json['waitlist_max_size'] as int?,
      waitlistAutoApprove: (json['waitlist_auto_approve'] as bool?) ?? true,
      eventMaxImages: json['event_max_images'] as int?,
      maxPostsPerDay: json['max_posts_per_day'] as int?,
      maxCoOrganizers: json['max_co_organizers'] as int?,
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

  /// Whether the viewer is an accepted co-organizer (any permission).
  bool get viewerIsCoOrganizer => viewerCoOrganizerPermission != null;

  /// Whether the viewer is an accepted co-organizer with full permission.
  bool get viewerHasFullCoOrganizerAccess => viewerCoOrganizerPermission == 'full';

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

// ─── Event Metadata Models ───

class PendingCancellation {
  final String? reason;
  final String? requestedAt;
  final int? requestedBy;
  final num? pledgePercent;

  PendingCancellation({this.reason, this.requestedAt, this.requestedBy, this.pledgePercent});

  factory PendingCancellation.fromJson(Map<String, dynamic> json) =>
      PendingCancellation(
        reason: json['reason'] as String?,
        requestedAt: json['requested_at'] as String?,
        requestedBy: json['requested_by'] as int?,
        pledgePercent: json['pledge_percent'] as num?,
      );
}

class PendingExtension {
  final String? fundingEndAt;
  final int? fundingGoalCents;
  final String? startTime;
  final String? endTime;

  PendingExtension({this.fundingEndAt, this.fundingGoalCents, this.startTime, this.endTime});

  factory PendingExtension.fromJson(Map<String, dynamic> json) =>
      PendingExtension(
        fundingEndAt: json['funding_end_at'] as String?,
        fundingGoalCents: json['funding_goal_cents'] as int?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
      );
}

class ReviewLogEntry {
  final String actor;
  final String? timestamp;
  final String? action;
  final String? message;
  final String? notes;

  ReviewLogEntry({required this.actor, this.timestamp, this.action, this.message, this.notes});

  factory ReviewLogEntry.fromJson(Map<String, dynamic> json) =>
      ReviewLogEntry(
        actor: (json['actor'] as String?) ?? '',
        timestamp: json['timestamp'] as String?,
        action: json['action'] as String?,
        message: json['message'] as String?,
        notes: json['notes'] as String?,
      );
}

class ReactionResult {
  final String action;
  final String reaction;
  final int likeCount;
  final int dislikeCount;

  ReactionResult({
    required this.action,
    required this.reaction,
    required this.likeCount,
    required this.dislikeCount,
  });

  factory ReactionResult.fromJson(Map<String, dynamic> json) => ReactionResult(
        action: (json['action'] as String?) ?? '',
        reaction: (json['reaction'] as String?) ?? '',
        likeCount: (json['like_count'] as int?) ?? 0,
        dislikeCount: (json['dislike_count'] as int?) ?? 0,
      );
}

class FeaturedEvents {
  final List<Event> trending;
  final List<Event> popular;
  final List<Event> comingSoon;

  FeaturedEvents({
    this.trending = const [],
    this.popular = const [],
    this.comingSoon = const [],
  });

  factory FeaturedEvents.fromJson(Map<String, dynamic> json) {
    List<Event> parseList(dynamic val) => (val as List?)
            ?.map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return FeaturedEvents(
      trending: parseList(json['trending']),
      popular: parseList(json['popular']),
      comingSoon: parseList(json['coming_soon']),
    );
  }
}

class EventListPage {
  final List<Event> items;
  final String? nextCursor;

  EventListPage({required this.items, this.nextCursor});

  factory EventListPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = (rawItems as List?)
            ?.map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return EventListPage(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

class EventOrganizer {
  final int userId;
  final String? displayName;
  final String email;
  final bool isMain;
  final String permission;
  final String invitationStatus;

  EventOrganizer({
    required this.userId,
    this.displayName,
    required this.email,
    this.isMain = false,
    required this.permission,
    required this.invitationStatus,
  });

  factory EventOrganizer.fromJson(Map<String, dynamic> json) =>
      EventOrganizer(
        userId: json['user_id'] as int,
        displayName: json['display_name'] as String?,
        email: (json['email'] as String?) ?? '',
        isMain: (json['is_main'] as bool?) ?? false,
        permission: (json['permission'] as String?) ?? 'read',
        invitationStatus:
            (json['invitation_status'] as String?) ?? 'pending',
      );
}

class OrganizerSearchResult {
  final int id;
  final String email;
  final String? displayName;

  OrganizerSearchResult({
    required this.id,
    required this.email,
    this.displayName,
  });

  factory OrganizerSearchResult.fromJson(Map<String, dynamic> json) =>
      OrganizerSearchResult(
        id: json['id'] as int,
        email: (json['email'] as String?) ?? '',
        displayName: json['display_name'] as String?,
      );
}

class Registration {
  final int id;
  final int eventId;
  final int userId;
  final String status;
  final DateTime createdAt;

  Registration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        userId: json['user_id'] as int,
        status: (json['status'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CapacityInfo {
  final int maxCapacity;
  final int ticketsSold;
  final int totalReservedSpots;
  final int occupied;
  final int available;
  final int registrationCount;

  CapacityInfo({
    required this.maxCapacity,
    required this.ticketsSold,
    required this.totalReservedSpots,
    required this.occupied,
    required this.available,
    required this.registrationCount,
  });

  factory CapacityInfo.fromJson(Map<String, dynamic> json) => CapacityInfo(
        maxCapacity: (json['max_capacity'] as int?) ?? 0,
        ticketsSold: (json['tickets_sold'] as int?) ?? 0,
        totalReservedSpots: (json['total_reserved_spots'] as int?) ?? 0,
        occupied: (json['occupied'] as int?) ?? 0,
        available: (json['available'] as int?) ?? 0,
        registrationCount: (json['registration_count'] as int?) ?? 0,
      );
}
