import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    setUp(() {
      // Initialize SharedPreferences with empty values for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('initial mode is light', () {
      final provider = ThemeProvider();
      expect(provider.mode, ThemeMode.light);
      expect(provider.isDark, false);
    });

    test('setMode changes to dark', () async {
      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.dark);
      expect(provider.mode, ThemeMode.dark);
      expect(provider.isDark, true);
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

      await provider.setMode(ThemeMode.light); // already light
      expect(notifyCount, 0);
    });

    test('toggle switches light to dark', () async {
      final provider = ThemeProvider();
      expect(provider.isDark, false);

      await provider.toggle();
      expect(provider.isDark, true);
      expect(provider.mode, ThemeMode.dark);
    });

    test('toggle switches dark to light', () async {
      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.dark);
      expect(provider.isDark, true);

      await provider.toggle();
      expect(provider.isDark, false);
      expect(provider.mode, ThemeMode.light);
    });

    test('persists to SharedPreferences', () async {
      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
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
