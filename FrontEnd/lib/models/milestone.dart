class FundingMilestone {
  final int id;
  final int eventId;
  final String title;
  final String? description;
  final int unlockPercent;
  final String? benefitDescription;
  final int sortOrder;
  final int likeCount;
  final int dislikeCount;
  final bool isUnlocked;
  final DateTime createdAt;

  FundingMilestone({
    required this.id,
    required this.eventId,
    required this.title,
    this.description,
    required this.unlockPercent,
    this.benefitDescription,
    this.sortOrder = 0,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.isUnlocked = false,
    required this.createdAt,
  });

  factory FundingMilestone.fromJson(Map<String, dynamic> json) {
    return FundingMilestone(
      id: json['id'],
      eventId: json['event_id'],
      title: json['title'],
      description: json['description'],
      unlockPercent: json['unlock_percent'],
      benefitDescription: json['benefit_description'],
      sortOrder: json['sort_order'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
      isUnlocked: json['is_unlocked'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class MilestoneSnapshot {
  final int id;
  final int eventId;
  final int milestonePercent;
  final DateTime reachedAt;
  final int userCount;

  MilestoneSnapshot({
    required this.id,
    required this.eventId,
    required this.milestonePercent,
    required this.reachedAt,
    required this.userCount,
  });

  factory MilestoneSnapshot.fromJson(Map<String, dynamic> json) =>
      MilestoneSnapshot(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        milestonePercent: json['milestone_percent'] as int,
        reachedAt: DateTime.parse(json['reached_at'] as String),
        userCount: (json['user_count'] as int?) ?? 0,
      );
}

class MilestoneReactionStatus {
  final String? reaction;
  final int totalLikes;
  final int totalDislikes;

  MilestoneReactionStatus({
    this.reaction,
    this.totalLikes = 0,
    this.totalDislikes = 0,
  });

  factory MilestoneReactionStatus.fromJson(Map<String, dynamic> json) =>
      MilestoneReactionStatus(
        reaction: json['reaction'] as String?,
        totalLikes: (json['total_likes'] as int?) ?? 0,
        totalDislikes: (json['total_dislikes'] as int?) ?? 0,
      );
}

class MilestoneRequest {
  final String title;
  final String? benefitDescription;
  final int unlockPercent;

  const MilestoneRequest({
    required this.title,
    this.benefitDescription,
    required this.unlockPercent,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'unlock_percent': unlockPercent,
        if (benefitDescription != null && benefitDescription!.isNotEmpty)
          'benefit_description': benefitDescription,
      };
}
