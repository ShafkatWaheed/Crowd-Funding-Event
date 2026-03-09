import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/payment.dart';
import 'package:crowd_funding_app/providers/config_provider.dart';
import 'package:crowd_funding_app/repositories/payment_repository.dart';
import '../helpers/mock_event_repository.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockEventRepository mockRepo;
  late MockPaymentRepository mockPaymentRepo;
  late ConfigProvider provider;

  setUp(() {
    mockRepo = MockEventRepository();
    mockPaymentRepo = MockPaymentRepository();
    provider = ConfigProvider(mockRepo, mockPaymentRepo);
  });

  group('ConfigProvider', () {
    test('initial state has defaults', () {
      expect(provider.maxTicketsPerPurchase, 10);
      expect(provider.maxTicketsFrontendEnabled, false);
      expect(provider.featureMilestonesEnabled, true);
      expect(provider.featureScheduleEnabled, true);
      expect(provider.featureSponsorsEnabled, true);
      expect(provider.featureCommunityRulesEnabled, true);
      expect(provider.stripeEnabled, false);
      expect(provider.loaded, false);
    });

    test('fetchConfig success updates values', () async {
      when(() => mockRepo.getPublicConfig()).thenAnswer((_) async =>
          PublicConfig(
            maxTicketsPerPurchase: 5,
            maxTicketsFrontendEnabled: true,
            featureMilestonesEnabled: false,
            featureScheduleEnabled: true,
            featureSponsorsEnabled: false,
            featureCommunityRulesEnabled: true,
          ));
      when(() => mockPaymentRepo.getStripeConfig()).thenAnswer(
          (_) async => StripeConfig(stripeEnabled: true, publishableKey: 'pk_test'));

      await provider.fetchConfig();

      expect(provider.maxTicketsPerPurchase, 5);
      expect(provider.maxTicketsFrontendEnabled, true);
      expect(provider.featureMilestonesEnabled, false);
      expect(provider.featureSponsorsEnabled, false);
      expect(provider.stripeEnabled, true);
      expect(provider.loaded, true);
    });

    test('fetchConfig failure keeps defaults', () async {
      when(() => mockRepo.getPublicConfig()).thenThrow(Exception('Network error'));

      await provider.fetchConfig();

      // Defaults preserved
      expect(provider.maxTicketsPerPurchase, 10);
      expect(provider.featureMilestonesEnabled, true);
      expect(provider.loaded, false);
    });

    test('fetchConfig with partial data uses defaults for missing keys', () async {
      when(() => mockRepo.getPublicConfig()).thenAnswer((_) async =>
          PublicConfig(maxTicketsPerPurchase: 3));
      when(() => mockPaymentRepo.getStripeConfig()).thenAnswer(
          (_) async => StripeConfig(stripeEnabled: false));

      await provider.fetchConfig();

      expect(provider.maxTicketsPerPurchase, 3);
      expect(provider.featureMilestonesEnabled, true); // default
      expect(provider.loaded, true);
    });

    test('createPaymentIntent forwards to payment repo', () async {
      final mockIntent = PaymentIntent(
        clientSecret: 'pi_secret_test',
        amountCents: 5000,
        status: 'requires_payment_method',
      );
      when(() => mockPaymentRepo.createPaymentIntent(
            amountCents: any(named: 'amountCents'),
            description: any(named: 'description'),
            idempotencyKey: any(named: 'idempotencyKey'),
          )).thenAnswer((_) async => mockIntent);

      final result = await provider.createPaymentIntent(
        amountCents: 5000,
        description: 'Test payment',
      );

      expect(result.clientSecret, 'pi_secret_test');
      expect(result.amountCents, 5000);
    });
  });
}
