import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crowd_funding_app/screens/auth/splash_screen.dart';
import '../helpers/pump_app.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('renders CrowdFund and Events text', (tester) async {
      await pumpApp(tester, const SplashScreen());
      // The animations take time, but the widgets should be in the tree
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('CrowdFund'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      await pumpApp(tester, const SplashScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
