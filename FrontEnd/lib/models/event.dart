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
  final int totalTierCapacity;
  final String? cancellationReason;
  final String? reviewNotes;
  final int registrationCount;
  final String? genre;
  final bool communityRules;
  final bool postsEnabled;
  final bool faqEnabled;
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
  final int? viewerPledgeAmountCents;
  final int? viewerTicketCount;
  final bool viewerIsSponsor;
  final Venue? venue;
  final DateTime createdAt;
  // Policy fields
  final int? waitlistMaxSize;
  final bool waitlistAutoApprove;
  final int? eventMaxImages;
  final int? maxPostsPerDay;
  final int? maxCoOrganizers;
  final int? reservedSpotsReleasePercent;
  final bool releaseTierSpotLimits;
  final bool isPrivate;
  final String? shareToken;

  /// True if this is a private closed event (accessible only via share link).
  bool get isPrivateClosed => isPrivate && registrationType == RegistrationType.closed;

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
    this.totalTierCapacity = 0,
    this.cancellationReason,
    this.reviewNotes,
    this.registrationCount = 0,
    this.genre,
    this.communityRules = false,
    this.postsEnabled = true,
    this.faqEnabled = false,
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
    this.viewerPledgeAmountCents,
    this.viewerTicketCount,
    this.viewerIsSponsor = false,
    this.venue,
    required this.createdAt,
    this.waitlistMaxSize,
    this.waitlistAutoApprove = true,
    this.eventMaxImages,
    this.maxPostsPerDay,
    this.maxCoOrganizers,
    this.reservedSpotsReleasePercent,
    this.releaseTierSpotLimits = false,
    this.isPrivate = false,
    this.shareToken,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: (json['id'] as num?)?.toInt() ?? 0,
      organizerId: (json['organizer_id'] as num?)?.toInt() ?? 0,
      organizerName: json['organizer_name'],
      venueId: (json['venue_id'] as num?)?.toInt() ?? 0,
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
      totalTierCapacity: json['total_tier_capacity'] ?? 0,
      cancellationReason: json['cancellation_reason'],
      reviewNotes: json['review_notes'],
      registrationCount: json['registration_count'] ?? 0,
      genre: json['genre'],
      communityRules: json['community_rules'] ?? false,
      postsEnabled: json['posts_enabled'] ?? true,
      faqEnabled: json['faq_enabled'] as bool? ?? false,
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
      viewerPledgeAmountCents: json['viewer_pledge_amount_cents'] as int?,
      viewerTicketCount: json['viewer_ticket_count'] as int?,
      viewerIsSponsor: json['viewer_is_sponsor'] as bool? ?? false,
      venue: json['venue'] != null ? Venue.fromJson(json['venue']) : null,
      createdAt: DateTime.parse(json['created_at']),
      waitlistMaxSize: json['waitlist_max_size'] as int?,
      waitlistAutoApprove: (json['waitlist_auto_approve'] as bool?) ?? true,
      eventMaxImages: json['event_max_images'] as int?,
      maxPostsPerDay: json['max_posts_per_day'] as int?,
      maxCoOrganizers: json['max_co_organizers'] as int?,
      reservedSpotsReleasePercent: json['reserved_spots_release_percent'] as int?,
      releaseTierSpotLimits: (json['release_tier_spot_limits'] as bool?) ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      shareToken: json['share_token'] as String?,
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

  Event copyWithRegistrationCount(int count) => Event(
        id: id, organizerId: organizerId, organizerName: organizerName,
        venueId: venueId, title: title, description: description,
        startTime: startTime, endTime: endTime, lat: lat, lng: lng,
        fundingGoalCents: fundingGoalCents, fundingEndAt: fundingEndAt,
        minPledgeCents: minPledgeCents, status: status,
        registrationType: registrationType, maxCapacity: maxCapacity,
        maxReservedSpotsPerUser: maxReservedSpotsPerUser,
        commonDiscountPercent: commonDiscountPercent,
        pledgeDiscountPercent: pledgeDiscountPercent,
        totalPledgedCents: totalPledgedCents, fundingDaysLeft: fundingDaysLeft,
        totalReservedSpots: totalReservedSpots,
        ticketsSoldCount: ticketsSoldCount, totalTierCapacity: totalTierCapacity,
        cancellationReason: cancellationReason, reviewNotes: reviewNotes,
        registrationCount: count,
        genre: genre, communityRules: communityRules, postsEnabled: postsEnabled, faqEnabled: faqEnabled,
        refundDeadlineDays: refundDeadlineDays, eventDateDeadline: eventDateDeadline,
        ticketStrategyId: ticketStrategyId, ticketStrategyName: ticketStrategyName,
        likeCount: likeCount, dislikeCount: dislikeCount,
        pendingExtension: pendingExtension, pendingCancellation: pendingCancellation,
        organizerTrustScore: organizerTrustScore, organizerTrustLabel: organizerTrustLabel,
        organizerCompletedEvents: organizerCompletedEvents,
        organizerPublishedEvents: organizerPublishedEvents,
        parkingInfo: parkingInfo, transitInfo: transitInfo,
        rideshareInfo: rideshareInfo, accessibilityInfo: accessibilityInfo,
        hasSchedule: hasSchedule, linkFundingToTiers: linkFundingToTiers,
        maxDiscountPercent: maxDiscountPercent, ageRestricted: ageRestricted,
        minAge: minAge, directionsUrl: directionsUrl, firstImageUrl: firstImageUrl,
        viewerCoOrganizerPermission: viewerCoOrganizerPermission,
        viewerIsRegistered: viewerIsRegistered,
        viewerRegistrationStatus: viewerRegistrationStatus,
        viewerPledgeAmountCents: viewerPledgeAmountCents,
        viewerTicketCount: viewerTicketCount,
        viewerIsSponsor: viewerIsSponsor,
        venue: venue, createdAt: createdAt,
        waitlistMaxSize: waitlistMaxSize, waitlistAutoApprove: waitlistAutoApprove,
        eventMaxImages: eventMaxImages, maxPostsPerDay: maxPostsPerDay,
        maxCoOrganizers: maxCoOrganizers,
        reservedSpotsReleasePercent: reservedSpotsReleasePercent,
        releaseTierSpotLimits: releaseTierSpotLimits,
        isPrivate: isPrivate, shareToken: shareToken,
      );

  Event copyWithViewerData({int? pledgeAmountCents, int? ticketCount}) => Event(
        id: id, organizerId: organizerId, organizerName: organizerName,
        venueId: venueId, title: title, description: description,
        startTime: startTime, endTime: endTime, lat: lat, lng: lng,
        fundingGoalCents: fundingGoalCents, fundingEndAt: fundingEndAt,
        minPledgeCents: minPledgeCents, status: status,
        registrationType: registrationType, maxCapacity: maxCapacity,
        maxReservedSpotsPerUser: maxReservedSpotsPerUser,
        commonDiscountPercent: commonDiscountPercent,
        pledgeDiscountPercent: pledgeDiscountPercent,
        totalPledgedCents: totalPledgedCents, fundingDaysLeft: fundingDaysLeft,
        totalReservedSpots: totalReservedSpots,
        ticketsSoldCount: ticketsSoldCount, totalTierCapacity: totalTierCapacity,
        cancellationReason: cancellationReason, reviewNotes: reviewNotes,
        registrationCount: registrationCount,
        genre: genre, communityRules: communityRules, postsEnabled: postsEnabled, faqEnabled: faqEnabled,
        refundDeadlineDays: refundDeadlineDays, eventDateDeadline: eventDateDeadline,
        ticketStrategyId: ticketStrategyId, ticketStrategyName: ticketStrategyName,
        likeCount: likeCount, dislikeCount: dislikeCount,
        pendingExtension: pendingExtension, pendingCancellation: pendingCancellation,
        organizerTrustScore: organizerTrustScore, organizerTrustLabel: organizerTrustLabel,
        organizerCompletedEvents: organizerCompletedEvents,
        organizerPublishedEvents: organizerPublishedEvents,
        parkingInfo: parkingInfo, transitInfo: transitInfo,
        rideshareInfo: rideshareInfo, accessibilityInfo: accessibilityInfo,
        hasSchedule: hasSchedule, linkFundingToTiers: linkFundingToTiers,
        maxDiscountPercent: maxDiscountPercent, ageRestricted: ageRestricted,
        minAge: minAge, directionsUrl: directionsUrl, firstImageUrl: firstImageUrl,
        viewerCoOrganizerPermission: viewerCoOrganizerPermission,
        viewerIsRegistered: viewerIsRegistered,
        viewerRegistrationStatus: viewerRegistrationStatus,
        viewerPledgeAmountCents: pledgeAmountCents ?? viewerPledgeAmountCents,
        viewerTicketCount: ticketCount ?? viewerTicketCount,
        viewerIsSponsor: viewerIsSponsor,
        venue: venue, createdAt: createdAt,
        waitlistMaxSize: waitlistMaxSize, waitlistAutoApprove: waitlistAutoApprove,
        eventMaxImages: eventMaxImages, maxPostsPerDay: maxPostsPerDay,
        maxCoOrganizers: maxCoOrganizers,
        reservedSpotsReleasePercent: reservedSpotsReleasePercent,
        releaseTierSpotLimits: releaseTierSpotLimits,
        isPrivate: isPrivate, shareToken: shareToken,
      );

  /// Whether registering / unregistering is allowed.
  bool get canUnregister =>
      status == EventStatus.approved ||
      status == EventStatus.draft ||
      status == EventStatus.waiting_event_date ||
      status == EventStatus.selling_tickets ||
      status == EventStatus.live;

  /// Whether the user can manually register via the bottom strip.
  /// During approved (funding), register is inline in FundingCard.
  /// During selling_tickets/live, registration is automatic via ticket purchase.
  bool get canManuallyRegister =>
      status == EventStatus.draft;
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

class AddEventOrganizerRequest {
  final int userId;
  final String permission;

  const AddEventOrganizerRequest({
    required this.userId,
    required this.permission,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'permission': permission,
      };
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
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
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
        id: (json['id'] as num?)?.toInt() ?? 0,
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
        id: (json['id'] as num?)?.toInt() ?? 0,
        eventId: (json['event_id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
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

class BookmarkToggleResult {
  final bool bookmarked;

  BookmarkToggleResult({required this.bookmarked});

  factory BookmarkToggleResult.fromJson(Map<String, dynamic> json) =>
      BookmarkToggleResult(bookmarked: (json['bookmarked'] as bool?) ?? false);
}

class PostsToggleResult {
  final bool postsEnabled;

  PostsToggleResult({required this.postsEnabled});

  factory PostsToggleResult.fromJson(Map<String, dynamic> json) =>
      PostsToggleResult(
          postsEnabled: (json['posts_enabled'] as bool?) ?? false);
}

class MyReactionStatus {
  final String? reaction;

  MyReactionStatus({this.reaction});

  factory MyReactionStatus.fromJson(Map<String, dynamic> json) =>
      MyReactionStatus(reaction: json['reaction'] as String?);
}

class UnregisterResult {
  final int refundedCents;
  final int pledgesRefunded;
  final bool refundEligible;

  UnregisterResult({
    this.refundedCents = 0,
    this.pledgesRefunded = 0,
    this.refundEligible = true,
  });

  factory UnregisterResult.fromJson(Map<String, dynamic> json) =>
      UnregisterResult(
        refundedCents: (json['refunded_cents'] as int?) ?? 0,
        pledgesRefunded: (json['pledges_refunded'] as int?) ?? 0,
        refundEligible: (json['refund_eligible'] as bool?) ?? true,
      );
}

class PublicConfig {
  final int maxTicketsPerPurchase;
  final int waitlistMaxSizeLimit;
  final int eventMaxImagesLimit;
  final int maxPostsPerEventLimit;
  final int maxCoOrganizersLimit;
  final bool maxTicketsFrontendEnabled;
  final bool featureMilestonesEnabled;
  final bool featureScheduleEnabled;
  final bool featureSponsorsEnabled;
  final bool featureCommunityRulesEnabled;
  final bool offlineTicketAutoDownloadEnabled;

  PublicConfig({
    this.maxTicketsPerPurchase = 10,
    this.waitlistMaxSizeLimit = 100,
    this.eventMaxImagesLimit = 10,
    this.maxPostsPerEventLimit = 10,
    this.maxCoOrganizersLimit = 5,
    this.maxTicketsFrontendEnabled = false,
    this.featureMilestonesEnabled = true,
    this.featureScheduleEnabled = true,
    this.featureSponsorsEnabled = true,
    this.featureCommunityRulesEnabled = true,
    this.offlineTicketAutoDownloadEnabled = false,
  });

  factory PublicConfig.fromJson(Map<String, dynamic> json) => PublicConfig(
        maxTicketsPerPurchase:
            (json['max_tickets_per_purchase'] as int?) ?? 10,
        waitlistMaxSizeLimit:
            (json['waitlist_max_size_limit'] as int?) ?? 100,
        eventMaxImagesLimit:
            (json['event_max_images_limit'] as int?) ?? 10,
        maxPostsPerEventLimit:
            (json['max_posts_per_event_limit'] as int?) ?? 10,
        maxCoOrganizersLimit:
            (json['max_co_organizers_limit'] as int?) ?? 5,
        maxTicketsFrontendEnabled:
            (json['max_tickets_frontend_enabled'] as bool?) ?? false,
        featureMilestonesEnabled:
            (json['feature_milestones_enabled'] as bool?) ?? true,
        featureScheduleEnabled:
            (json['feature_schedule_enabled'] as bool?) ?? true,
        featureSponsorsEnabled:
            (json['feature_sponsors_enabled'] as bool?) ?? true,
        featureCommunityRulesEnabled:
            (json['feature_community_rules_enabled'] as bool?) ?? true,
        offlineTicketAutoDownloadEnabled:
            (json['offline_ticket_auto_download_enabled'] as bool?) ?? false,
      );

  Map<String, int> get platformLimits => {
        'waitlist_max_size_limit': waitlistMaxSizeLimit,
        'event_max_images_limit': eventMaxImagesLimit,
        'max_posts_per_event_limit': maxPostsPerEventLimit,
        'max_co_organizers_limit': maxCoOrganizersLimit,
      };
}

class ExtendFundingInput {
  final String? fundingEndAt;
  final int? fundingGoalCents;

  const ExtendFundingInput({this.fundingEndAt, this.fundingGoalCents});

  Map<String, dynamic> toJson() => {
        if (fundingEndAt != null) 'funding_end_at': fundingEndAt,
        if (fundingGoalCents != null) 'funding_goal_cents': fundingGoalCents,
      };

  bool get isEmpty => fundingEndAt == null && fundingGoalCents == null;
}

class SetEventDateInput {
  final String startTime;
  final String endTime;

  const SetEventDateInput({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() => {
        'start_time': startTime,
        'end_time': endTime,
      };
}

class EventCreateRequest {
  final int venueId;
  final String title;
  final String description;
  final int maxCapacity;
  final String registrationType;
  final int minPledgeCents;
  final int maxReservedSpotsPerUser;
  final String? genre;
  final bool communityRules;
  final bool postsEnabled;
  final bool faqEnabled;
  final bool publish;
  final String? startTime;
  final String? endTime;
  final String? fundingEndAt;
  final int? refundDeadlineDays;
  final int? fundingGoalCents;
  final int? ticketStrategyId;
  final double? lat;
  final double? lng;
  final String? parkingInfo;
  final String? transitInfo;
  final String? rideshareInfo;
  final String? accessibilityInfo;
  final bool hasSchedule;
  final bool linkFundingToTiers;
  final int maxDiscountPercent;
  final bool ageRestricted;
  final int minAge;
  final int? waitlistMaxSize;
  final bool waitlistAutoApprove;
  final int? eventMaxImages;
  final int? maxPostsPerDay;
  final int? maxCoOrganizers;
  final int? reservedSpotsReleasePercent;
  final bool releaseTierSpotLimits;
  final bool isPrivate;

  const EventCreateRequest({
    required this.venueId,
    required this.title,
    this.description = '',
    required this.maxCapacity,
    this.registrationType = 'open',
    this.minPledgeCents = 500,
    this.maxReservedSpotsPerUser = 0,
    this.genre,
    this.communityRules = false,
    this.postsEnabled = true,
    this.faqEnabled = false,
    this.publish = false,
    this.startTime,
    this.endTime,
    this.fundingEndAt,
    this.refundDeadlineDays,
    this.fundingGoalCents,
    this.ticketStrategyId,
    this.lat,
    this.lng,
    this.parkingInfo,
    this.transitInfo,
    this.rideshareInfo,
    this.accessibilityInfo,
    this.hasSchedule = false,
    this.linkFundingToTiers = false,
    this.maxDiscountPercent = 100,
    this.ageRestricted = false,
    this.minAge = 18,
    this.waitlistMaxSize,
    this.waitlistAutoApprove = true,
    this.eventMaxImages,
    this.maxPostsPerDay,
    this.maxCoOrganizers,
    this.reservedSpotsReleasePercent,
    this.releaseTierSpotLimits = false,
    this.isPrivate = false,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'venue_id': venueId,
      'title': title,
      'description': description,
      'max_capacity': maxCapacity,
      'registration_type': registrationType,
      'min_pledge_cents': minPledgeCents,
      'max_reserved_spots_per_user': maxReservedSpotsPerUser,
      'genre': genre,
      'community_rules': communityRules,
      'posts_enabled': postsEnabled,
      'faq_enabled': faqEnabled,
      'publish': publish,
    };
    if (startTime != null) data['start_time'] = startTime;
    if (endTime != null) data['end_time'] = endTime;
    if (fundingEndAt != null) {
      data['funding_end_at'] = fundingEndAt;
      if (refundDeadlineDays != null && refundDeadlineDays! > 0) {
        data['refund_deadline_days'] = refundDeadlineDays;
      }
    }
    if (fundingGoalCents != null && fundingGoalCents! > 0) {
      data['funding_goal_cents'] = fundingGoalCents;
    }
    if (ticketStrategyId != null) data['ticket_strategy_id'] = ticketStrategyId;
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    if (parkingInfo != null && parkingInfo!.isNotEmpty) data['parking_info'] = parkingInfo;
    if (transitInfo != null && transitInfo!.isNotEmpty) data['transit_info'] = transitInfo;
    if (rideshareInfo != null && rideshareInfo!.isNotEmpty) data['rideshare_info'] = rideshareInfo;
    if (accessibilityInfo != null && accessibilityInfo!.isNotEmpty) data['accessibility_info'] = accessibilityInfo;
    if (hasSchedule) data['has_schedule'] = true;
    if (linkFundingToTiers) data['link_funding_to_tiers'] = true;
    if (maxDiscountPercent != 100) data['max_discount_percent'] = maxDiscountPercent;
    if (ageRestricted) {
      data['age_restricted'] = true;
      data['min_age'] = minAge;
    }
    if (waitlistMaxSize != null && waitlistMaxSize! > 0) data['waitlist_max_size'] = waitlistMaxSize;
    data['waitlist_auto_approve'] = waitlistAutoApprove;
    if (eventMaxImages != null && eventMaxImages! > 0) data['event_max_images'] = eventMaxImages;
    if (maxPostsPerDay != null && maxPostsPerDay! > 0) data['max_posts_per_day'] = maxPostsPerDay;
    if (maxCoOrganizers != null && maxCoOrganizers! > 0) data['max_co_organizers'] = maxCoOrganizers;
    if (reservedSpotsReleasePercent != null) data['reserved_spots_release_percent'] = reservedSpotsReleasePercent;
    data['release_tier_spot_limits'] = releaseTierSpotLimits;
    if (isPrivate) data['is_private'] = true;
    return data;
  }
}

class EventUpdateRequest {
  final String? title;
  final String? description;
  final int? maxCapacity;
  final String? registrationType;
  final int? minPledgeCents;
  final int? maxReservedSpotsPerUser;
  final String? genre;
  final bool? postsEnabled;
  final bool? faqEnabled;
  final bool? communityRules;
  final String? startTime;
  final String? endTime;
  final String? fundingEndAt;
  final int? refundDeadlineDays;
  final int? fundingGoalCents;
  final int? ticketStrategyId;
  final int? venueId;
  final String? parkingInfo;
  final String? transitInfo;
  final String? rideshareInfo;
  final String? accessibilityInfo;
  final bool? hasSchedule;
  final int? waitlistMaxSize;
  final bool? waitlistAutoApprove;
  final int? eventMaxImages;
  final int? maxPostsPerDay;
  final int? maxCoOrganizers;
  final int? reservedSpotsReleasePercent;
  final bool? releaseTierSpotLimits;
  final bool? isPrivate;

  const EventUpdateRequest({
    this.title,
    this.description,
    this.maxCapacity,
    this.registrationType,
    this.minPledgeCents,
    this.maxReservedSpotsPerUser,
    this.genre,
    this.postsEnabled,
    this.faqEnabled,
    this.communityRules,
    this.startTime,
    this.endTime,
    this.fundingEndAt,
    this.refundDeadlineDays,
    this.fundingGoalCents,
    this.ticketStrategyId,
    this.venueId,
    this.parkingInfo,
    this.transitInfo,
    this.rideshareInfo,
    this.accessibilityInfo,
    this.hasSchedule,
    this.waitlistMaxSize,
    this.waitlistAutoApprove,
    this.eventMaxImages,
    this.maxPostsPerDay,
    this.maxCoOrganizers,
    this.reservedSpotsReleasePercent,
    this.releaseTierSpotLimits,
    this.isPrivate,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (maxCapacity != null) data['max_capacity'] = maxCapacity;
    if (registrationType != null) data['registration_type'] = registrationType;
    if (minPledgeCents != null) data['min_pledge_cents'] = minPledgeCents;
    if (maxReservedSpotsPerUser != null) data['max_reserved_spots_per_user'] = maxReservedSpotsPerUser;
    if (genre != null) data['genre'] = genre;
    if (postsEnabled != null) data['posts_enabled'] = postsEnabled;
    if (faqEnabled != null) data['faq_enabled'] = faqEnabled;
    if (communityRules != null) data['community_rules'] = communityRules;
    if (startTime != null) data['start_time'] = startTime;
    if (endTime != null) data['end_time'] = endTime;
    if (fundingEndAt != null) data['funding_end_at'] = fundingEndAt;
    if (refundDeadlineDays != null) data['refund_deadline_days'] = refundDeadlineDays;
    if (fundingGoalCents != null) data['funding_goal_cents'] = fundingGoalCents;
    if (ticketStrategyId != null) data['ticket_strategy_id'] = ticketStrategyId;
    if (venueId != null) data['venue_id'] = venueId;
    if (parkingInfo != null) data['parking_info'] = parkingInfo;
    if (transitInfo != null) data['transit_info'] = transitInfo;
    if (rideshareInfo != null) data['rideshare_info'] = rideshareInfo;
    if (accessibilityInfo != null) data['accessibility_info'] = accessibilityInfo;
    if (hasSchedule != null) data['has_schedule'] = hasSchedule;
    if (waitlistMaxSize != null) data['waitlist_max_size'] = waitlistMaxSize;
    if (waitlistAutoApprove != null) data['waitlist_auto_approve'] = waitlistAutoApprove;
    if (eventMaxImages != null) data['event_max_images'] = eventMaxImages;
    if (maxPostsPerDay != null) data['max_posts_per_day'] = maxPostsPerDay;
    if (maxCoOrganizers != null) data['max_co_organizers'] = maxCoOrganizers;
    if (reservedSpotsReleasePercent != null) data['reserved_spots_release_percent'] = reservedSpotsReleasePercent;
    if (releaseTierSpotLimits != null) data['release_tier_spot_limits'] = releaseTierSpotLimits;
    if (isPrivate != null) data['is_private'] = isPrivate;
    return data;
  }
}

/// Typed filter parameters for event list queries.
///
/// Used by [EventRepository.getEvents] and [EventProvider.loadEvents] as a
/// replacement for raw `Map<String, dynamic>` filter maps.
class EventFilters {
  final String? search;
  final String? status;
  final String? registrationType;
  final String? dateFrom;
  final String? dateTo;
  final bool? hasFunding;
  final String? genre;
  final String? city;
  final bool? includeAllStatuses;
  final int? organizerId;
  final bool? sponsorshipOnly;
  final String? communityRules;

  const EventFilters({
    this.search,
    this.status,
    this.registrationType,
    this.dateFrom,
    this.dateTo,
    this.hasFunding,
    this.genre,
    this.city,
    this.includeAllStatuses,
    this.organizerId,
    this.sponsorshipOnly,
    this.communityRules,
  });

  Map<String, dynamic> toQueryParams() => {
        if (search != null && search!.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        if (registrationType != null) 'registration_type': registrationType,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (hasFunding != null) 'has_funding': hasFunding,
        if (genre != null) 'genre': genre,
        if (city != null) 'city': city,
        if (includeAllStatuses != null && includeAllStatuses!)
          'include_all_statuses': true,
        if (organizerId != null) 'organizer_id': organizerId,
        if (sponsorshipOnly != null && sponsorshipOnly!)
          'sponsorship_only': true,
        if (communityRules != null) 'community_rules': communityRules,
      };
}
