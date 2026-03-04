import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/user_provider.dart';
import '../../lib/repositories/user_repository.dart';
import '../../lib/widgets/kyc_section.dart';
import '../helpers/mock_user_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockUserRepository mockUserRepo;

  setUp(() {
    mockUserRepo = MockUserRepository();
  });

  Future<void> pumpKyc(WidgetTester tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: KycSection())),
      overrides: [ChangeNotifierProvider<UserProvider>.value(value: UserProvider(mockUserRepo))],
    );
  }

  KycStatus kycResponse({
    String status = 'not_started',
    bool verified = false,
    bool required = false,
    List<KycDocument> documents = const [],
  }) =>
      KycStatus(
        kycStatus: status,
        kycVerified: verified,
        kycRequiredForRole: required,
        documents: documents,
      );

  group('KycSection', () {
    testWidgets('shows loading indicator while fetching', (tester) async {
      // Use a Completer that never completes — avoids pending Timer teardown errors.
      final completer = Completer<KycStatus>();
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) => completer.future);

      await pumpKyc(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid async leaks.
      completer.complete(kycResponse());
      await tester.pumpAndSettle();
    });

    testWidgets('renders "not_started" state with document upload list', (tester) async {
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'not_started'));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      // Status banner
      expect(find.text('Not Verified'), findsOneWidget);
      // Required doc labels
      expect(find.text('Government ID (Front)'), findsOneWidget);
      expect(find.text('Proof of Address'), findsOneWidget);
      // Optional docs
      expect(find.text('Government ID (Back)'), findsOneWidget);
      expect(find.text('Selfie with ID'), findsOneWidget);
      expect(find.text('Tax ID Document'), findsOneWidget);
      // Upload buttons
      expect(find.text('Upload'), findsWidgets);
      // Submit disabled (required docs not uploaded)
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit for Verification'),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('renders "not_started" with required flag', (tester) async {
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'not_started', required: true));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      expect(find.text('Verification Required'), findsOneWidget);
    });

    testWidgets('renders "verified" state without upload list', (tester) async {
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'verified', verified: true));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      expect(find.text('Identity Verified'), findsOneWidget);
      expect(find.text('Your identity has been verified. No further action needed.'), findsOneWidget);
      // No upload buttons
      expect(find.text('Upload'), findsNothing);
      expect(find.text('Submit for Verification'), findsNothing);
    });

    testWidgets('renders "submitted" state with review message', (tester) async {
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'submitted'));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      expect(find.text('Under Review'), findsOneWidget);
      expect(
        find.textContaining('Your documents are under review'),
        findsOneWidget,
      );
      expect(find.text('Upload'), findsNothing);
    });

    testWidgets('renders "rejected" state with rejection reasons', (tester) async {
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) async => kycResponse(
            status: 'rejected',
            documents: [
              KycDocument(
                id: 1,
                documentType: 'id_front',
                originalFilename: 'id.jpg',
                status: 'rejected',
                rejectionReason: 'Image is blurry',
              ),
            ],
          ));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      expect(find.text('Verification Rejected'), findsOneWidget);
      expect(find.text('Rejection reasons:'), findsOneWidget);
      expect(find.textContaining('Image is blurry'), findsOneWidget);
    });

    testWidgets('shows check icon for uploaded documents', (tester) async {
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) async => kycResponse(
            status: 'not_started',
            documents: [
              KycDocument(
                id: 10,
                documentType: 'id_front',
                originalFilename: 'my_id.jpg',
                status: 'pending',
              ),
            ],
          ));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      // Uploaded file name visible
      expect(find.text('my_id.jpg'), findsOneWidget);
      // Check icon for uploaded doc
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // Close/remove button for pending doc
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('submit button enabled when required docs are uploaded', (tester) async {
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) async => kycResponse(
            status: 'not_started',
            documents: [
              KycDocument(id: 1, documentType: 'id_front', originalFilename: 'a.jpg', status: 'pending'),
              KycDocument(id: 2, documentType: 'proof_of_address', originalFilename: 'b.pdf', status: 'pending'),
            ],
          ));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit for Verification'),
      );
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('tapping submit calls submitKyc and reloads', (tester) async {
      // First load: required docs uploaded
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) async => kycResponse(
            status: 'not_started',
            documents: [
              KycDocument(id: 1, documentType: 'id_front', originalFilename: 'a.jpg', status: 'pending'),
              KycDocument(id: 2, documentType: 'proof_of_address', originalFilename: 'b.pdf', status: 'pending'),
            ],
          ));
      when(() => mockUserRepo.submitKyc())
          .thenAnswer((_) async => KycSubmitResult(kycStatus: 'submitted', message: 'Submitted for review'));

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      // After submit, return submitted state
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'submitted'));

      await tester.tap(find.text('Submit for Verification'));
      await tester.pumpAndSettle();

      verify(() => mockUserRepo.submitKyc()).called(1);
      // Reloaded to submitted state
      expect(find.text('Under Review'), findsOneWidget);
    });

    testWidgets('tapping delete button calls deleteKycDocument', (tester) async {
      when(() => mockUserRepo.getKycStatus()).thenAnswer((_) async => kycResponse(
            status: 'not_started',
            documents: [
              KycDocument(id: 42, documentType: 'id_front', originalFilename: 'a.jpg', status: 'pending'),
            ],
          ));
      when(() => mockUserRepo.deleteKycDocument(42)).thenAnswer((_) async {});

      await pumpKyc(tester);
      await tester.pumpAndSettle();

      // Reload after delete returns empty
      when(() => mockUserRepo.getKycStatus())
          .thenAnswer((_) async => kycResponse(status: 'not_started'));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      verify(() => mockUserRepo.deleteKycDocument(42)).called(1);
    });
  });
}
