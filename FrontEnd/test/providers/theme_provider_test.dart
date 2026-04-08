import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crowd_funding_app/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    setUp(() {
      // Initialize SharedPreferences with empty values for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('initial mode is dark', () {
      final provider = ThemeProvider();
      expect(provider.mode, ThemeMode.dark);
      expect(provider.isDark, true);
    });

    testWidgets('setMode changes to light', (tester) async {
      final provider = ThemeProvider();
      await tester.pump(); // let _load() settle
      await provider.setMode(ThemeMode.light);
      expect(provider.mode, ThemeMode.light);
      expect(provider.isDark, false);
    });

    test('setMode changes to system', () async {
      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.system);
      expect(provider.mode, ThemeMode.system);
      expect(provider.isDark, false); // isDark only true for ThemeMode.dark
    });

    test('setMode with same value is noop', () async {
      final provider = ThemeProvider();
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setMode(ThemeMode.dark); // already dark
      expect(notifyCount, 0);
    });

    testWidgets('toggle switches dark to light', (tester) async {
      final provider = ThemeProvider();
      await tester.pump(); // let _load() settle
      expect(provider.isDark, true);

      await provider.toggle();
      expect(provider.isDark, false);
      expect(provider.mode, ThemeMode.light);
    });

    testWidgets('toggle switches light to dark', (tester) async {
      final provider = ThemeProvider();
      await tester.pump(); // let _load() settle
      await provider.setMode(ThemeMode.light);
      expect(provider.isDark, false);

      await provider.toggle();
      expect(provider.isDark, true);
      expect(provider.mode, ThemeMode.dark);
    });

    test('persists to SharedPreferences', () async {
      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    testWidgets('loads persisted value from SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      final provider = ThemeProvider();
      // Let async _load() complete and post-frame callback fire
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(provider.mode, ThemeMode.dark);
    });
  });
}
