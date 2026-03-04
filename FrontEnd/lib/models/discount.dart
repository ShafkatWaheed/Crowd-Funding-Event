// Discount models for event discounts, strategies, and claimable discounts.

// ─── Discount Request Models ───

class CreateEventDiscountRequest {
  final String name;
  final String discountType;
  final int value;
  final String target;
  final int? milestonePercent;
  final int? milestoneDiscountValue;

  const CreateEventDiscountRequest({
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
    this.milestonePercent,
    this.milestoneDiscountValue,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'discount_type': discountType,
        'value': value,
        'target': target,
        if (milestonePercent != null) 'milestone_percent': milestonePercent,
        if (milestoneDiscountValue != null) 'milestone_discount_value': milestoneDiscountValue,
      };
}

class CreateDiscountStrategyRequest {
  final String name;
  final String discountType;
  final int value;
  final String target;

  const CreateDiscountStrategyRequest({
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'discount_type': discountType,
        'value': value,
        'target': target,
      };
}

class CreateEarlyBirdDiscountRequest {
  final String appliesTo;
  final String discountType;
  final int value;
  final String? windowStart;
  final String windowEnd;

  const CreateEarlyBirdDiscountRequest({
    required this.appliesTo,
    required this.discountType,
    required this.value,
    this.windowStart,
    required this.windowEnd,
  });

  Map<String, dynamic> toJson() => {
        'applies_to': appliesTo,
        'discount_type': discountType,
        'value': value,
        if (windowStart != null) 'window_start': windowStart,
        'window_end': windowEnd,
      };
}

class UpdateEarlyBirdDiscountRequest {
  final String? windowEnd;
  final String? discountType;
  final int? value;

  const UpdateEarlyBirdDiscountRequest({
    this.windowEnd,
    this.discountType,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        if (windowEnd != null) 'window_end': windowEnd,
        if (discountType != null) 'discount_type': discountType,
        if (value != null) 'value': value,
      };
}

class EventDiscount {
  final int id;
  final int eventId;
  final String name;
  final String discountType;
  final int value;
  final String target;
  final int? milestonePercent;
  final int? milestoneDiscountValue;
  final DateTime createdAt;

  EventDiscount({
    required this.id,
    required this.eventId,
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
    this.milestonePercent,
    this.milestoneDiscountValue,
    required this.createdAt,
  });

  factory EventDiscount.fromJson(Map<String, dynamic> json) => EventDiscount(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        name: json['name'] as String,
        discountType: json['discount_type'] as String,
        value: json['value'] as int,
        target: json['target'] as String,
        milestonePercent: json['milestone_percent'] as int?,
        milestoneDiscountValue: json['milestone_discount_value'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class UserDiscount {
  final int discountId;
  final String discountType;
  final int value;
  final String target;

  UserDiscount({
    required this.discountId,
    required this.discountType,
    required this.value,
    required this.target,
  });

  factory UserDiscount.fromJson(Map<String, dynamic> json) => UserDiscount(
        discountId: json['discount_id'] as int,
        discountType: json['discount_type'] as String,
        value: json['value'] as int,
        target: json['target'] as String,
      );
}

class MyDiscounts {
  final List<UserDiscount> availableDiscounts;

  MyDiscounts({required this.availableDiscounts});

  factory MyDiscounts.fromJson(Map<String, dynamic> json) => MyDiscounts(
        availableDiscounts: (json['available_discounts'] as List?)
                ?.map((e) =>
                    UserDiscount.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

class DiscountStrategy {
  final int id;
  final int organizerId;
  final String name;
  final String discountType;
  final int value;
  final String target;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscountStrategy({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiscountStrategy.fromJson(Map<String, dynamic> json) =>
      DiscountStrategy(
        id: json['id'] as int,
        organizerId: json['organizer_id'] as int,
        name: json['name'] as String,
        discountType: json['discount_type'] as String,
        value: json['value'] as int,
        target: json['target'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class EventDiscountStrategy {
  final int id;
  final String name;
  final String discountType;
  final int value;
  final String target;
  final bool autoApply;

  EventDiscountStrategy({
    required this.id,
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
    required this.autoApply,
  });

  factory EventDiscountStrategy.fromJson(Map<String, dynamic> json) =>
      EventDiscountStrategy(
        id: json['id'] as int,
        name: json['name'] as String,
        discountType: json['discount_type'] as String,
        value: json['value'] as int,
        target: json['target'] as String,
        autoApply: (json['auto_apply'] as bool?) ?? false,
      );
}

class ClaimableDiscount {
  final int linkId;
  final int strategyId;
  final String name;
  final String discountType;
  final int value;
  final String target;
  final bool claimed;

  ClaimableDiscount({
    required this.linkId,
    required this.strategyId,
    required this.name,
    required this.discountType,
    required this.value,
    required this.target,
    required this.claimed,
  });

  factory ClaimableDiscount.fromJson(Map<String, dynamic> json) =>
      ClaimableDiscount(
        linkId: json['link_id'] as int,
        strategyId: json['strategy_id'] as int,
        name: json['name'] as String,
        discountType: json['discount_type'] as String,
        value: json['value'] as int,
        target: json['target'] as String,
        claimed: (json['claimed'] as bool?) ?? false,
      );
}

class EarlyBirdDiscount {
  final int id;
  final int eventId;
  final String discountType;
  final int value;
  final String target;
  final bool autoApply;
  final bool isActive;
  final String? startsAt;
  final String? endsAt;

  EarlyBirdDiscount({
    required this.id,
    required this.eventId,
    required this.discountType,
    required this.value,
    required this.target,
    this.autoApply = true,
    this.isActive = false,
    this.startsAt,
    this.endsAt,
  });

  factory EarlyBirdDiscount.fromJson(Map<String, dynamic> json) =>
      EarlyBirdDiscount(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        discountType: (json['discount_type'] as String?) ?? '',
        value: (json['value'] as int?) ?? 0,
        target: (json['target'] as String?) ?? 'all',
        autoApply: (json['auto_apply'] as bool?) ?? true,
        isActive: (json['is_active'] as bool?) ?? false,
        startsAt: json['starts_at'] as String?,
        endsAt: json['ends_at'] as String?,
      );
}
