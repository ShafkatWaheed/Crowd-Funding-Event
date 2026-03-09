import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/models/event.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockEventRepository mockRepo;
  late EventProvider provider;

  setUpAll(() {
    registerFallbackValue(const EventCreateRequest(venueId: 0, title: '', maxCapacity: 0));
    registerFallbackValue(const EventUpdateRequest());
    registerFallbackValue(const EventFilters());
  });

  setUp(() {
    mockRepo = MockEventRepository();
    provider = EventProvider(mockRepo);
  });

  group('EventProvider', () {
    test('initial state', () {
      expect(provider.events, isEmpty);
      expect(provider.selectedEvent, isNull);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.hasMore, true);
    });

    test('loadEvents success', () async {
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [Event.fromJson(eventJson(id: 1)), Event.fromJson(eventJson(id: 2))],
            nextCursor: null,
          ));

      await provider.loadEvents();

      expect(provider.events.length, 2);
      expect(provider.events[0].id, 1);
      expect(provider.events[1].id, 2);
      expect(provider.isLoading, false);
      expect(provider.hasMore, false);
      expect(provider.error, isNull);
    });

    test('loadEvents with filters', () async {
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [Event.fromJson(eventJson(id: 1, genre: 'music'))],
            nextCursor: null,
          ));

      await provider.loadEvents(filters: const EventFilters(genre: 'music'));

      expect(provider.events.length, 1);
    });

    test('loadEvents error sets error message', () async {
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenThrow(Exception('Network error'));

      await provider.loadEvents();

      expect(provider.error, isNotNull);
      expect(provider.isLoading, false);
    });

    test('loadMoreEvents appends items', () async {
      // First load
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [Event.fromJson(eventJson(id: 1))],
            nextCursor: 'cursor-1',
          ));
      await provider.loadEvents();
      expect(provider.events.length, 1);
      expect(provider.hasMore, true);

      // Load more
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [Event.fromJson(eventJson(id: 2))],
            nextCursor: null,
          ));
      await provider.loadMoreEvents();

      expect(provider.events.length, 2);
      expect(provider.hasMore, false);
    });

    test('loadMoreEvents noop when not hasMore', () async {
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [],
            nextCursor: null,
          ));
      await provider.loadEvents();

      await provider.loadMoreEvents();
      // Should not call API again since hasMore is false
      verify(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).called(1); // Only the loadEvents call
    });

    test('loadMoreEvents noop when already loading more — prevents duplicate requests',
        () async {
      // Prime the provider with a first page that has more items
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(
            items: [Event.fromJson(eventJson(id: 1))],
            nextCursor: 'cursor-1',
          ));
      await provider.loadEvents();
      expect(provider.hasMore, true);

      // Second page is slow — returns a completer so the first loadMoreEvents
      // call is still in-flight when we attempt a second call.
      final slowPage = Completer<EventListPage>();
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) => slowPage.future);

      // Start first loadMoreEvents (still in-flight)
      final firstLoad = provider.loadMoreEvents();

      // Second loadMoreEvents while first is still running — must be ignored
      await provider.loadMoreEvents();

      // Complete the slow page and settle
      slowPage.complete(EventListPage(
        items: [Event.fromJson(eventJson(id: 2))],
        nextCursor: null,
      ));
      await firstLoad;

      // getEvents was called: once for loadEvents + once for the single loadMoreEvents
      verify(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).called(2);

      // Only 2 items — second loadMoreEvents was silently skipped
      expect(provider.events.length, 2);
    });

    test('loadEvent success', () async {
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1, title: 'Test Event')));

      await provider.loadEvent(1);

      expect(provider.selectedEvent, isNotNull);
      expect(provider.selectedEvent!.id, 1);
      expect(provider.selectedEvent!.title, 'Test Event');
    });

    test('loadEvent uses cache on second call', () async {
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1)));

      await provider.loadEvent(1);
      await provider.loadEvent(1); // Should use cache

      verify(() => mockRepo.getEvent(1)).called(1); // Only called once
    });

    test('loadEvent forceRefresh bypasses cache', () async {
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1)));

      await provider.loadEvent(1);
      await provider.loadEvent(1, forceRefresh: true);

      verify(() => mockRepo.getEvent(1)).called(2);
    });

    test('loadEvent error sets error', () async {
      when(() => mockRepo.getEvent(1)).thenThrow(Exception('Not found'));

      await provider.loadEvent(1);

      expect(provider.error, isNotNull);
      expect(provider.selectedEvent, isNull);
    });

    test('createEvent success', () async {
      when(() => mockRepo.createEvent(any()))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 99)));
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(items: [], nextCursor: null));

      final result = await provider.createEvent(const EventCreateRequest(venueId: 1, title: 'New Event', maxCapacity: 100));
      expect(result, true);
    });

    test('createEvent failure returns false', () async {
      when(() => mockRepo.createEvent(any()))
          .thenThrow(Exception('Validation error'));

      final result = await provider.createEvent(const EventCreateRequest(venueId: 1, title: '', maxCapacity: 100));
      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('publishEvent success', () async {
      when(() => mockRepo.publishEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1, status: 'pending_approval')));
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1, status: 'pending_approval')));

      final result = await provider.publishEvent(1);
      expect(result, true);
    });

    test('deleteEvent success clears selected', () async {
      when(() => mockRepo.deleteEvent(1)).thenAnswer((_) async => {});
      when(() => mockRepo.getEvents(
            filters: any(named: 'filters'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => EventListPage(items: [], nextCursor: null));

      // Set selected event first
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1)));
      await provider.loadEvent(1);
      expect(provider.selectedEvent, isNotNull);

      final result = await provider.deleteEvent(1);
      expect(result, true);
      expect(provider.selectedEvent, isNull);
    });

    test('invalidateCache removes entry', () async {
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1)));

      await provider.loadEvent(1);
      provider.invalidateCache(1);

      // Next call should hit API since cache was invalidated
      await provider.loadEvent(1);
      verify(() => mockRepo.getEvent(1)).called(2);
    });

    test('clearCache removes all entries', () async {
      when(() => mockRepo.getEvent(any()))
          .thenAnswer((inv) async => Event.fromJson(eventJson(id: inv.positionalArguments[0] as int)));

      await provider.loadEvent(1);
      await provider.loadEvent(2);
      provider.clearCache();

      await provider.loadEvent(1);
      await provider.loadEvent(2);

      verify(() => mockRepo.getEvent(1)).called(2);
      verify(() => mockRepo.getEvent(2)).called(2);
    });

    test('clearSelected sets selectedEvent to null', () async {
      when(() => mockRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(id: 1)));
      await provider.loadEvent(1);
      expect(provider.selectedEvent, isNotNull);

      provider.clearSelected();
      expect(provider.selectedEvent, isNull);
    });
  });
}
