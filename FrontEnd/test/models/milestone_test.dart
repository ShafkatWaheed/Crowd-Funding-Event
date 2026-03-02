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
}
