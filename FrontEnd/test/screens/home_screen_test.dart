/// Widget tests for HomeScreen — bottom navigation tabs and role-based layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/chat_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/providers/notification_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/home/home_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;
  late MockNotificationProvider mockNotif;
  late MockChatProvider mockChat;
  late MockApiService mockApi;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();
    mockNotif = MockNotificationProvider();
    mockChat = MockChatProvider();
    mockApi = MockApiService();

    // Unstubbed API methods should throw (caught by widget try/catch)
    // rather than returning null which causes type errors.
    throwOnMissingStub(mockApi);

    // Default stubs shared by all tests
    when(() => mockEvent.events).thenReturn([]);
    when(() => mockEvent.isLoading).thenReturn(false);
    when(() => mockEvent.isLoadingMore).thenReturn(false);
    when(() => mockEvent.hasMore).thenReturn(false);
    when(() => mockEvent.error).thenReturn(null);
    when(() => mockEvent.selectedEvent).thenReturn(null);
    when(() => mockEvent.loadEvents(filters: any(named: 'filters')))
        .thenAnswer((_) async {});
    when(() => mockEvent.addListener(any())).thenReturn(null);
    when(() => mockEvent.removeListener(any())).thenReturn(null);

    when(() => mockNotif.unreadCount).thenReturn(0);
    when(() => mockNotif.addListener(any())).thenReturn(null);
    when(() => mockNotif.removeListener(any())).thenReturn(null);

    when(() => mockChat.totalUnreadCount).thenReturn(0);
    when(() => mockChat.conversationsLoading).thenReturn(false);
    when(() => mockChat.conversations).thenReturn([]);
    when(() => mockChat.loadConversations()).thenAnswer((_) async {});
    when(() => mockChat.addListener(any())).thenReturn(null);
    when(() => mockChat.removeListener(any())).thenReturn(null);

    when(() => mockApi.getEventCities()).thenAnswer((_) async => <String>[]);
    when(() => mockApi.checkBookmarks(any()))
        .thenAnswer((_) async => {'bookmarked_ids': <int>[]});
    when(() => mockApi.getMyEvents(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        )).thenAnswer((_) async => <dynamic>[]);
  });

  List<SingleChildWidget> _providers(AppUser? user) {
    when(() => mockAuth.user).thenReturn(user);
    when(() => mockAuth.isAuthenticated).thenReturn(user != null);
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);

    return [
      ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
      ChangeNotifierProvider<NotificationProvider>.value(value: mockNotif),
      ChangeNotifierProvider<ChatProvider>.value(value: mockChat),
      Provider<ApiService>.value(value: mockApi),
    ];
  }

  group('HomeScreen', () {
    testWidgets('renders 4 bottom navigation items for customer',
        (tester) async {
      final user = makeUser(role: UserRole.customer);
      await pumpApp(
        tester,
        const HomeScreen(),
        overrides: _providers(user),
      );
      await tester.pump();

      // Bottom nav should contain: Home, Explore, Manage, Tickets
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Tickets'), findsOneWidget);
      // Customer should NOT see Channel tab
      expect(find.text('Channel'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('renders Channel tab for organizer instead of Tickets',
        (tester) async {
      final user = makeUser(role: UserRole.organizer);
      await pumpApp(
        tester,
        const HomeScreen(),
        overrides: _providers(user),
      );
      await tester.pump();

      // Organizer sees: Home, Explore, Manage, Channel
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Channel'), findsOneWidget);
      expect(find.text('Tickets'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('initial tab is 0 by default', (tester) async {
      final user = makeUser(role: UserRole.customer);
      await pumpApp(
        tester,
        const HomeScreen(),
        overrides: _providers(user),
      );
      await tester.pump();

      // The "Home" nav item should be active (rendered with activeIcon).
      // We verify by checking the nav bar contains the Home icon with the
      // active styling — the first nav item at index 0.
      // IndexedStack starts at index 0, so the HomeTab child is displayed.
      // The active Home nav item uses Icons.home_rounded (filled).
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      // Explore should use the outlined variant since it's not active.
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('tapping Explore tab updates nav index', (tester) async {
      final user = makeUser(role: UserRole.customer);
      await pumpApp(
        tester,
        const HomeScreen(),
        overrides: _providers(user),
      );
      await tester.pump();

      // Initially Explore uses outlined icon
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);

      // Tap the Explore nav item
      await tester.tap(find.text('Explore'));
      await tester.pump();

      // After tapping, Explore should use filled icon (active)
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
      // Home should now use outlined icon (inactive)
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
