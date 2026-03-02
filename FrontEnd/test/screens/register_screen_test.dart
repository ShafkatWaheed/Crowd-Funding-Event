import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/screens/auth/register_screen.dart';
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

  /// Helper to pump the RegisterScreen wrapped in the required providers.
  Future<void> pumpRegister(WidgetTester tester) async {
    await pumpApp(
      tester,
      const RegisterScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
    );
    // Let flutter_animate animations settle.
    await tester.pumpAndSettle();
  }

  group('RegisterScreen', () {
    testWidgets('renders all required form fields', (tester) async {
      await pumpRegister(tester);

      // The form has 6 TextFormFields:
      //   Display Name, Email, Phone, Password, Confirm Password, Birthday
      final textFormFields = find.byType(TextFormField);
      expect(textFormFields, findsNWidgets(6));

      // Check label texts are present.
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone (optional)'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Birthday *'), findsOneWidget);
    });

    testWidgets('password confirmation mismatch shows error', (tester) async {
      await pumpRegister(tester);

      final textFormFields = find.byType(TextFormField);

      // Fill in name, email, password, and a mismatched confirm password.
      // Fields: [0] Display Name, [1] Email, [2] Phone, [3] Password,
      //         [4] Confirm Password, [5] Birthday (read-only)
      await tester.enterText(textFormFields.at(0), 'Test User');
      await tester.enterText(textFormFields.at(1), 'test@example.com');
      await tester.enterText(textFormFields.at(3), 'password123');
      await tester.enterText(textFormFields.at(4), 'different');

      // Find and tap the Create Account button.
      // The button is disabled because terms are not accepted and birthday
      // is not selected, so we need to trigger validation another way.
      // Actually, the button is disabled, so form validation won't trigger
      // from tapping it. Instead, we can verify the validator logic
      // by triggering form validation manually.
      //
      // We'll scroll down and try submitting. Since button is disabled,
      // let's just verify the validator message would appear by using
      // a Form key approach. Actually, the simplest way is to check that
      // the validator is set up correctly by looking at what happens when
      // we submit from a keyboard action or test the validator text.
      //
      // For widget testing, let's verify the mismatch error appears after
      // we enable the button conditions. We can't easily tap checkbox
      // and pick birthday in widget tests. So instead let's verify the
      // TextFormField has a validator that catches mismatches by checking
      // the error text after form validation.
      //
      // Approach: Find the Form widget, get its state, and call validate().
      final formFinder = find.byType(Form);
      expect(formFinder, findsOneWidget);
      final FormState formState = tester.state(formFinder);
      formState.validate();
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('role selection cards exist for all three roles',
        (tester) async {
      await pumpRegister(tester);

      // The three role cards should be visible.
      expect(find.text('Attend Events'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);

      expect(find.text('Organize Events'), findsOneWidget);
      expect(find.text('Organizer'), findsOneWidget);

      expect(find.text('Sponsor Events'), findsOneWidget);
      expect(find.text('Sponsor'), findsOneWidget);

      // Verify the role-related icons exist.
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(find.byIcon(Icons.handshake_rounded), findsOneWidget);
    });

    testWidgets('terms checkbox exists and is initially unchecked',
        (tester) async {
      await pumpRegister(tester);

      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      final Checkbox checkboxWidget = tester.widget(checkbox);
      expect(checkboxWidget.value, isFalse);

      // The terms text is rendered via RichText with TextSpan children,
      // so find.text() won't match. Use find.byWidgetPredicate to check
      // that a RichText containing the terms text is present.
      final termsRichText = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text.contains('I have read and agree to the') &&
              text.contains('Terms and Conditions');
        }
        return false;
      });
      expect(termsRichText, findsOneWidget);
    });

    testWidgets('submit button is disabled when terms are not accepted',
        (tester) async {
      await pumpRegister(tester);

      // With terms unchecked (default) and no birthday, the button is disabled.
      final button = find.widgetWithText(ElevatedButton, 'Create Account');
      expect(button, findsOneWidget);

      final ElevatedButton elevatedButton = tester.widget(button);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('error message is displayed when auth fails', (tester) async {
      when(() => mockAuth.errorMessage)
          .thenReturn('Email already in use');

      await pumpRegister(tester);

      expect(find.text('Email already in use'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('form renders correctly with header and subtitle',
        (tester) async {
      await pumpRegister(tester);

      // Header and subtitle text.
      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Join CrowdFund Events today'), findsOneWidget);

      // The "I want to..." label for role selection.
      expect(find.text('I want to...'), findsOneWidget);

      // The login link at the bottom.
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign In'), findsOneWidget);
    });
  });
}
