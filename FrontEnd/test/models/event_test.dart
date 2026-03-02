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
}
