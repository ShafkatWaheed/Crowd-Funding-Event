import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/discount.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/providers/ticket_provider.dart';
import '../../lib/screens/manage/global_discounts_screen.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockTicketRepo = MockTicketRepository();
  });

  DiscountStrategy makeStrategy({
    int id = 1,
    String name = 'Early Bird',
    String discountType = 'ticket_percent',
    int value = 10,
    String target = 'all',
  }) =>
      DiscountStrategy.fromJson({
        'id': id,
        'organizer_id': 1,
        'name': name,
        'discount_type': discountType,
        'value': value,
        'target': target,
        'created_at': '2025-01-01T00:00:00',
        'updated_at': '2025-01-01T00:00:00',
      });

  void stubDiscounts({List<DiscountStrategy>? data}) {
    when(() => mockTicketRepo.getDiscountStrategies())
        .thenAnswer((_) async => data ?? []);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      const GlobalDiscountsScreen(),
      overrides: [ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo))],
    );
  }

  group('GlobalDiscountsScreen', () {
    testWidgets('shows title', (tester) async {
      stubDiscounts();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Discounts'), findsOneWidget);
    });

    testWidgets('shows create form', (tester) async {
      stubDiscounts();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Create Discount'), findsWidgets);
      expect(find.text('Discount Type'), findsOneWidget);
      expect(find.text('% of Ticket'), findsOneWidget);
      expect(find.text('% of Pledge'), findsOneWidget);
    });

    testWidgets('shows target options', (tester) async {
      stubDiscounts();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Who gets this discount?'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Pledgers'), findsOneWidget);
      expect(find.text('Non-Pledgers'), findsOneWidget);
    });

    testWidgets('shows empty state when no discounts', (tester) async {
      stubDiscounts(data: []);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No discounts yet'), findsOneWidget);
      expect(find.text('0 discounts'), findsOneWidget);
    });

    testWidgets('renders discount cards', (tester) async {
      stubDiscounts(data: [
        makeStrategy(name: 'Early Bird', discountType: 'ticket_percent', value: 10, target: 'all'),
        makeStrategy(id: 2, name: 'Pledger Reward', discountType: 'pledge_percent', value: 5, target: 'pledgers'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Early Bird'), findsOneWidget);
      expect(find.text('Pledger Reward'), findsOneWidget);
      expect(find.text('2 discounts'), findsOneWidget);
      expect(find.textContaining('10% off ticket price'), findsOneWidget);
      expect(find.textContaining('5% of pledge amount'), findsOneWidget);
    });

    testWidgets('shows target info on discount cards', (tester) async {
      stubDiscounts(data: [
        makeStrategy(name: 'Pledgers Only', target: 'pledgers', value: 15),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('pledgers only'), findsOneWidget);
    });

    testWidgets('search filters discounts by name', (tester) async {
      stubDiscounts(data: [
        makeStrategy(name: 'Early Bird'),
        makeStrategy(id: 2, name: 'VIP Special'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // Find the search field (second TextField — first is name in create form)
      final searchFields = find.byType(TextField);
      // Search is the third TextField (name, percentage, search)
      await tester.enterText(searchFields.at(2), 'VIP');
      await tester.pump();

      expect(find.text('Early Bird'), findsNothing);
      expect(find.text('VIP Special'), findsOneWidget);
      expect(find.text('1 discount'), findsOneWidget);
    });

    testWidgets('shows delete button on cards', (tester) async {
      stubDiscounts(data: [makeStrategy()]);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('calls deleteDiscountStrategy when delete tapped',
        (tester) async {
      stubDiscounts(data: [makeStrategy(id: 42)]);
      when(() => mockTicketRepo.deleteDiscountStrategy(42))
          .thenAnswer((_) async {});

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      verify(() => mockTicketRepo.deleteDiscountStrategy(42)).called(1);
    });
  });
}
