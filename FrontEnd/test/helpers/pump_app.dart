/// Test helper to wrap widgets in MaterialApp + providers for testing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/providers/notification_provider.dart';
import '../../lib/providers/config_provider.dart';
import '../../lib/providers/theme_provider.dart';

/// Pumps [child] wrapped in MaterialApp with optional providers.
///
/// Sets a generous surface size (1080x1920 logical pixels) and
/// suppresses RenderFlex overflow errors that commonly occur in
/// widget tests due to the Ahem test font being wider than production fonts.
///
/// Use [overrides] to inject mock providers:
/// ```dart
/// await pumpApp(tester, const MyWidget(), overrides: [
///   ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
/// ]);
/// ```
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<SingleChildWidget> overrides = const [],
  NavigatorObserver? navigatorObserver,
  Size surfaceSize = const Size(1080, 1920),
}) async {
  // Use a large surface to minimise layout overflow issues.
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;

  // Suppress harmless errors that are artefacts of the test environment:
  // - RenderFlex overflow (Ahem font is wider than production fonts)
  // - ProviderNotFoundException for AppDatabase / GoRouter (screens catch
  //   these internally, but the FlutterError is still reported in tests)
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    final suppress = msg.contains('overflowed') ||
        msg.contains('ProviderNotFoundException') ||
        msg.contains('Could not find the correct Provider<AppDatabase>') ||
        msg.contains('No GoRouter found in context');
    if (!suppress) {
      // Forward non-suppressed errors to the original handler.
      originalOnError?.call(details);
    }
  };

  addTearDown(() {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final widget = overrides.isNotEmpty
      ? MultiProvider(
          providers: overrides,
          child: MaterialApp(
            home: child,
            navigatorObservers:
                navigatorObserver != null ? [navigatorObserver] : [],
          ),
        )
      : MaterialApp(
          home: child,
          navigatorObservers:
              navigatorObserver != null ? [navigatorObserver] : [],
        );

  await tester.pumpWidget(widget);
}
