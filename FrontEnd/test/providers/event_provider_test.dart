import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/models/event.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockApiService mockApi;
  late EventProvider provider;

  setUp(() {
    mockApi = MockApiService();
    provider = EventProvider(mockApi);
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
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {
            'items': [eventJson(id: 1), eventJson(id: 2)],
            'next_cursor': null,
          });

      await provider.loadEvents();

      expect(provider.events.length, 2);
      expect(provider.events[0].id, 1);
      expect(provider.events[1].id, 2);
      expect(provider.isLoading, false);
      expect(provider.hasMore, false);
      expect(provider.error, isNull);
    });

    test('loadEvents with filters', () async {
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {
            'items': [eventJson(id: 1, genre: 'music')],
            'next_cursor': null,
          });

      await provider.loadEvents(filters: {'genre': 'music'});

      expect(provider.events.length, 1);
    });

    test('loadEvents error sets error message', () async {
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenThrow(Exception('Network error'));

      await provider.loadEvents();

      expect(provider.error, isNotNull);
      expect(provider.isLoading, false);
    });

    test('loadMoreEvents appends items', () async {
      // First load
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {
            'items': [eventJson(id: 1)],
            'next_cursor': 'cursor-1',
          });
      await provider.loadEvents();
      expect(provider.events.length, 1);
      expect(provider.hasMore, true);

      // Load more
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {
            'items': [eventJson(id: 2)],
            'next_cursor': null,
          });
      await provider.loadMoreEvents();

      expect(provider.events.length, 2);
      expect(provider.hasMore, false);
    });

    test('loadMoreEvents noop when not hasMore', () async {
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {
            'items': [],
            'next_cursor': null,
          });
      await provider.loadEvents();

      await provider.loadMoreEvents();
      // Should not call API again since hasMore is false
      verify(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).called(1); // Only the loadEvents call
    });

    test('loadEvent success', () async {
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1, title: 'Test Event'));

      await provider.loadEvent(1);

      expect(provider.selectedEvent, isNotNull);
      expect(provider.selectedEvent!.id, 1);
      expect(provider.selectedEvent!.title, 'Test Event');
    });

    test('loadEvent uses cache on second call', () async {
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1));

      await provider.loadEvent(1);
      await provider.loadEvent(1); // Should use cache

      verify(() => mockApi.getEvent(1)).called(1); // Only called once
    });

    test('loadEvent forceRefresh bypasses cache', () async {
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1));

      await provider.loadEvent(1);
      await provider.loadEvent(1, forceRefresh: true);

      verify(() => mockApi.getEvent(1)).called(2);
    });

    test('loadEvent error sets error', () async {
      when(() => mockApi.getEvent(1)).thenThrow(Exception('Not found'));

      await provider.loadEvent(1);

      expect(provider.error, isNotNull);
      expect(provider.selectedEvent, isNull);
    });

    test('createEvent success', () async {
      when(() => mockApi.createEvent(any()))
          .thenAnswer((_) async => eventJson(id: 99));
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {'items': [], 'next_cursor': null});

      final result = await provider.createEvent({'title': 'New Event'});
      expect(result, true);
    });

    test('createEvent failure returns false', () async {
      when(() => mockApi.createEvent(any()))
          .thenThrow(Exception('Validation error'));

      final result = await provider.createEvent({'title': ''});
      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('publishEvent success', () async {
      when(() => mockApi.publishEvent(1)).thenAnswer((_) async => {});
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1, status: 'pending_approval'));

      final result = await provider.publishEvent(1);
      expect(result, true);
    });

    test('deleteEvent success clears selected', () async {
      when(() => mockApi.deleteEvent(1)).thenAnswer((_) async => {});
      when(() => mockApi.getEvents(
            params: any(named: 'params'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => {'items': [], 'next_cursor': null});

      // Set selected event first
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1));
      await provider.loadEvent(1);
      expect(provider.selectedEvent, isNotNull);

      final result = await provider.deleteEvent(1);
      expect(result, true);
      expect(provider.selectedEvent, isNull);
    });

    test('invalidateCache removes entry', () async {
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1));

      await provider.loadEvent(1);
      provider.invalidateCache(1);

      // Next call should hit API since cache was invalidated
      await provider.loadEvent(1);
      verify(() => mockApi.getEvent(1)).called(2);
    });

    test('clearCache removes all entries', () async {
      when(() => mockApi.getEvent(any()))
          .thenAnswer((inv) async => eventJson(id: inv.positionalArguments[0] as int));

      await provider.loadEvent(1);
      await provider.loadEvent(2);
      provider.clearCache();

      await provider.loadEvent(1);
      await provider.loadEvent(2);

      verify(() => mockApi.getEvent(1)).called(2);
      verify(() => mockApi.getEvent(2)).called(2);
    });

    test('clearSelected sets selectedEvent to null', () async {
      when(() => mockApi.getEvent(1))
          .thenAnswer((_) async => eventJson(id: 1));
      await provider.loadEvent(1);
      expect(provider.selectedEvent, isNotNull);

      provider.clearSelected();
      expect(provider.selectedEvent, isNull);
    });
  });
}
