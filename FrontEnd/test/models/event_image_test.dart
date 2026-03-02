import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/event_image.dart';
import '../helpers/fixtures.dart';

void main() {
  group('EventImage', () {
    test('fromJson parses all fields', () {
      final json = eventImageJson(
        id: 3,
        eventId: 7,
        imageUrl: 'https://cdn.example.com/photo.jpg',
        caption: 'Stage setup',
        displayOrder: 2,
      );
      final img = EventImage.fromJson(json);

      expect(img.id, 3);
      expect(img.eventId, 7);
      expect(img.imageUrl, 'https://cdn.example.com/photo.jpg');
      expect(img.caption, 'Stage setup');
      expect(img.displayOrder, 2);
      expect(img.createdAt, isNotNull);
    });

    test('nullable caption', () {
      final json = eventImageJson(caption: null);
      final img = EventImage.fromJson(json);
      expect(img.caption, isNull);
    });

    test('defaults for missing fields', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'created_at': '2025-01-01T00:00:00',
      };
      final img = EventImage.fromJson(json);
      expect(img.imageUrl, '');
      expect(img.displayOrder, 0);
    });
  });
}
