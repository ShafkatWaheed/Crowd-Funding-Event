import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/models/venue.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/venue_provider.dart';
import 'package:crowd_funding_app/screens/venue/venue_list_screen.dart';
import 'package:crowd_funding_app/screens/venue/create_venue_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_venue_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockVenueRepository mockVenueRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockVenueRepo = MockVenueRepository();

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  group('VenueListScreen', () {
    Future<void> pumpVenueList(WidgetTester tester) async {
      await pumpApp(
        tester,
        const VenueListScreen(),
        overrides: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<VenueProvider>.value(value: VenueProvider(mockVenueRepo)),
        ],
      );
    }

    testWidgets('shows My Venues title and Add Venue FAB', (tester) async {
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => [Venue.fromJson(venueJson())]);

      await pumpVenueList(tester);
      await tester.pumpAndSettle();

      expect(find.text('My Venues'), findsOneWidget);
      expect(find.text('Add Venue'), findsOneWidget);
    });

    testWidgets('shows empty state when no venues', (tester) async {
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => []);

      await pumpVenueList(tester);
      await tester.pumpAndSettle();

      expect(find.text('No venues yet'), findsOneWidget);
    });

    testWidgets('shows venue card with name and address', (tester) async {
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => [
                Venue.fromJson(venueJson(name: 'Grand Arena', address: '123 Main St', city: 'NYC')),
              ]);

      await pumpVenueList(tester);
      await tester.pumpAndSettle();

      expect(find.text('Grand Arena'), findsOneWidget);
    });
  });

  group('CreateVenueScreen', () {
    Future<void> pumpCreateVenue(WidgetTester tester) async {
      await pumpApp(
        tester,
        const CreateVenueScreen(),
        overrides: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<VenueProvider>.value(value: VenueProvider(mockVenueRepo)),
        ],
      );
    }

    testWidgets('renders Add Venue title and form fields', (tester) async {
      await pumpCreateVenue(tester);
      await tester.pumpAndSettle();

      expect(find.text('Add Venue'), findsOneWidget);
      expect(find.text('Venue Name'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Province'), findsOneWidget);
      expect(find.text('Max Capacity'), findsOneWidget);
      expect(find.text('Create Venue'), findsOneWidget);
    });
  });
}
