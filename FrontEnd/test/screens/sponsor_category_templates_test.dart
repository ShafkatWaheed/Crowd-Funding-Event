import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/sponsor_provider.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/sponsor_category_templates_screen.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockSponsorRepository mockSponsorRepo;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
  });

  Map<String, dynamic> templateJson({
    int id = 1,
    String name = 'Gold Sponsor',
    String? description = 'Premium sponsorship tier',
    int totalSpots = 5,
    int minBidCents = 10000,
  }) =>
      {
        'id': id,
        'name': name,
        'description': description,
        'total_spots': totalSpots,
        'min_bid_cents': minBidCents,
      };

  void stubTemplates({List<Map<String, dynamic>>? data}) {
    when(() => mockSponsorRepo.getSponsorCategoryTemplates())
        .thenAnswer((_) async => data ?? []);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorCategoryTemplatesScreen(),
      overrides: [ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo))],
    );
  }

  group('SponsorCategoryTemplatesScreen', () {
    testWidgets('shows title', (tester) async {
      stubTemplates();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sponsor Categories'), findsOneWidget);
    });

    testWidgets('shows empty state when no templates', (tester) async {
      stubTemplates(data: []);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No sponsor categories yet'), findsOneWidget);
      expect(find.textContaining('Create reusable'), findsOneWidget);
    });

    testWidgets('renders template cards with name and details',
        (tester) async {
      stubTemplates(data: [
        templateJson(name: 'Gold Sponsor', totalSpots: 5, minBidCents: 10000),
        templateJson(id: 2, name: 'Silver Sponsor', totalSpots: 10, minBidCents: 5000),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Gold Sponsor'), findsOneWidget);
      expect(find.text('Silver Sponsor'), findsOneWidget);
      expect(find.text('5 spots'), findsOneWidget);
      expect(find.text('10 spots'), findsOneWidget);
      expect(find.text('\$100.00 min'), findsOneWidget);
      expect(find.text('\$50.00 min'), findsOneWidget);
    });

    testWidgets('search filters templates', (tester) async {
      stubTemplates(data: [
        templateJson(name: 'Gold Sponsor'),
        templateJson(id: 2, name: 'Silver Sponsor'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'silver');
      await tester.pump();

      expect(find.text('Gold Sponsor'), findsNothing);
      expect(find.text('Silver Sponsor'), findsOneWidget);
    });

    testWidgets('shows "No matching categories" when search empty',
        (tester) async {
      stubTemplates(data: [
        templateJson(name: 'Gold Sponsor'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump();

      expect(find.text('No matching categories'), findsOneWidget);
    });

    testWidgets('shows FAB for creating new category', (tester) async {
      stubTemplates();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('New Category'), findsOneWidget);
    });

    testWidgets('shows manage requirements button on cards', (tester) async {
      stubTemplates(data: [templateJson()]);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Manage Requirements'), findsOneWidget);
    });

    testWidgets('shows description on card', (tester) async {
      stubTemplates(data: [
        templateJson(description: 'Premium sponsorship tier'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Premium sponsorship tier'), findsOneWidget);
    });
  });
}
