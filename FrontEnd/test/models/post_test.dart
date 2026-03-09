import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/post.dart';
import '../helpers/fixtures.dart';

void main() {
  group('EventPost', () {
    test('fromJson parses all fields', () {
      final json = eventPostJson(
        id: 5,
        eventId: 3,
        userId: 10,
        authorName: 'Alice',
        content: 'Exciting update about the venue!',
      );
      final post = EventPost.fromJson(json);

      expect(post.id, 5);
      expect(post.eventId, 3);
      expect(post.userId, 10);
      expect(post.authorName, 'Alice');
      expect(post.content, 'Exciting update about the venue!');
      expect(post.createdAt, isNotNull);
    });

    test('nullable authorName', () {
      final json = eventPostJson(authorName: null);
      final post = EventPost.fromJson(json);
      expect(post.authorName, isNull);
    });

    test('content defaults to empty string', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'user_id': 1,
        'created_at': '2025-01-01T00:00:00',
      };
      final post = EventPost.fromJson(json);
      expect(post.content, '');
    });

    test('createdAt parsed correctly', () {
      final post = EventPost.fromJson(
        eventPostJson(createdAt: '2025-06-20T16:45:00'),
      );
      expect(post.createdAt, DateTime.parse('2025-06-20T16:45:00'));
    });
  });
}
