import 'venue.dart';

// ignore_for_file: constant_identifier_names
enum EventStatus { draft, pending_approval, approved, live, ended, cancelled }

enum RegistrationType { open, closed }

class Event {
  final int id;
  final int organizerId;
  final int venueId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
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
  final Venue? venue;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.organizerId,
    required this.venueId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
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
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
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
}
