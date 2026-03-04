import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/milestone.dart';
import '../helpers/fixtures.dart';

void main() {
  group('FundingMilestone', () {
    test('fromJson parses all fields', () {
      final json = milestoneJson(
        id: 3,
        eventId: 5,
        title: '75% Funded',
        description: 'Almost there!',
        unlockPercent: 75,
        benefitDescription: 'VIP access',
        isUnlocked: true,
      );
      final ms = FundingMilestone.fromJson(json);

      expect(ms.id, 3);
      expect(ms.eventId, 5);
      expect(ms.title, '75% Funded');
      expect(ms.description, 'Almost there!');
      expect(ms.unlockPercent, 75);
      expect(ms.benefitDescription, 'VIP access');
      expect(ms.isUnlocked, true);
      expect(ms.createdAt, isNotNull);
    });

    test('defaults for optional fields', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'title': 'Test',
        'unlock_percent': 50,
        'created_at': '2025-01-01T00:00:00',
      };
      final ms = FundingMilestone.fromJson(json);
      expect(ms.description, isNull);
      expect(ms.benefitDescription, isNull);
      expect(ms.sortOrder, 0);
      expect(ms.likeCount, 0);
      expect(ms.dislikeCount, 0);
      expect(ms.isUnlocked, false);
    });

    test('likeCount and dislikeCount', () {
      final json = milestoneJson();
      json['like_count'] = 42;
      json['dislike_count'] = 5;
      final ms = FundingMilestone.fromJson(json);
      expect(ms.likeCount, 42);
      expect(ms.dislikeCount, 5);
    });
  });

  group('MilestoneSnapshot', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'event_id': 5,
        'milestone_percent': 50,
        'reached_at': '2025-02-15T12:00:00',
        'user_count': 25,
      };
      final snap = MilestoneSnapshot.fromJson(json);

      expect(snap.id, 1);
      expect(snap.eventId, 5);
      expect(snap.milestonePercent, 50);
      expect(snap.reachedAt, DateTime.parse('2025-02-15T12:00:00'));
      expect(snap.userCount, 25);
    });

    test('userCount defaults to 0 when null', () {
      final json = {
        'id': 2,
        'event_id': 3,
        'milestone_percent': 75,
        'reached_at': '2025-03-01T08:00:00',
      };
      final snap = MilestoneSnapshot.fromJson(json);
      expect(snap.userCount, 0);
    });
  });

  group('MilestoneRequest', () {
    test('toJson includes all fields', () {
      final r = MilestoneRequest(
        title: 'Halfway',
        benefitDescription: 'Free drink',
        unlockPercent: 50,
      );
      final json = r.toJson();
      expect(json['title'], 'Halfway');
      expect(json['unlock_percent'], 50);
      expect(json['benefit_description'], 'Free drink');
    });

    test('toJson omits empty benefit', () {
      final r = MilestoneRequest(title: 'Test', unlockPercent: 25);
      final json = r.toJson();
      expect(json.containsKey('benefit_description'), false);
    });
  });

  group('MilestoneReactionStatus', () {
    test('fromJson parses all fields', () {
      final r = MilestoneReactionStatus.fromJson({
        'reaction': 'like',
        'total_likes': 15,
        'total_dislikes': 3,
      });
      expect(r.reaction, 'like');
      expect(r.totalLikes, 15);
      expect(r.totalDislikes, 3);
    });

    test('reaction null when not provided', () {
      final r = MilestoneReactionStatus.fromJson({});
      expect(r.reaction, isNull);
      expect(r.totalLikes, 0);
      expect(r.totalDislikes, 0);
    });

    test('dislike reaction', () {
      final r = MilestoneReactionStatus.fromJson({
        'reaction': 'dislike',
        'total_likes': 5,
        'total_dislikes': 10,
      });
      expect(r.reaction, 'dislike');
      expect(r.totalLikes, 5);
      expect(r.totalDislikes, 10);
    });
  });
}
