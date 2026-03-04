import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/event.dart';
import '../../lib/models/venue.dart';
import '../helpers/fixtures.dart';

void main() {
  group('Event', () {
    test('fromJson parses all required fields', () {
      final json = eventJson(
        id: 5,
        title: 'Music Fest',
        status: 'approved',
        maxCapacity: 300,
      );
      final event = Event.fromJson(json);

      expect(event.id, 5);
      expect(event.title, 'Music Fest');
      expect(event.status, EventStatus.approved);
      expect(event.maxCapacity, 300);
      expect(event.organizerId, 10);
      expect(event.venueId, 1);
    });

    test('status enum parsing with all values', () {
      for (final s in EventStatus.values) {
        final json = eventJson(status: s.name);
        final event = Event.fromJson(json);
        expect(event.status, s);
      }
    });

    test('unknown status falls back to draft', () {
      final json = eventJson(status: 'nonexistent_status');
      final event = Event.fromJson(json);
      expect(event.status, EventStatus.draft);
    });

    test('registrationType enum parsing', () {
      final open = Event.fromJson(eventJson(registrationType: 'open'));
      expect(open.registrationType, RegistrationType.open);

      final closed = Event.fromJson(eventJson(registrationType: 'closed'));
      expect(closed.registrationType, RegistrationType.closed);
    });

    test('nullable date fields', () {
      final json = eventJson(startTime: null, endTime: null, fundingEndAt: null);
      final event = Event.fromJson(json);
      expect(event.startTime, isNull);
      expect(event.endTime, isNull);
      expect(event.fundingEndAt, isNull);
    });

    test('date parsing works correctly', () {
      final json = eventJson(
        startTime: '2025-06-15T18:00:00',
        endTime: '2025-06-15T23:00:00',
        fundingEndAt: '2025-05-01T00:00:00',
      );
      final event = Event.fromJson(json);
      expect(event.startTime, DateTime.parse('2025-06-15T18:00:00'));
      expect(event.endTime, DateTime.parse('2025-06-15T23:00:00'));
      expect(event.fundingEndAt, DateTime.parse('2025-05-01T00:00:00'));
    });

    test('nested venue parsed when present', () {
      final json = eventJson(venue: venueJson(name: 'Arena'));
      final event = Event.fromJson(json);
      expect(event.venue, isNotNull);
      expect(event.venue!.name, 'Arena');
    });

    test('venue is null when not provided', () {
      final json = eventJson(venue: null);
      final event = Event.fromJson(json);
      expect(event.venue, isNull);
    });

    test('fundingProgress computed correctly', () {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: 100000,
        totalPledgedCents: 50000,
      ));
      expect(event.fundingProgress, 0.5);
    });

    test('fundingProgress zero when goal is null', () {
      final event = Event.fromJson(eventJson(fundingGoalCents: null));
      expect(event.fundingProgress, 0.0);
    });

    test('fundingProgress zero when goal is zero', () {
      final event = Event.fromJson(eventJson(fundingGoalCents: 0));
      expect(event.fundingProgress, 0.0);
    });

    test('fundingGoalFormatted', () {
      final event = Event.fromJson(eventJson(fundingGoalCents: 100000));
      expect(event.fundingGoalFormatted, '\$1000.00');
    });

    test('fundingGoalFormatted N/A when null', () {
      final event = Event.fromJson(eventJson(fundingGoalCents: null));
      expect(event.fundingGoalFormatted, 'N/A');
    });

    test('totalPledgedFormatted', () {
      final event = Event.fromJson(eventJson(totalPledgedCents: 75000));
      expect(event.totalPledgedFormatted, '\$750.00');
    });

    test('canPledge when approved with funding end date', () {
      final event = Event.fromJson(eventJson(
        status: 'approved',
        fundingEndAt: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      ));
      expect(event.canPledge, true);
    });

    test('canPledge false when not approved', () {
      final event = Event.fromJson(eventJson(status: 'draft'));
      expect(event.canPledge, false);
    });

    test('isFunding when goal and end date set and future', () {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: 100000,
        fundingEndAt: DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      ));
      expect(event.isFunding, true);
    });

    test('isFunding false when funding ended', () {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: 100000,
        fundingEndAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      ));
      expect(event.isFunding, false);
    });

    test('ageRestricted and minAge', () {
      final event = Event.fromJson(eventJson(ageRestricted: true, minAge: 21));
      expect(event.ageRestricted, true);
      expect(event.minAge, 21);
    });

    test('hasTransportInfo', () {
      final json = eventJson();
      json['parking_info'] = 'Free parking available';
      final event = Event.fromJson(json);
      expect(event.hasTransportInfo, true);

      final noTransport = Event.fromJson(eventJson());
      expect(noTransport.hasTransportInfo, false);
    });

    test('viewerIsCoOrganizer and viewerHasFullCoOrganizerAccess', () {
      final json = eventJson();
      json['viewer_co_organizer_permission'] = 'full';
      final event = Event.fromJson(json);
      expect(event.viewerIsCoOrganizer, true);
      expect(event.viewerHasFullCoOrganizerAccess, true);
    });

    test('fundingTimeLeftFormatted', () {
      // Test "Ended" case
      final ended = Event.fromJson(eventJson(
        fundingEndAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      ));
      expect(ended.fundingTimeLeftFormatted, 'Ended');

      // Test empty case
      final noEnd = Event.fromJson(eventJson(fundingEndAt: null));
      expect(noEnd.fundingTimeLeftFormatted, '');
    });
  });

  group('ReactionResult', () {
    test('fromJson parses all fields', () {
      final r = ReactionResult.fromJson({
        'action': 'added',
        'reaction': 'like',
        'like_count': 10,
        'dislike_count': 2,
      });
      expect(r.action, 'added');
      expect(r.reaction, 'like');
      expect(r.likeCount, 10);
      expect(r.dislikeCount, 2);
    });

    test('defaults for null fields', () {
      final r = ReactionResult.fromJson({});
      expect(r.action, '');
      expect(r.reaction, '');
      expect(r.likeCount, 0);
      expect(r.dislikeCount, 0);
    });
  });

  group('FeaturedEvents', () {
    test('fromJson parses all categories', () {
      final json = {
        'trending': [eventJson(id: 1, title: 'Trending')],
        'popular': [eventJson(id: 2, title: 'Popular')],
        'coming_soon': [eventJson(id: 3, title: 'Coming Soon')],
      };
      final f = FeaturedEvents.fromJson(json);

      expect(f.trending.length, 1);
      expect(f.trending[0].title, 'Trending');
      expect(f.popular.length, 1);
      expect(f.popular[0].title, 'Popular');
      expect(f.comingSoon.length, 1);
      expect(f.comingSoon[0].title, 'Coming Soon');
    });

    test('empty lists when not provided', () {
      final f = FeaturedEvents.fromJson({});
      expect(f.trending, isEmpty);
      expect(f.popular, isEmpty);
      expect(f.comingSoon, isEmpty);
    });
  });

  group('EventListPage', () {
    test('fromJson parses items and nextCursor', () {
      final json = {
        'items': [eventJson(id: 1), eventJson(id: 2)],
        'next_cursor': 'abc123',
      };
      final page = EventListPage.fromJson(json);

      expect(page.items.length, 2);
      expect(page.items[0].id, 1);
      expect(page.items[1].id, 2);
      expect(page.nextCursor, 'abc123');
    });

    test('null nextCursor when not provided', () {
      final page = EventListPage.fromJson({'items': []});
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('null items list defaults to empty', () {
      final page = EventListPage.fromJson({});
      expect(page.items, isEmpty);
    });
  });

  group('EventOrganizer', () {
    test('fromJson parses all fields', () {
      final json = {
        'user_id': 5,
        'display_name': 'Alice',
        'email': 'alice@test.com',
        'is_main': true,
        'permission': 'full',
        'invitation_status': 'accepted',
      };
      final o = EventOrganizer.fromJson(json);

      expect(o.userId, 5);
      expect(o.displayName, 'Alice');
      expect(o.email, 'alice@test.com');
      expect(o.isMain, true);
      expect(o.permission, 'full');
      expect(o.invitationStatus, 'accepted');
    });

    test('defaults for optional fields', () {
      final json = {'user_id': 6};
      final o = EventOrganizer.fromJson(json);

      expect(o.displayName, isNull);
      expect(o.email, '');
      expect(o.isMain, false);
      expect(o.permission, 'read');
      expect(o.invitationStatus, 'pending');
    });
  });

  group('OrganizerSearchResult', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 10,
        'email': 'organizer@test.com',
        'display_name': 'Bob',
      };
      final r = OrganizerSearchResult.fromJson(json);

      expect(r.id, 10);
      expect(r.email, 'organizer@test.com');
      expect(r.displayName, 'Bob');
    });

    test('defaults for optional fields', () {
      final json = {'id': 11};
      final r = OrganizerSearchResult.fromJson(json);

      expect(r.email, '');
      expect(r.displayName, isNull);
    });
  });

  group('Registration', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 1,
        'event_id': 5,
        'user_id': 10,
        'status': 'approved',
        'created_at': '2025-02-01T10:00:00',
      };
      final reg = Registration.fromJson(json);

      expect(reg.id, 1);
      expect(reg.eventId, 5);
      expect(reg.userId, 10);
      expect(reg.status, 'approved');
      expect(reg.createdAt, DateTime.parse('2025-02-01T10:00:00'));
    });

    test('status defaults to empty string', () {
      final json = {
        'id': 2,
        'event_id': 3,
        'user_id': 4,
        'created_at': '2025-02-01T10:00:00',
      };
      final reg = Registration.fromJson(json);
      expect(reg.status, '');
    });
  });

  group('CapacityInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'max_capacity': 500,
        'tickets_sold': 200,
        'total_reserved_spots': 50,
        'occupied': 250,
        'available': 250,
        'registration_count': 30,
      };
      final c = CapacityInfo.fromJson(json);

      expect(c.maxCapacity, 500);
      expect(c.ticketsSold, 200);
      expect(c.totalReservedSpots, 50);
      expect(c.occupied, 250);
      expect(c.available, 250);
      expect(c.registrationCount, 30);
    });

    test('defaults to 0 when fields are null', () {
      final c = CapacityInfo.fromJson({});

      expect(c.maxCapacity, 0);
      expect(c.ticketsSold, 0);
      expect(c.totalReservedSpots, 0);
      expect(c.occupied, 0);
      expect(c.available, 0);
      expect(c.registrationCount, 0);
    });
  });
}
