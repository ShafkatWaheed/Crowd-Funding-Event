import 'event.dart';

// ─── Generic Paginated Wrapper ───

class AdminPage<T> {
  final List<T> items;
  final int total;

  AdminPage({required this.items, required this.total});
}

// ─── Users ───

class AdminUserItem {
  final int id;
  final String email;
  final String? displayName;
  final String role;
  final String? createdAt;

  AdminUserItem({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.createdAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) => AdminUserItem(
        id: json['id'] as int,
        email: (json['email'] as String?) ?? '',
        displayName: json['display_name'] as String?,
        role: (json['role'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
      );
}

class AdminUserDetail {
  final int id;
  final String email;
  final String? displayName;
  final String role;
  final String? createdAt;
  final List<AdminUserTicket>? tickets;
  final List<AdminUserPledge>? pledges;
  final List<AdminUserEvent>? events;
  final List<AdminUserTicketSale>? ticketSales;
  final List<AdminUserSponsor>? sponsors;
  final List<AdminUserDiscount>? discounts;
  final List<AdminUserEscrow>? escrows;
  final List<AdminSponsorshipEvent>? sponsorships;
  final List<AdminSponsorshipEvent>? sponsorBids;

  AdminUserDetail({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.createdAt,
    this.tickets,
    this.pledges,
    this.events,
    this.ticketSales,
    this.sponsors,
    this.discounts,
    this.escrows,
    this.sponsorships,
    this.sponsorBids,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) =>
      AdminUserDetail(
        id: json['id'] as int,
        email: (json['email'] as String?) ?? '',
        displayName: json['display_name'] as String?,
        role: (json['role'] as String?) ?? 'customer',
        createdAt: json['created_at'] as String?,
        tickets: _parseList(json['tickets'], AdminUserTicket.fromJson),
        pledges: _parseList(json['pledges'], AdminUserPledge.fromJson),
        events: _parseList(json['events'], AdminUserEvent.fromJson),
        ticketSales:
            _parseList(json['ticket_sales'], AdminUserTicketSale.fromJson),
        sponsors: _parseList(json['sponsors'], AdminUserSponsor.fromJson),
        discounts: _parseList(json['discounts'], AdminUserDiscount.fromJson),
        escrows: _parseList(json['escrows'], AdminUserEscrow.fromJson),
        sponsorships:
            _parseList(json['sponsorships'], AdminSponsorshipEvent.fromJson),
        sponsorBids:
            _parseList(json['sponsor_bids'], AdminSponsorshipEvent.fromJson),
      );
}

/// Helper to parse a nullable JSON list into typed list.
List<T>? _parseList<T>(
    dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw == null) return null;
  return (raw as List)
      .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

class AdminUserTicket {
  final int id;
  final int eventId;
  final String? eventTitle;
  final String? tierName;
  final int amountPaidCents;
  final String status;
  final String? createdAt;

  AdminUserTicket({
    required this.id,
    required this.eventId,
    this.eventTitle,
    this.tierName,
    required this.amountPaidCents,
    required this.status,
    this.createdAt,
  });

  factory AdminUserTicket.fromJson(Map<String, dynamic> json) =>
      AdminUserTicket(
        id: json['id'] as int,
        eventId: (json['event_id'] as int?) ?? 0,
        eventTitle: json['event_title'] as String?,
        tierName: json['tier_name'] as String?,
        amountPaidCents: (json['amount_paid_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
      );
}

class AdminUserPledge {
  final int id;
  final int eventId;
  final String? eventTitle;
  final String? userDisplayName;
  final int amountCents;
  final String status;
  final bool isGuest;
  final int reservedSpots;
  final String? createdAt;

  AdminUserPledge({
    required this.id,
    required this.eventId,
    this.eventTitle,
    this.userDisplayName,
    required this.amountCents,
    required this.status,
    this.isGuest = false,
    this.reservedSpots = 0,
    this.createdAt,
  });

  factory AdminUserPledge.fromJson(Map<String, dynamic> json) =>
      AdminUserPledge(
        id: json['id'] as int,
        eventId: (json['event_id'] as int?) ?? 0,
        eventTitle: json['event_title'] as String?,
        userDisplayName: json['user_display_name'] as String?,
        amountCents: (json['amount_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        isGuest: (json['is_guest'] as bool?) ?? false,
        reservedSpots: (json['reserved_spots'] as int?) ?? 0,
        createdAt: json['created_at'] as String?,
      );
}

class AdminUserEvent {
  final int id;
  final String title;
  final String status;
  final int? organizerId;
  final String? description;
  final String? genre;
  final int? maxCapacity;
  final String? registrationType;
  final int registrationCount;
  final int? fundingGoalCents;
  final int minPledgeCents;
  final String? ticketStrategyName;
  final String? venueName;
  final String? venueAddress;
  final String? createdAt;
  final String? startTime;
  final String? endTime;
  final String? fundingEndAt;
  final bool hasSchedule;
  final bool communityRules;
  final int ticketTiersCount;
  final int sponsorshipCategoriesCount;
  final int milestonesCount;
  final int? userTicketCount;
  final int? userPledgeCount;
  final int? userPledgeTotalCents;
  final int? userReservedSpots;
  final int? userDonationCount;
  final int? userDonationTotalCents;
  final String? reviewNotes;
  final List<ReviewLogEntry> reviewLog;
  final PendingCancellation? pendingCancellation;
  final PendingExtension? pendingExtension;
  final List<String> validationWarnings;

  AdminUserEvent({
    required this.id,
    required this.title,
    required this.status,
    this.organizerId,
    this.description,
    this.genre,
    this.maxCapacity,
    this.registrationType,
    this.registrationCount = 0,
    this.fundingGoalCents,
    this.minPledgeCents = 0,
    this.ticketStrategyName,
    this.venueName,
    this.venueAddress,
    this.createdAt,
    this.startTime,
    this.endTime,
    this.fundingEndAt,
    this.hasSchedule = false,
    this.communityRules = false,
    this.ticketTiersCount = 0,
    this.sponsorshipCategoriesCount = 0,
    this.milestonesCount = 0,
    this.userTicketCount,
    this.userPledgeCount,
    this.userPledgeTotalCents,
    this.userReservedSpots,
    this.userDonationCount,
    this.userDonationTotalCents,
    this.reviewNotes,
    this.reviewLog = const [],
    this.pendingCancellation,
    this.pendingExtension,
    this.validationWarnings = const [],
  });

  factory AdminUserEvent.fromJson(Map<String, dynamic> json) => AdminUserEvent(
        id: json['id'] as int,
        title: (json['title'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        organizerId: json['organizer_id'] as int?,
        description: json['description'] as String?,
        genre: json['genre'] as String?,
        maxCapacity: json['max_capacity'] as int?,
        registrationType: json['registration_type'] as String?,
        registrationCount: (json['registration_count'] as int?) ?? 0,
        fundingGoalCents: json['funding_goal_cents'] as int?,
        minPledgeCents: (json['min_pledge_cents'] as int?) ?? 0,
        ticketStrategyName: json['ticket_strategy_name'] as String?,
        venueName: json['venue_name'] as String?,
        venueAddress: json['venue_address'] as String?,
        createdAt: json['created_at'] as String?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        fundingEndAt: json['funding_end_at'] as String?,
        hasSchedule: (json['has_schedule'] as bool?) ?? false,
        communityRules: (json['community_rules'] as bool?) ?? false,
        ticketTiersCount: (json['ticket_tiers_count'] as int?) ?? 0,
        sponsorshipCategoriesCount:
            (json['sponsorship_categories_count'] as int?) ?? 0,
        milestonesCount: (json['milestones_count'] as int?) ?? 0,
        userTicketCount: json['user_ticket_count'] as int?,
        userPledgeCount: json['user_pledge_count'] as int?,
        userPledgeTotalCents: json['user_pledge_total_cents'] as int?,
        userReservedSpots: json['user_reserved_spots'] as int?,
        userDonationCount: json['user_donation_count'] as int?,
        userDonationTotalCents: json['user_donation_total_cents'] as int?,
        reviewNotes: json['review_notes'] as String?,
        reviewLog: (json['review_log'] as List?)
                ?.map((e) => ReviewLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        pendingCancellation: json['pending_cancellation'] != null
            ? PendingCancellation.fromJson(Map<String, dynamic>.from(json['pending_cancellation'] as Map))
            : null,
        pendingExtension: json['pending_extension'] != null
            ? PendingExtension.fromJson(Map<String, dynamic>.from(json['pending_extension'] as Map))
            : null,
        validationWarnings: (json['validation_warnings'] as List?)
                ?.map((w) => w.toString())
                .toList() ??
            [],
      );
}

class AdminUserTicketSale {
  final int id;
  final int eventId;
  final String? eventTitle;
  final String? tierName;
  final int amountPaidCents;
  final String status;
  final String? createdAt;
  final String? attendeeDisplayName;

  AdminUserTicketSale({
    required this.id,
    required this.eventId,
    this.eventTitle,
    this.tierName,
    required this.amountPaidCents,
    required this.status,
    this.createdAt,
    this.attendeeDisplayName,
  });

  factory AdminUserTicketSale.fromJson(Map<String, dynamic> json) =>
      AdminUserTicketSale(
        id: json['id'] as int,
        eventId: (json['event_id'] as int?) ?? 0,
        eventTitle: json['event_title'] as String?,
        tierName: json['tier_name'] as String?,
        amountPaidCents: (json['amount_paid_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
        attendeeDisplayName: json['attendee_display_name'] as String?,
      );
}

class AdminUserSponsor {
  final int? sponsorUserId;
  final String? companyName;
  final String? contactName;
  final int totalBids;
  final int totalAmountCents;

  AdminUserSponsor({
    this.sponsorUserId,
    this.companyName,
    this.contactName,
    this.totalBids = 0,
    this.totalAmountCents = 0,
  });

  factory AdminUserSponsor.fromJson(Map<String, dynamic> json) =>
      AdminUserSponsor(
        sponsorUserId: json['sponsor_user_id'] as int?,
        companyName: json['company_name'] as String?,
        contactName: json['contact_name'] as String?,
        totalBids: (json['total_bids'] as int?) ?? 0,
        totalAmountCents: (json['total_amount_cents'] as int?) ?? 0,
      );
}

class AdminUserDiscount {
  final int? eventId;
  final String? eventTitle;
  final int? userId;
  final String? userDisplayName;
  final String discountType;
  final int value;

  AdminUserDiscount({
    this.eventId,
    this.eventTitle,
    this.userId,
    this.userDisplayName,
    required this.discountType,
    required this.value,
  });

  factory AdminUserDiscount.fromJson(Map<String, dynamic> json) =>
      AdminUserDiscount(
        eventId: json['event_id'] as int?,
        eventTitle: json['event_title'] as String?,
        userId: json['user_id'] as int?,
        userDisplayName: json['user_display_name'] as String?,
        discountType: (json['discount_type'] as String?) ?? '',
        value: (json['value'] as int?) ?? 0,
      );
}

class AdminUserEscrow {
  final int id;
  final int? eventId;
  final String? eventTitle;
  final String? organizerName;
  final String? organizerEmail;
  final int totalHeldCents;
  final int totalReleasedCents;
  final int remainingCents;
  final String status;
  final String? stage1ReleasedAt;
  final String? stage2ReleasedAt;
  final String? stage3ReleasedAt;

  AdminUserEscrow({
    required this.id,
    this.eventId,
    this.eventTitle,
    this.organizerName,
    this.organizerEmail,
    this.totalHeldCents = 0,
    this.totalReleasedCents = 0,
    this.remainingCents = 0,
    required this.status,
    this.stage1ReleasedAt,
    this.stage2ReleasedAt,
    this.stage3ReleasedAt,
  });

  factory AdminUserEscrow.fromJson(Map<String, dynamic> json) =>
      AdminUserEscrow(
        id: json['id'] as int,
        eventId: json['event_id'] as int?,
        eventTitle: json['event_title'] as String?,
        organizerName: json['organizer_name'] as String?,
        organizerEmail: json['organizer_email'] as String?,
        totalHeldCents: (json['total_held_cents'] as int?) ?? 0,
        totalReleasedCents: (json['total_released_cents'] as int?) ?? 0,
        remainingCents: (json['remaining_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        stage1ReleasedAt: json['stage1_released_at'] as String?,
        stage2ReleasedAt: json['stage2_released_at'] as String?,
        stage3ReleasedAt: json['stage3_released_at'] as String?,
      );
}

class AdminSponsorshipBid {
  final int bidId;
  final int categoryId;
  final String? categoryName;
  final int amountCents;
  final String status;
  final bool canRefund;

  AdminSponsorshipBid({
    required this.bidId,
    required this.categoryId,
    this.categoryName,
    this.amountCents = 0,
    this.status = '',
    this.canRefund = false,
  });

  factory AdminSponsorshipBid.fromJson(Map<String, dynamic> json) =>
      AdminSponsorshipBid(
        bidId: json['bid_id'] as int,
        categoryId: (json['category_id'] as int?) ?? 0,
        categoryName: json['category_name'] as String?,
        amountCents: (json['amount_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        canRefund: (json['can_refund'] as bool?) ?? false,
      );
}

class AdminSponsorshipEvent {
  final int eventId;
  final String? eventTitle;
  final List<AdminSponsorshipBid> bids;

  AdminSponsorshipEvent({
    required this.eventId,
    this.eventTitle,
    this.bids = const [],
  });

  factory AdminSponsorshipEvent.fromJson(Map<String, dynamic> json) =>
      AdminSponsorshipEvent(
        eventId: (json['event_id'] as int?) ?? 0,
        eventTitle: json['event_title'] as String?,
        bids: (json['bids'] as List?)
                ?.map((e) => AdminSponsorshipBid.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

// ─── Events ───

class AdminEventItem {
  final int id;
  final String title;
  final String status;
  final int? organizerId;
  final int? maxCapacity;
  final int? fundingGoalCents;
  final String? reviewNotes;
  final List<ReviewLogEntry> reviewLog;
  final String? cancellationReason;
  final PendingExtension? pendingExtension;
  final PendingCancellation? pendingCancellation;
  final String? createdAt;
  final String? startTime;
  final String? endTime;
  final String? fundingEndAt;
  final List<String> validationWarnings;

  AdminEventItem({
    required this.id,
    required this.title,
    required this.status,
    this.organizerId,
    this.maxCapacity,
    this.fundingGoalCents,
    this.reviewNotes,
    this.reviewLog = const [],
    this.cancellationReason,
    this.pendingExtension,
    this.pendingCancellation,
    this.createdAt,
    this.startTime,
    this.endTime,
    this.fundingEndAt,
    this.validationWarnings = const [],
  });

  factory AdminEventItem.fromJson(Map<String, dynamic> json) => AdminEventItem(
        id: json['id'] as int,
        title: (json['title'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        organizerId: json['organizer_id'] as int?,
        maxCapacity: json['max_capacity'] as int?,
        fundingGoalCents: json['funding_goal_cents'] as int?,
        reviewNotes: json['review_notes'] as String?,
        reviewLog: (json['review_log'] as List?)
                ?.map((e) => ReviewLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        cancellationReason: json['cancellation_reason'] as String?,
        pendingExtension: json['pending_extension'] != null
            ? PendingExtension.fromJson(Map<String, dynamic>.from(json['pending_extension'] as Map))
            : null,
        pendingCancellation: json['pending_cancellation'] != null
            ? PendingCancellation.fromJson(Map<String, dynamic>.from(json['pending_cancellation'] as Map))
            : null,
        createdAt: json['created_at'] as String?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        fundingEndAt: json['funding_end_at'] as String?,
        validationWarnings: (json['validation_warnings'] as List?)
                ?.map((w) => w.toString())
                .toList() ??
            [],
      );
}

// ─── Stats ───

class AdminStats {
  final int eventsTotal;
  final int eventsPending;
  final int eventsLive;
  final int usersTotal;
  final int totalTicketCommissionCents;
  final int totalFundingCommissionCents;
  final int totalEscrowHeldCents;

  AdminStats({
    this.eventsTotal = 0,
    this.eventsPending = 0,
    this.eventsLive = 0,
    this.usersTotal = 0,
    this.totalTicketCommissionCents = 0,
    this.totalFundingCommissionCents = 0,
    this.totalEscrowHeldCents = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        eventsTotal: (json['events_total'] as int?) ?? 0,
        eventsPending: (json['events_pending'] as int?) ?? 0,
        eventsLive: (json['events_live'] as int?) ?? 0,
        usersTotal: (json['users_total'] as int?) ?? 0,
        totalTicketCommissionCents:
            (json['total_ticket_commission_cents'] as int?) ?? 0,
        totalFundingCommissionCents:
            (json['total_funding_commission_cents'] as int?) ?? 0,
        totalEscrowHeldCents:
            (json['total_escrow_held_cents'] as int?) ?? 0,
      );
}

// ─── Dashboard ───

class AdminDashboard {
  final AdminDashboardKpis kpis;
  final AdminDashboardFilters availableFilters;
  final List<AdminGenreBreakdown> byGenre;
  final List<AdminStatusBreakdown> byStatus;
  final List<AdminEscrowBreakdown> byEscrowStatus;
  final List<AdminTimeSeriesPoint> timeSeries;
  final List<AdminTopEvent> topEvents;
  final AdminActionItems actionItems;

  AdminDashboard({
    required this.kpis,
    required this.availableFilters,
    this.byGenre = const [],
    this.byStatus = const [],
    this.byEscrowStatus = const [],
    this.timeSeries = const [],
    this.topEvents = const [],
    required this.actionItems,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
        kpis: AdminDashboardKpis.fromJson(
            Map<String, dynamic>.from((json['kpis'] as Map?) ?? {})),
        availableFilters: AdminDashboardFilters.fromJson(
            Map<String, dynamic>.from(
                (json['available_filters'] as Map?) ?? {})),
        byGenre: (json['by_genre'] as List?)
                ?.map((e) => AdminGenreBreakdown.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        byStatus: (json['by_status'] as List?)
                ?.map((e) => AdminStatusBreakdown.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        byEscrowStatus: (json['by_escrow_status'] as List?)
                ?.map((e) => AdminEscrowBreakdown.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        timeSeries: (json['time_series'] as List?)
                ?.map((e) => AdminTimeSeriesPoint.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        topEvents: (json['top_events'] as List?)
                ?.map((e) => AdminTopEvent.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        actionItems: AdminActionItems.fromJson(
            Map<String, dynamic>.from(
                (json['action_items'] as Map?) ?? {})),
      );
}

class AdminDashboardKpis {
  final int totalRevenueCents;
  final int ticketCommissionCents;
  final int fundingCommissionCents;
  final int totalTicketSalesCents;
  final int totalFundingCents;
  final int escrowHeldCents;
  final int escrowReleasedCents;
  final int ticketsSold;
  final int pledgesMade;
  final int eventsTotal;
  final int eventsLive;
  final int usersTotal;
  final int avgTicketPriceCents;
  final int avgFundingPerEventCents;
  final double refundRatePercent;
  final double fundingGoalHitRatePercent;

  AdminDashboardKpis({
    this.totalRevenueCents = 0,
    this.ticketCommissionCents = 0,
    this.fundingCommissionCents = 0,
    this.totalTicketSalesCents = 0,
    this.totalFundingCents = 0,
    this.escrowHeldCents = 0,
    this.escrowReleasedCents = 0,
    this.ticketsSold = 0,
    this.pledgesMade = 0,
    this.eventsTotal = 0,
    this.eventsLive = 0,
    this.usersTotal = 0,
    this.avgTicketPriceCents = 0,
    this.avgFundingPerEventCents = 0,
    this.refundRatePercent = 0.0,
    this.fundingGoalHitRatePercent = 0.0,
  });

  factory AdminDashboardKpis.fromJson(Map<String, dynamic> json) =>
      AdminDashboardKpis(
        totalRevenueCents: (json['total_revenue_cents'] as num?)?.toInt() ?? 0,
        ticketCommissionCents:
            (json['ticket_commission_cents'] as num?)?.toInt() ?? 0,
        fundingCommissionCents:
            (json['funding_commission_cents'] as num?)?.toInt() ?? 0,
        totalTicketSalesCents:
            (json['total_ticket_sales_cents'] as num?)?.toInt() ?? 0,
        totalFundingCents:
            (json['total_funding_cents'] as num?)?.toInt() ?? 0,
        escrowHeldCents: (json['escrow_held_cents'] as num?)?.toInt() ?? 0,
        escrowReleasedCents:
            (json['escrow_released_cents'] as num?)?.toInt() ?? 0,
        ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 0,
        pledgesMade: (json['pledges_made'] as num?)?.toInt() ?? 0,
        eventsTotal: (json['events_total'] as num?)?.toInt() ?? 0,
        eventsLive: (json['events_live'] as num?)?.toInt() ?? 0,
        usersTotal: (json['users_total'] as num?)?.toInt() ?? 0,
        avgTicketPriceCents:
            (json['avg_ticket_price_cents'] as num?)?.toInt() ?? 0,
        avgFundingPerEventCents:
            (json['avg_funding_per_event_cents'] as num?)?.toInt() ?? 0,
        refundRatePercent:
            (json['refund_rate_percent'] as num?)?.toDouble() ?? 0.0,
        fundingGoalHitRatePercent:
            (json['funding_goal_hit_rate_percent'] as num?)?.toDouble() ?? 0.0,
      );
}

class AdminDashboardFilters {
  final List<String> genres;
  final List<String> statuses;

  AdminDashboardFilters({this.genres = const [], this.statuses = const []});

  factory AdminDashboardFilters.fromJson(Map<String, dynamic> json) =>
      AdminDashboardFilters(
        genres: (json['genres'] as List?)?.cast<String>() ?? [],
        statuses: (json['statuses'] as List?)?.cast<String>() ?? [],
      );
}

class AdminGenreBreakdown {
  final String genre;
  final int events;
  final int revenueCents;
  final int tickets;
  final int fundingCents;

  AdminGenreBreakdown({
    required this.genre,
    this.events = 0,
    this.revenueCents = 0,
    this.tickets = 0,
    this.fundingCents = 0,
  });

  factory AdminGenreBreakdown.fromJson(Map<String, dynamic> json) =>
      AdminGenreBreakdown(
        genre: (json['genre'] as String?) ?? '',
        events: (json['events'] as num?)?.toInt() ?? 0,
        revenueCents: (json['revenue_cents'] as num?)?.toInt() ?? 0,
        tickets: (json['tickets'] as num?)?.toInt() ?? 0,
        fundingCents: (json['funding_cents'] as num?)?.toInt() ?? 0,
      );
}

class AdminStatusBreakdown {
  final String status;
  final int count;
  final int revenueCents;
  final int fundingCents;

  AdminStatusBreakdown({
    required this.status,
    this.count = 0,
    this.revenueCents = 0,
    this.fundingCents = 0,
  });

  factory AdminStatusBreakdown.fromJson(Map<String, dynamic> json) =>
      AdminStatusBreakdown(
        status: (json['status'] as String?) ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        revenueCents: (json['revenue_cents'] as num?)?.toInt() ?? 0,
        fundingCents: (json['funding_cents'] as num?)?.toInt() ?? 0,
      );
}

class AdminEscrowBreakdown {
  final String status;
  final int count;
  final int totalCents;

  AdminEscrowBreakdown({
    required this.status,
    this.count = 0,
    this.totalCents = 0,
  });

  factory AdminEscrowBreakdown.fromJson(Map<String, dynamic> json) =>
      AdminEscrowBreakdown(
        status: (json['status'] as String?) ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        totalCents: (json['total_cents'] as num?)?.toInt() ?? 0,
      );
}

class AdminTimeSeriesPoint {
  final String date;
  final int revenueCents;
  final int ticketsSold;
  final int pledgesCount;

  AdminTimeSeriesPoint({
    required this.date,
    this.revenueCents = 0,
    this.ticketsSold = 0,
    this.pledgesCount = 0,
  });

  factory AdminTimeSeriesPoint.fromJson(Map<String, dynamic> json) =>
      AdminTimeSeriesPoint(
        date: (json['date'] as String?) ?? '',
        revenueCents: (json['revenue_cents'] as num?)?.toInt() ?? 0,
        ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 0,
        pledgesCount: (json['pledges_count'] as num?)?.toInt() ?? 0,
      );
}

class AdminTopEvent {
  final int id;
  final String title;
  final String? genre;
  final String status;
  final int revenueCents;
  final int ticketsSold;
  final int fundingCents;

  AdminTopEvent({
    required this.id,
    required this.title,
    this.genre,
    required this.status,
    this.revenueCents = 0,
    this.ticketsSold = 0,
    this.fundingCents = 0,
  });

  factory AdminTopEvent.fromJson(Map<String, dynamic> json) => AdminTopEvent(
        id: json['id'] as int,
        title: (json['title'] as String?) ?? '',
        genre: json['genre'] as String?,
        status: (json['status'] as String?) ?? '',
        revenueCents: (json['revenue_cents'] as num?)?.toInt() ?? 0,
        ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 0,
        fundingCents: (json['funding_cents'] as num?)?.toInt() ?? 0,
      );
}

class AdminActionItems {
  final int pendingApproval;
  final int pendingCancellations;
  final int pendingExtensions;
  final int underReview;
  final int pendingRefunds;

  AdminActionItems({
    this.pendingApproval = 0,
    this.pendingCancellations = 0,
    this.pendingExtensions = 0,
    this.underReview = 0,
    this.pendingRefunds = 0,
  });

  factory AdminActionItems.fromJson(Map<String, dynamic> json) =>
      AdminActionItems(
        pendingApproval: (json['pending_approval'] as num?)?.toInt() ?? 0,
        pendingCancellations:
            (json['pending_cancellations'] as num?)?.toInt() ?? 0,
        pendingExtensions:
            (json['pending_extensions'] as num?)?.toInt() ?? 0,
        underReview: (json['under_review'] as num?)?.toInt() ?? 0,
        pendingRefunds: (json['pending_refunds'] as num?)?.toInt() ?? 0,
      );
}

// ─── Settings ───

class PlatformSetting {
  final String key;
  final String value;
  final String? description;

  PlatformSetting({
    required this.key,
    required this.value,
    this.description,
  });

  factory PlatformSetting.fromJson(Map<String, dynamic> json) =>
      PlatformSetting(
        key: (json['key'] as String?) ?? '',
        value: (json['value'] as String?) ?? '',
        description: json['description'] as String?,
      );
}

// ─── Escrows ───

class AdminEscrowItem {
  final int id;
  final int eventId;
  final String? eventTitle;
  final String? organizerName;
  final String? organizerEmail;
  final int totalHeldCents;
  final int totalReleasedCents;
  final int remainingCents;
  final String status;
  final int stage1ReleasedCents;
  final int stage2ReleasedCents;
  final int stage3ReleasedCents;
  final String? stage1ReleasedAt;
  final String? stage2ReleasedAt;
  final String? stage3ReleasedAt;
  final bool stage1AutoRelease;
  final bool stage2AutoRelease;
  final bool stage3AutoRelease;

  AdminEscrowItem({
    required this.id,
    required this.eventId,
    this.eventTitle,
    this.organizerName,
    this.organizerEmail,
    this.totalHeldCents = 0,
    this.totalReleasedCents = 0,
    this.remainingCents = 0,
    this.status = '',
    this.stage1ReleasedCents = 0,
    this.stage2ReleasedCents = 0,
    this.stage3ReleasedCents = 0,
    this.stage1ReleasedAt,
    this.stage2ReleasedAt,
    this.stage3ReleasedAt,
    this.stage1AutoRelease = false,
    this.stage2AutoRelease = false,
    this.stage3AutoRelease = false,
  });

  factory AdminEscrowItem.fromJson(Map<String, dynamic> json) =>
      AdminEscrowItem(
        id: (json['id'] as int?) ?? 0,
        eventId: (json['event_id'] as int?) ?? 0,
        eventTitle: json['event_title'] as String?,
        organizerName: json['organizer_name'] as String?,
        organizerEmail: json['organizer_email'] as String?,
        totalHeldCents: (json['total_held_cents'] as int?) ?? 0,
        totalReleasedCents: (json['total_released_cents'] as int?) ?? 0,
        remainingCents: (json['remaining_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        stage1ReleasedCents: (json['stage1_released_cents'] as int?) ?? 0,
        stage2ReleasedCents: (json['stage2_released_cents'] as int?) ?? 0,
        stage3ReleasedCents: (json['stage3_released_cents'] as int?) ?? 0,
        stage1ReleasedAt: json['stage1_released_at'] as String?,
        stage2ReleasedAt: json['stage2_released_at'] as String?,
        stage3ReleasedAt: json['stage3_released_at'] as String?,
        stage1AutoRelease: (json['stage1_auto_release'] as bool?) ?? false,
        stage2AutoRelease: (json['stage2_auto_release'] as bool?) ?? false,
        stage3AutoRelease: (json['stage3_auto_release'] as bool?) ?? false,
      );
}

class AdminEventEscrows {
  final int eventId;
  final AdminEscrowItem? fund;
  final AdminEscrowItem? ticket;
  final AdminEscrowItem? sponsor;

  AdminEventEscrows({
    required this.eventId,
    this.fund,
    this.ticket,
    this.sponsor,
  });

  factory AdminEventEscrows.fromJson(Map<String, dynamic> json) =>
      AdminEventEscrows(
        eventId: (json['event_id'] as int?) ?? 0,
        fund: json['fund'] != null
            ? AdminEscrowItem.fromJson(
                Map<String, dynamic>.from(json['fund'] as Map))
            : null,
        ticket: json['ticket'] != null
            ? AdminEscrowItem.fromJson(
                Map<String, dynamic>.from(json['ticket'] as Map))
            : null,
        sponsor: json['sponsor'] != null
            ? AdminEscrowItem.fromJson(
                Map<String, dynamic>.from(json['sponsor'] as Map))
            : null,
      );
}

// ─── Disputes ───

class AdminDispute {
  final int id;
  final String? stripeDisputeId;
  final int amountCents;
  final String? reason;
  final String status;
  final String? createdAt;

  AdminDispute({
    required this.id,
    this.stripeDisputeId,
    this.amountCents = 0,
    this.reason,
    this.status = '',
    this.createdAt,
  });

  factory AdminDispute.fromJson(Map<String, dynamic> json) => AdminDispute(
        id: json['id'] as int,
        stripeDisputeId: json['stripe_dispute_id'] as String?,
        amountCents: (json['amount_cents'] as int?) ?? 0,
        reason: json['reason'] as String?,
        status: (json['status'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
      );
}

// ─── Reconciliation & Ledger ───

class ReconciliationEntry {
  final int deltaCents;
  final String status;
  final String? runDate;

  ReconciliationEntry({
    this.deltaCents = 0,
    this.status = '',
    this.runDate,
  });

  factory ReconciliationEntry.fromJson(Map<String, dynamic> json) =>
      ReconciliationEntry(
        deltaCents: (json['delta_cents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? '',
        runDate: json['run_date'] as String?,
      );
}

class AdminLedgerHealth {
  final bool balanced;
  final int totalDebitsCents;
  final int totalCreditsCents;
  final Map<String, dynamic> accounts;

  AdminLedgerHealth({
    this.balanced = true,
    this.totalDebitsCents = 0,
    this.totalCreditsCents = 0,
    this.accounts = const {},
  });

  factory AdminLedgerHealth.fromJson(Map<String, dynamic> json) =>
      AdminLedgerHealth(
        balanced: (json['balanced'] as bool?) ?? true,
        totalDebitsCents: (json['total_debits_cents'] as int?) ?? 0,
        totalCreditsCents: (json['total_credits_cents'] as int?) ?? 0,
        accounts: json['accounts'] != null
            ? Map<String, dynamic>.from(json['accounts'] as Map)
            : {},
      );
}

// ─── Transactions ───

class AdminTransaction {
  final String? transactionId;
  final String operation;
  final String status;
  final int amountCents;
  final int feeCents;
  final String? fromAccount;
  final String? toAccount;
  final String? authorizationCode;
  final String? receiptReference;
  final String? description;
  final String? failureReason;
  final String? relatedType;
  final int? relatedId;
  final String? createdAt;
  final String? completedAt;

  AdminTransaction({
    this.transactionId,
    this.operation = '',
    this.status = '',
    this.amountCents = 0,
    this.feeCents = 0,
    this.fromAccount,
    this.toAccount,
    this.authorizationCode,
    this.receiptReference,
    this.description,
    this.failureReason,
    this.relatedType,
    this.relatedId,
    this.createdAt,
    this.completedAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) =>
      AdminTransaction(
        transactionId: json['transaction_id'] as String?,
        operation: (json['operation'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        amountCents: (json['amount_cents'] as int?) ?? 0,
        feeCents: (json['fee_cents'] as int?) ?? 0,
        fromAccount: json['from_account'] as String?,
        toAccount: json['to_account'] as String?,
        authorizationCode: json['authorization_code'] as String?,
        receiptReference: json['receipt_reference'] as String?,
        description: json['description'] as String?,
        failureReason: json['failure_reason'] as String?,
        relatedType: json['related_type'] as String?,
        relatedId: json['related_id'] as int?,
        createdAt: json['created_at'] as String?,
        completedAt: json['completed_at'] as String?,
      );
}

// ─── Payouts ───

class AdminPayoutItem {
  final int organizerId;
  final String? organizerName;
  final String? organizerEmail;
  final bool hasBankAccount;
  final String? bankStatus;
  final int pendingPayoutCents;
  final int pendingAmountCents;
  final String? payoutSchedule;
  final String? nextPayoutDate;

  AdminPayoutItem({
    required this.organizerId,
    this.organizerName,
    this.organizerEmail,
    this.hasBankAccount = false,
    this.bankStatus,
    this.pendingPayoutCents = 0,
    this.pendingAmountCents = 0,
    this.payoutSchedule,
    this.nextPayoutDate,
  });

  factory AdminPayoutItem.fromJson(Map<String, dynamic> json) =>
      AdminPayoutItem(
        organizerId: (json['organizer_id'] as int?) ?? 0,
        organizerName: json['organizer_name'] as String?,
        organizerEmail: json['organizer_email'] as String?,
        hasBankAccount: (json['has_bank_account'] as bool?) ?? false,
        bankStatus: json['bank_status'] as String?,
        pendingPayoutCents: (json['pending_payout_cents'] as int?) ?? 0,
        pendingAmountCents: (json['pending_amount_cents'] as int?) ?? 0,
        payoutSchedule: json['payout_schedule'] as String?,
        nextPayoutDate: json['next_payout_date'] as String?,
      );
}

// ─── Platform Account ───

class AdminPlatformAccount {
  final Map<String, dynamic> raw;

  AdminPlatformAccount({required this.raw});

  factory AdminPlatformAccount.fromJson(Map<String, dynamic> json) =>
      AdminPlatformAccount(raw: json);

  dynamic operator [](String key) => raw[key];
}

// ─── Banking Overview ───

class AdminBankingOverview {
  final bool mockModeActive;
  final bool stripeEnabled;
  final bool stripeConnectEnabled;
  final bool platformAccountConfigured;
  final String? platformAccountInstitution;
  final String? platformAccountTransit;
  final String? platformAccountLastFour;
  final int disputesOpenCount;
  final int disputesTotalAmountCents;
  final int fundEscrowTotalHeldCents;
  final int fundEscrowActiveCount;
  final int ticketEscrowTotalHeldCents;
  final int ticketEscrowActiveCount;
  final int sponsorEscrowTotalHeldCents;
  final int sponsorEscrowActiveCount;
  final int commissionTotalCents;
  final int taxCollectedTotalCents;
  final Map<String, dynamic> commissionBySource;
  final int payoutPendingCount;
  final int payoutPendingTotalCents;
  final int transactionTotalCount;
  final int transactionSettledCount;
  final int transactionPendingCount;
  final int transactionFailedCount;
  final String? lastReconciliationStatus;
  final int lastReconciliationDeltaCents;

  AdminBankingOverview({
    this.mockModeActive = false,
    this.stripeEnabled = false,
    this.stripeConnectEnabled = false,
    this.platformAccountConfigured = false,
    this.platformAccountInstitution,
    this.platformAccountTransit,
    this.platformAccountLastFour,
    this.disputesOpenCount = 0,
    this.disputesTotalAmountCents = 0,
    this.fundEscrowTotalHeldCents = 0,
    this.fundEscrowActiveCount = 0,
    this.ticketEscrowTotalHeldCents = 0,
    this.ticketEscrowActiveCount = 0,
    this.sponsorEscrowTotalHeldCents = 0,
    this.sponsorEscrowActiveCount = 0,
    this.commissionTotalCents = 0,
    this.taxCollectedTotalCents = 0,
    this.commissionBySource = const {},
    this.payoutPendingCount = 0,
    this.payoutPendingTotalCents = 0,
    this.transactionTotalCount = 0,
    this.transactionSettledCount = 0,
    this.transactionPendingCount = 0,
    this.transactionFailedCount = 0,
    this.lastReconciliationStatus,
    this.lastReconciliationDeltaCents = 0,
  });

  factory AdminBankingOverview.fromJson(Map<String, dynamic> json) =>
      AdminBankingOverview(
        mockModeActive: (json['mock_mode_active'] as bool?) ?? false,
        stripeEnabled: (json['stripe_enabled'] as bool?) ?? false,
        stripeConnectEnabled:
            (json['stripe_connect_enabled'] as bool?) ?? false,
        platformAccountConfigured:
            (json['platform_account_configured'] as bool?) ?? false,
        platformAccountInstitution:
            json['platform_account_institution'] as String?,
        platformAccountTransit:
            json['platform_account_transit'] as String?,
        platformAccountLastFour:
            json['platform_account_last_four'] as String?,
        disputesOpenCount: (json['disputes_open_count'] as int?) ?? 0,
        disputesTotalAmountCents:
            (json['disputes_total_amount_cents'] as int?) ?? 0,
        fundEscrowTotalHeldCents:
            (json['fund_escrow_total_held_cents'] as int?) ?? 0,
        fundEscrowActiveCount:
            (json['fund_escrow_active_count'] as int?) ?? 0,
        ticketEscrowTotalHeldCents:
            (json['ticket_escrow_total_held_cents'] as int?) ?? 0,
        ticketEscrowActiveCount:
            (json['ticket_escrow_active_count'] as int?) ?? 0,
        sponsorEscrowTotalHeldCents:
            (json['sponsor_escrow_total_held_cents'] as int?) ?? 0,
        sponsorEscrowActiveCount:
            (json['sponsor_escrow_active_count'] as int?) ?? 0,
        commissionTotalCents:
            (json['commission_total_cents'] as int?) ?? 0,
        taxCollectedTotalCents:
            (json['tax_collected_total_cents'] as int?) ?? 0,
        commissionBySource: json['commission_by_source'] != null
            ? Map<String, dynamic>.from(json['commission_by_source'] as Map)
            : {},
        payoutPendingCount: (json['payout_pending_count'] as int?) ?? 0,
        payoutPendingTotalCents:
            (json['payout_pending_total_cents'] as int?) ?? 0,
        transactionTotalCount:
            (json['transaction_total_count'] as int?) ?? 0,
        transactionSettledCount:
            (json['transaction_settled_count'] as int?) ?? 0,
        transactionPendingCount:
            (json['transaction_pending_count'] as int?) ?? 0,
        transactionFailedCount:
            (json['transaction_failed_count'] as int?) ?? 0,
        lastReconciliationStatus:
            json['last_reconciliation_status'] as String?,
        lastReconciliationDeltaCents:
            (json['last_reconciliation_delta_cents'] as int?) ?? 0,
      );
}

// ─── Audit Log ───

class AdminAuditEntry {
  final int id;
  final int adminId;
  final String action;
  final String targetType;
  final int targetId;
  final Map<String, dynamic> details;
  final String? createdAt;

  AdminAuditEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.details = const {},
    this.createdAt,
  });

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) =>
      AdminAuditEntry(
        id: json['id'] as int,
        adminId: (json['admin_id'] as int?) ?? 0,
        action: (json['action'] as String?) ?? '',
        targetType: (json['target_type'] as String?) ?? '',
        targetId: (json['target_id'] as int?) ?? 0,
        details: json['details'] != null
            ? Map<String, dynamic>.from(json['details'] as Map)
            : {},
        createdAt: json['created_at'] as String?,
      );
}

// ─── Workers (ARQ) ───

class AdminWorkerTask {
  final String taskName;
  final bool enabled;
  final String settingKey;
  final int totalRuns;
  final int totalErrors;
  final String? lastRunAt;
  final String? lastStatus;

  AdminWorkerTask({
    required this.taskName,
    this.enabled = false,
    this.settingKey = '',
    this.totalRuns = 0,
    this.totalErrors = 0,
    this.lastRunAt,
    this.lastStatus,
  });

  factory AdminWorkerTask.fromJson(Map<String, dynamic> json) =>
      AdminWorkerTask(
        taskName: (json['task_name'] as String?) ?? '',
        enabled: (json['enabled'] as bool?) ?? false,
        settingKey: (json['setting_key'] as String?) ?? '',
        totalRuns: (json['total_runs'] as int?) ?? 0,
        totalErrors: (json['total_errors'] as int?) ?? 0,
        lastRunAt: json['last_run_at'] as String?,
        lastStatus: json['last_status'] as String?,
      );
}

class AdminWorkerSummary {
  final List<AdminWorkerTask> tasks;

  AdminWorkerSummary({this.tasks = const []});

  factory AdminWorkerSummary.fromJson(Map<String, dynamic> json) =>
      AdminWorkerSummary(
        tasks: (json['tasks'] as List?)
                ?.map((e) => AdminWorkerTask.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

class AdminWorkerRun {
  final int id;
  final String taskName;
  final String status;
  final int durationMs;
  final int itemsProcessed;
  final String? error;
  final String? startedAt;
  final String? finishedAt;

  AdminWorkerRun({
    required this.id,
    required this.taskName,
    required this.status,
    this.durationMs = 0,
    this.itemsProcessed = 0,
    this.error,
    this.startedAt,
    this.finishedAt,
  });

  factory AdminWorkerRun.fromJson(Map<String, dynamic> json) => AdminWorkerRun(
        id: json['id'] as int,
        taskName: (json['task_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        durationMs: (json['duration_ms'] as int?) ?? 0,
        itemsProcessed: (json['items_processed'] as int?) ?? 0,
        error: json['error'] as String?,
        startedAt: json['started_at'] as String?,
        finishedAt: json['finished_at'] as String?,
      );
}

// ─── Email Templates ───

class EmailTemplate {
  final String key;
  final String subject;
  final String bodyHtml;
  final bool isActive;
  final bool isCustomized;
  final List<String> variables;

  EmailTemplate({
    required this.key,
    this.subject = '',
    this.bodyHtml = '',
    this.isActive = true,
    this.isCustomized = false,
    this.variables = const [],
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) => EmailTemplate(
        key: (json['template_key'] as String?) ??
            (json['key'] as String?) ??
            '',
        subject: (json['subject'] as String?) ?? '',
        bodyHtml: (json['body_html'] as String?) ?? '',
        isActive: (json['is_active'] as bool?) ?? true,
        isCustomized: (json['is_customized'] as bool?) ?? false,
        variables: (json['variables'] as List?)?.cast<String>() ?? [],
      );
}

// ─── Mock Overview ───

class AdminMockTransaction {
  final String operation;
  final String status;
  final int amountCents;
  final String? fromAccount;
  final String? toAccount;
  final String? failureReason;
  final String? authorizationCode;

  AdminMockTransaction({
    this.operation = '',
    this.status = '',
    this.amountCents = 0,
    this.fromAccount,
    this.toAccount,
    this.failureReason,
    this.authorizationCode,
  });

  factory AdminMockTransaction.fromJson(Map<String, dynamic> json) =>
      AdminMockTransaction(
        operation: (json['operation'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        amountCents: (json['amount_cents'] as int?) ?? 0,
        fromAccount: json['from_account'] as String?,
        toAccount: json['to_account'] as String?,
        failureReason: json['failure_reason'] as String?,
        authorizationCode: json['authorization_code'] as String?,
      );
}

class AdminMockEmail {
  final String status;
  final String? subject;
  final String? toEmail;
  final String? templateKey;

  AdminMockEmail({
    this.status = '',
    this.subject,
    this.toEmail,
    this.templateKey,
  });

  factory AdminMockEmail.fromJson(Map<String, dynamic> json) =>
      AdminMockEmail(
        status: (json['status'] as String?) ?? '',
        subject: json['subject'] as String?,
        toEmail: json['to_email'] as String?,
        templateKey: json['template_key'] as String?,
      );
}

class AdminMockOverview {
  final bool mockModeActive;
  final int totalTransactions;
  final int totalVolumeCents;
  final double successRate;
  final int totalEmails;
  final double emailBounceRate;
  final String? lastTransactionAt;
  final String? lastEmailAt;
  final List<AdminMockTransaction> recentTransactions;
  final List<AdminMockEmail> recentEmails;

  AdminMockOverview({
    this.mockModeActive = false,
    this.totalTransactions = 0,
    this.totalVolumeCents = 0,
    this.successRate = 0.0,
    this.totalEmails = 0,
    this.emailBounceRate = 0.0,
    this.lastTransactionAt,
    this.lastEmailAt,
    this.recentTransactions = const [],
    this.recentEmails = const [],
  });

  factory AdminMockOverview.fromJson(Map<String, dynamic> json) =>
      AdminMockOverview(
        mockModeActive: (json['mock_mode_active'] as bool?) ?? false,
        totalTransactions: (json['total_transactions'] as int?) ?? 0,
        totalVolumeCents: (json['total_volume_cents'] as int?) ?? 0,
        successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
        totalEmails: (json['total_emails'] as int?) ?? 0,
        emailBounceRate:
            (json['email_bounce_rate'] as num?)?.toDouble() ?? 0.0,
        lastTransactionAt: json['last_transaction_at'] as String?,
        lastEmailAt: json['last_email_at'] as String?,
        recentTransactions: (json['recent_transactions'] as List?)
                ?.map((e) => AdminMockTransaction.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        recentEmails: (json['recent_emails'] as List?)
                ?.map((e) => AdminMockEmail.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

// ─── Policy Overrides ───

class AdminPolicyOverrides {
  final Map<String, dynamic> effective;

  AdminPolicyOverrides({required this.effective});

  factory AdminPolicyOverrides.fromJson(Map<String, dynamic> json) =>
      AdminPolicyOverrides(
        effective: json['effective'] != null
            ? Map<String, dynamic>.from(json['effective'] as Map)
            : Map<String, dynamic>.from(json),
      );

  dynamic operator [](String key) => effective[key];
}

// ─── Request Classes ───

/// Typed request for POST /admin/events/:id/approve.
class ApproveEventRequest {
  final bool approved;
  final String? reason;

  const ApproveEventRequest({
    required this.approved,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'approved': approved,
    };
    if (reason != null) json['reason'] = reason;
    return json;
  }
}

/// Typed request for PATCH /admin/events/:id/policy-overrides.
/// All fields are nullable — null values are sent as null to clear overrides.
class SetPolicyOverridesRequest {
  final int? waitlistMaxSize;
  final int? eventMaxImages;
  final int? maxPostsPerDay;
  final int? maxCoOrganizers;
  final int? refundDeadlinePercent;

  const SetPolicyOverridesRequest({
    this.waitlistMaxSize,
    this.eventMaxImages,
    this.maxPostsPerDay,
    this.maxCoOrganizers,
    this.refundDeadlinePercent,
  });

  Map<String, dynamic> toJson() => {
        'admin_override_waitlist_max_size': waitlistMaxSize,
        'admin_override_event_max_images': eventMaxImages,
        'admin_override_max_posts_per_day': maxPostsPerDay,
        'admin_override_max_co_organizers': maxCoOrganizers,
        'admin_override_refund_deadline_percent': refundDeadlinePercent,
      };
}

/// Typed request for PUT /admin/platform-account.
class UpdatePlatformAccountRequest {
  final String institutionNumber;
  final String transitNumber;
  final String accountNumber;
  final String accountHolder;

  const UpdatePlatformAccountRequest({
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    required this.accountHolder,
  });

  Map<String, dynamic> toJson() => {
        'institution_number': institutionNumber,
        'transit_number': transitNumber,
        'account_number': accountNumber,
        'account_holder': accountHolder,
      };
}
