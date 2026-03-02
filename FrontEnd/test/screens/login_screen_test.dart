import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/screens/auth/login_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
    // Default stubs — idle state, no error, not authenticated.
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.errorMessage).thenReturn(null);
    when(() => mockAuth.user).thenReturn(null);
    when(() => mockAuth.isAuthenticated).thenReturn(false);
    when(() => mockAuth.initialCheckDone).thenReturn(true);
  });

  /// Helper to pump the LoginScreen wrapped in the required providers.
  ///
  /// When [settle] is true (default), calls `pumpAndSettle()` to let
  /// flutter_animate entry animations finish. Set to false when the
  /// widget tree contains infinite animations (e.g. CircularProgressIndicator)
  /// which would cause `pumpAndSettle` to time out.
  Future<void> pumpLogin(
    WidgetTester tester, {
    bool settle = true,
  }) async {
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Pump enough frames for flutter_animate entry animations to render
      // without waiting for infinite animations to finish.
      await tester.pump(const Duration(seconds: 1));
    }
  }

  group('LoginScreen', () {
    testWidgets('renders email and password TextFormFields', (tester) async {
      await pumpLogin(tester);

      // There should be exactly two TextFormFields (email + password).
      final textFormFields = find.byType(TextFormField);
      expect(textFormFields, findsNWidgets(2));

      // Verify the hint/label text exists somewhere in the tree.
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('email validation shows error when empty', (tester) async {
      await pumpLogin(tester);

      // Leave email empty, tap Sign In to trigger validation.
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('password validation shows error when empty', (tester) async {
      await pumpLogin(tester);

      // Enter a valid email but leave password empty.
      final textFormFields = find.byType(TextFormField);
      await tester.enterText(textFormFields.first, 'test@example.com');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('submit button exists and is tappable', (tester) async {
      await pumpLogin(tester);

      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(signInButton, findsOneWidget);

      // Verify the button is enabled (onPressed is not null).
      final ElevatedButton button = tester.widget(signInButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('loading state shows CircularProgressIndicator',
        (tester) async {
      when(() => mockAuth.isLoading).thenReturn(true);

      // CircularProgressIndicator is an infinite animation; don't settle.
      await pumpLogin(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The "Sign In" text should NOT be visible when loading.
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('loading state disables the submit button', (tester) async {
      when(() => mockAuth.isLoading).thenReturn(true);

      // CircularProgressIndicator is an infinite animation; don't settle.
      await pumpLogin(tester, settle: false);

      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      final ElevatedButton elevatedButton = tester.widget(button);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('error message is displayed when auth fails', (tester) async {
      when(() => mockAuth.errorMessage).thenReturn('Invalid credentials');

      await pumpLogin(tester);

      expect(find.text('Invalid credentials'), findsOneWidget);
      // The error icon should also be present.
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('register link (Sign Up) button exists', (tester) async {
      await pumpLogin(tester);

      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('form submission calls signIn on AuthProvider',
        (tester) async {
      when(() => mockAuth.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});

      await pumpLogin(tester);

      // Fill in the form fields.
      final textFormFields = find.byType(TextFormField);
      await tester.enterText(textFormFields.at(0), 'user@example.com');
      await tester.enterText(textFormFields.at(1), 'password123');

      // Tap the Sign In button.
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify signIn was called with the correct arguments.
      verify(() => mockAuth.signIn(
            email: 'user@example.com',
            password: 'password123',
          )).called(1);
    });
  });
}
