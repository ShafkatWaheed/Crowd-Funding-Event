// Organizer dashboard models for KPIs, time series, and customer history.

import 'event.dart';

class KpiItem {
  final int value;
  final double? deltaPercent;

  KpiItem({required this.value, this.deltaPercent});

  factory KpiItem.fromJson(Map<String, dynamic> json) => KpiItem(
        value: (json['value'] as int?) ?? 0,
        deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
      );
}

class KpiFloatItem {
  final double value;
  final double? deltaPercent;

  KpiFloatItem({required this.value, this.deltaPercent});

  factory KpiFloatItem.fromJson(Map<String, dynamic> json) => KpiFloatItem(
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
      );
}

class StatusBreakdown {
  final String status;
  final int count;

  StatusBreakdown({required this.status, required this.count});

  factory StatusBreakdown.fromJson(Map<String, dynamic> json) =>
      StatusBreakdown(
        status: json['status'] as String,
        count: (json['count'] as int?) ?? 0,
      );
}

class ActivityFeedItem {
  final String type;
  final int eventId;
  final String eventTitle;
  final String actorName;
  final int amountCents;
  final Map<String, dynamic>? extra;
  final DateTime createdAt;

  ActivityFeedItem({
    required this.type,
    required this.eventId,
    required this.eventTitle,
    required this.actorName,
    required this.amountCents,
    this.extra,
    required this.createdAt,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) =>
      ActivityFeedItem(
        type: json['type'] as String,
        eventId: json['event_id'] as int,
        eventTitle: (json['event_title'] as String?) ?? '',
        actorName: (json['actor_name'] as String?) ?? '',
        amountCents: (json['amount_cents'] as int?) ?? 0,
        extra: json['extra'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class OrganizerDashboard {
  final KpiItem totalRevenue;
  final KpiItem ticketsSold;
  final KpiItem totalBackers;
  final KpiItem totalEvents;
  final KpiItem totalSponsors;
  final KpiFloatItem refundRate;
  final List<StatusBreakdown> statusBreakdown;
  final List<Event> topEvents;
  final List<Event> trendingEvents;
  final List<Event> popularEvents;
  final List<ActivityFeedItem> recentActivity;

  OrganizerDashboard({
    required this.totalRevenue,
    required this.ticketsSold,
    required this.totalBackers,
    required this.totalEvents,
    required this.totalSponsors,
    required this.refundRate,
    this.statusBreakdown = const [],
    this.topEvents = const [],
    this.trendingEvents = const [],
    this.popularEvents = const [],
    this.recentActivity = const [],
  });

  factory OrganizerDashboard.fromJson(Map<String, dynamic> json) {
    List<Event> parseEvents(dynamic val) => (val as List?)
            ?.map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return OrganizerDashboard(
      totalRevenue: KpiItem.fromJson(
          Map<String, dynamic>.from(json['total_revenue'] as Map)),
      ticketsSold: KpiItem.fromJson(
          Map<String, dynamic>.from(json['tickets_sold'] as Map)),
      totalBackers: KpiItem.fromJson(
          Map<String, dynamic>.from(json['total_backers'] as Map)),
      totalEvents: KpiItem.fromJson(
          Map<String, dynamic>.from(json['total_events'] as Map)),
      totalSponsors: KpiItem.fromJson(
          Map<String, dynamic>.from(json['total_sponsors'] as Map)),
      refundRate: KpiFloatItem.fromJson(
          Map<String, dynamic>.from(json['refund_rate'] as Map)),
      statusBreakdown: (json['status_breakdown'] as List?)
              ?.map((e) => StatusBreakdown.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      topEvents: parseEvents(json['top_events']),
      trendingEvents: parseEvents(json['trending_events']),
      popularEvents: parseEvents(json['popular_events']),
      recentActivity: (json['recent_activity'] as List?)
              ?.map((e) => ActivityFeedItem.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }
}

class TimeSeriesPoint {
  final String date;
  final int revenueCents;
  final int ticketsSold;
  final int pledgesCount;

  TimeSeriesPoint({
    required this.date,
    required this.revenueCents,
    required this.ticketsSold,
    required this.pledgesCount,
  });

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) =>
      TimeSeriesPoint(
        date: json['date'] as String,
        revenueCents: (json['revenue_cents'] as int?) ?? 0,
        ticketsSold: (json['tickets_sold'] as int?) ?? 0,
        pledgesCount: (json['pledges_count'] as int?) ?? 0,
      );
}

class OrganizerTimeSeries {
  final List<TimeSeriesPoint> points;
  final String granularity;

  OrganizerTimeSeries({required this.points, required this.granularity});

  factory OrganizerTimeSeries.fromJson(Map<String, dynamic> json) =>
      OrganizerTimeSeries(
        points: (json['points'] as List?)
                ?.map((e) => TimeSeriesPoint.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        granularity: (json['granularity'] as String?) ?? 'daily',
      );
}

class CustomerHistoryItem {
  final int customerId;
  final String? customerName;
  final int eventId;
  final String? eventTitle;
  final String? scannedAt;
  final int eventsAttended;

  CustomerHistoryItem({
    required this.customerId,
    this.customerName,
    required this.eventId,
    this.eventTitle,
    this.scannedAt,
    required this.eventsAttended,
  });

  factory CustomerHistoryItem.fromJson(Map<String, dynamic> json) =>
      CustomerHistoryItem(
        customerId: json['customer_id'] as int,
        customerName: json['customer_name'] as String?,
        eventId: json['event_id'] as int,
        eventTitle: json['event_title'] as String?,
        scannedAt: json['scanned_at'] as String?,
        eventsAttended: (json['events_attended'] as int?) ?? 0,
      );
}
