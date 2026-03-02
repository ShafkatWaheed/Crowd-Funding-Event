import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/repositories/event_repository.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/sponsorship_categories_screen.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockSponsorRepository mockSponsorRepo;
  late MockEventRepository mockEventRepo;
  late MockAuthProvider mockAuth;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
    mockEventRepo = MockEventRepository();
    mockAuth = MockAuthProvider();
  });

  Map<String, dynamic> categoryJson({
    int id = 1,
    int eventId = 1,
    String name = 'Gold Sponsor',
    String? description,
    int totalSpots = 5,
    int filledSpots = 2,
    int minBidCents = 10000,
    int bidCount = 3,
    List<int>? bidAmounts,
    int myBidCount = 0,
    List<Map<String, dynamic>>? myBids,
    int prereqCount = 0,
  }) =>
      {
        'id': id,
        'event_id': eventId,
        'name': name,
        'description': description,
        'total_spots': totalSpots,
        'filled_spots': filledSpots,
        'min_bid_cents': minBidCents,
        'bid_count': bidCount,
        'bid_amounts': bidAmounts ?? [],
        'my_bid_count': myBidCount,
        'my_bids': myBids ?? [],
        'prereq_count': prereqCount,
      };

  void stubData({
    List<dynamic>? categories,
    String eventStatus = 'approved',
  }) {
    when(() => mockSponsorRepo.getSponsorshipCategories(any()))
        .thenAnswer((_) async => categories ?? []);
    when(() => mockEventRepo.getEvent(any()))
        .thenAnswer((_) async => {'id': 1, 'status': eventStatus});
  }

  Future<void> pumpScreen(WidgetTester tester, {UserRole role = UserRole.customer}) async {
    when(() => mockAuth.user).thenReturn(AppUser(
      id: 1,
      email: 'test@test.com',
      displayName: 'Test',
      role: role,
    ));

    await pumpApp(
      tester,
      const SponsorshipCategoriesScreen(eventId: 1),
      overrides: [
        Provider<SponsorRepository>.value(value: mockSponsorRepo),
        Provider<EventRepository>.value(value: mockEventRepo),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
    );
  }

  group('SponsorshipCategoriesScreen', () {
    testWidgets('shows title', (tester) async {
      stubData();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sponsorships'), findsOneWidget);
    });

    testWidgets('shows empty state when no categories', (tester) async {
      stubData(categories: []);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No sponsorships yet.'), findsOneWidget);
    });

    testWidgets('renders category cards with name and info', (tester) async {
      stubData(categories: [
        categoryJson(name: 'Gold Sponsor', totalSpots: 5, filledSpots: 2, minBidCents: 10000, bidCount: 3),
        categoryJson(id: 2, name: 'Silver Sponsor', totalSpots: 10, filledSpots: 0, minBidCents: 5000, bidCount: 0),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Gold Sponsor'), findsOneWidget);
      expect(find.text('Silver Sponsor'), findsOneWidget);
      expect(find.textContaining('2/5 spots'), findsOneWidget);
      expect(find.textContaining('0/10 spots'), findsOneWidget);
      expect(find.textContaining('3 bids'), findsOneWidget);
      expect(find.textContaining('0 bids'), findsOneWidget);
    });

    testWidgets('shows Place Bid button for sponsors', (tester) async {
      stubData(categories: [
        categoryJson(totalSpots: 5, filledSpots: 0, myBidCount: 0),
      ]);

      await pumpScreen(tester, role: UserRole.sponsor);
      await tester.pumpAndSettle();

      expect(find.text('Place Bid'), findsOneWidget);
    });

    testWidgets('hides Place Bid for non-sponsors', (tester) async {
      stubData(categories: [
        categoryJson(totalSpots: 5, filledSpots: 0),
      ]);

      await pumpScreen(tester, role: UserRole.customer);
      await tester.pumpAndSettle();

      expect(find.text('Place Bid'), findsNothing);
    });

    testWidgets('shows View Bids and Reqs for organizer', (tester) async {
      stubData(categories: [
        categoryJson(bidCount: 3),
      ]);

      await pumpScreen(tester, role: UserRole.organizer);
      await tester.pumpAndSettle();

      expect(find.text('View Bids (3)'), findsOneWidget);
      expect(find.text('Reqs'), findsOneWidget);
    });

    testWidgets('shows FAB for organizer when event is approved', (tester) async {
      stubData(eventStatus: 'approved');
      await pumpScreen(tester, role: UserRole.organizer);
      await tester.pumpAndSettle();

      expect(find.text('Add Sponsorship'), findsOneWidget);
    });

    testWidgets('hides FAB for organizer when event is live', (tester) async {
      stubData(eventStatus: 'live');
      await pumpScreen(tester, role: UserRole.organizer);
      await tester.pumpAndSettle();

      expect(find.text('Add Sponsorship'), findsNothing);
    });

    testWidgets('shows min bid display', (tester) async {
      stubData(categories: [
        categoryJson(minBidCents: 25000),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Min: \$250.00'), findsOneWidget);
    });
  });
}
