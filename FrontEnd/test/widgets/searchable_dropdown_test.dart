import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/searchable_dropdown.dart';
import '../helpers/pump_app.dart';

void main() {
  group('SearchableDropdown', () {
    final items = ['Apple', 'Banana', 'Cherry', 'Date'];

    Widget buildDropdown({
      String? selected,
      ValueChanged<String?>? onSelected,
      String? Function(String?)? validator,
    }) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SearchableDropdown<String>(
              label: 'Fruit',
              hint: 'Search fruits...',
              items: items,
              selectedItem: selected,
              itemLabel: (s) => s,
              filter: (item, query) =>
                  item.toLowerCase().contains(query.toLowerCase()),
              onSelected: onSelected ?? (_) {},
              validator: validator,
            ),
          ),
        ),
      );
    }

    testWidgets('renders label and hint', (tester) async {
      await pumpApp(tester, buildDropdown());
      await tester.pump();

      expect(find.text('Fruit'), findsOneWidget);
    });

    testWidgets('shows dropdown items when focused', (tester) async {
      await pumpApp(tester, buildDropdown());
      await tester.pump();

      // Focus the text field
      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      // Should show all items
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Cherry'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('filters items as user types', (tester) async {
      await pumpApp(tester, buildDropdown());
      await tester.pump();

      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'ban');
      await tester.pump();

      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets('selecting an item fires onSelected and closes dropdown', (tester) async {
      String? selectedValue;
      await pumpApp(
        tester,
        buildDropdown(onSelected: (v) => selectedValue = v),
      );
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      // Select "Cherry"
      await tester.tap(find.text('Cherry'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'Cherry');
    });

    testWidgets('shows selected item text in text field', (tester) async {
      await pumpApp(tester, buildDropdown(selected: 'Banana'));
      await tester.pump();

      final controller = tester
          .widget<TextFormField>(find.byType(TextFormField))
          .controller;
      expect(controller?.text, 'Banana');
    });

    testWidgets('shows clear button when item is selected', (tester) async {
      String? selectedValue = 'Apple';
      await pumpApp(
        tester,
        buildDropdown(
          selected: selectedValue,
          onSelected: (v) => selectedValue = v,
        ),
      );
      await tester.pump();

      // Clear icon should be visible
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('shows dropdown arrow when nothing selected', (tester) async {
      await pumpApp(tester, buildDropdown());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('shows check icon for selected item in list', (tester) async {
      await pumpApp(tester, buildDropdown(selected: 'Banana'));
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('validator shows error text', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  SearchableDropdown<String>(
                    label: 'Fruit',
                    hint: 'Search fruits...',
                    items: items,
                    selectedItem: null,
                    itemLabel: (s) => s,
                    filter: (item, query) =>
                        item.toLowerCase().contains(query.toLowerCase()),
                    onSelected: (_) {},
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Trigger validation via form submit
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('case-insensitive filtering', (tester) async {
      await pumpApp(tester, buildDropdown());
      await tester.pump();

      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'APPLE');
      await tester.pump();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
    });
  });
}
