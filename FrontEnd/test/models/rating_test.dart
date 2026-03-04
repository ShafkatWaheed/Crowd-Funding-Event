import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/rating.dart';

void main() {
  group('Rating', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'rater_name': 'Alice',
        'direction': 'attendee_to_event',
        'stars': 5,
        'description': 'Great event!',
        'created_at': '2025-03-01T10:00:00',
      };
      final r = Rating.fromJson(json);

      expect(r.id, 1);
      expect(r.raterName, 'Alice');
      expect(r.direction, 'attendee_to_event');
      expect(r.stars, 5);
      expect(r.description, 'Great event!');
      expect(r.createdAt, '2025-03-01T10:00:00');
    });

    test('defaults for optional/null fields', () {
      final json = {'id': 2};
      final r = Rating.fromJson(json);

      expect(r.id, 2);
      expect(r.raterName, 'Anonymous');
      expect(r.direction, '');
      expect(r.stars, 0);
      expect(r.description, isNull);
      expect(r.createdAt, isNull);
    });
  });

  group('MyRating', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 10,
        'stars': 4,
        'description': 'Good experience',
      };
      final r = MyRating.fromJson(json);

      expect(r.id, 10);
      expect(r.stars, 4);
      expect(r.description, 'Good experience');
    });

    test('defaults for optional fields', () {
      final json = {'id': 11};
      final r = MyRating.fromJson(json);

      expect(r.id, 11);
      expect(r.stars, 0);
      expect(r.description, isNull);
    });
  });

  group('RatingsSummary', () {
    test('fromJson parses all fields with reviews', () {
      final json = {
        'avg_stars': 4.5,
        'count': 20,
        'top_reviews': [
          {'id': 1, 'rater_name': 'Alice', 'direction': 'attendee_to_event', 'stars': 5},
          {'id': 2, 'rater_name': 'Bob', 'direction': 'attendee_to_event', 'stars': 5},
        ],
        'worst_reviews': [
          {'id': 3, 'rater_name': 'Charlie', 'direction': 'attendee_to_event', 'stars': 1},
        ],
        'my_rating': {'id': 10, 'stars': 4, 'description': 'Solid'},
        'my_organizer_rating': {'id': 11, 'stars': 3},
      };
      final s = RatingsSummary.fromJson(json);

      expect(s.avgStars, 4.5);
      expect(s.count, 20);
      expect(s.topReviews.length, 2);
      expect(s.topReviews[0].raterName, 'Alice');
      expect(s.worstReviews.length, 1);
      expect(s.worstReviews[0].stars, 1);
      expect(s.myRating, isNotNull);
      expect(s.myRating!.stars, 4);
      expect(s.myRating!.description, 'Solid');
      expect(s.myOrganizerRating, isNotNull);
      expect(s.myOrganizerRating!.stars, 3);
    });

    test('defaults when optional fields missing', () {
      final json = <String, dynamic>{
        'count': 0,
      };
      final s = RatingsSummary.fromJson(json);

      expect(s.avgStars, isNull);
      expect(s.count, 0);
      expect(s.topReviews, isEmpty);
      expect(s.worstReviews, isEmpty);
      expect(s.myRating, isNull);
      expect(s.myOrganizerRating, isNull);
    });

    test('avgStars handles int value', () {
      final json = {'avg_stars': 4, 'count': 5};
      final s = RatingsSummary.fromJson(json);
      expect(s.avgStars, 4.0);
    });
  });
}
