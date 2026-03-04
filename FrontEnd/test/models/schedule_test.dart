import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/schedule.dart';
import '../helpers/fixtures.dart';

void main() {
  group('ScheduleItem', () {
    test('fromJson parses all fields', () {
      final json = scheduleItemJson(
        id: 3,
        eventId: 5,
        date: '2025-06-15',
        startTime: '14:00',
        endTime: '15:30',
        title: 'Keynote Speech',
        description: 'Opening keynote by CEO',
      );
      final item = ScheduleItem.fromJson(json);

      expect(item.id, 3);
      expect(item.eventId, 5);
      expect(item.date, '2025-06-15');
      expect(item.startTime, '14:00');
      expect(item.endTime, '15:30');
      expect(item.title, 'Keynote Speech');
      expect(item.description, 'Opening keynote by CEO');
      expect(item.createdAt, isNotNull);
    });

    test('defaults for optional fields', () {
      final json = {
        'id': 1,
        'event_id': 1,
        'date': '2025-01-01',
        'start_time': '09:00',
        'end_time': '10:00',
        'title': 'Test',
        'created_at': '2025-01-01T00:00:00',
      };
      final item = ScheduleItem.fromJson(json);
      expect(item.description, isNull);
      expect(item.imageUrl, isNull);
      expect(item.imageCaption, isNull);
      expect(item.linkUrl, isNull);
      expect(item.sortOrder, 0);
      expect(item.overlaps, false);
    });

    test('overlaps flag', () {
      final json = scheduleItemJson();
      json['overlaps'] = true;
      final item = ScheduleItem.fromJson(json);
      expect(item.overlaps, true);
    });
  });

  group('ScheduleDay', () {
    test('fromJson parses date and items list', () {
      final json = {
        'date': '2025-06-15',
        'items': [
          scheduleItemJson(id: 1, title: 'Morning Session'),
          scheduleItemJson(id: 2, title: 'Afternoon Session'),
        ],
      };
      final day = ScheduleDay.fromJson(json);
      expect(day.date, '2025-06-15');
      expect(day.items.length, 2);
      expect(day.items[0].title, 'Morning Session');
      expect(day.items[1].title, 'Afternoon Session');
    });
  });

  // ─── ScheduleImageResult ───

  group('ScheduleImageResult', () {
    test('fromJson parses all fields with url key', () {
      final json = {
        'url': 'https://storage.example.com/schedule/img.jpg',
        'caption': 'Stage setup photo',
      };
      final r = ScheduleImageResult.fromJson(json);

      expect(r.url, 'https://storage.example.com/schedule/img.jpg');
      expect(r.caption, 'Stage setup photo');
    });

    test('fromJson falls back to image_url key', () {
      final json = {
        'image_url': 'https://storage.example.com/schedule/alt.jpg',
        'caption': 'Alt photo',
      };
      final r = ScheduleImageResult.fromJson(json);
      expect(r.url, 'https://storage.example.com/schedule/alt.jpg');
      expect(r.caption, 'Alt photo');
    });

    test('all fields nullable', () {
      final r = ScheduleImageResult.fromJson({});
      expect(r.url, isNull);
      expect(r.caption, isNull);
    });
  });
}
