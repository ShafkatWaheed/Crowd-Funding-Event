import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/payment.dart';

void main() {
  group('StripeConfig', () {
    test('fromJson parses all fields', () {
      final config = StripeConfig.fromJson({
        'stripe_enabled': true,
        'publishable_key': 'pk_test_123',
      });
      expect(config.stripeEnabled, true);
      expect(config.publishableKey, 'pk_test_123');
    });

    test('defaults when fields missing', () {
      final config = StripeConfig.fromJson({});
      expect(config.stripeEnabled, false);
      expect(config.publishableKey, isNull);
    });
  });

  group('PaymentIntent', () {
    test('fromJson parses all fields', () {
      final intent = PaymentIntent.fromJson({
        'client_secret': 'pi_secret_abc',
        'amount_cents': 5000,
        'status': 'requires_payment_method',
        'payment_intent_id': 'pi_123',
      });
      expect(intent.clientSecret, 'pi_secret_abc');
      expect(intent.amountCents, 5000);
      expect(intent.status, 'requires_payment_method');
      expect(intent.paymentIntentId, 'pi_123');
    });

    test('defaults when fields missing', () {
      final intent = PaymentIntent.fromJson({
        'client_secret': 'secret',
      });
      expect(intent.clientSecret, 'secret');
      expect(intent.amountCents, 0);
      expect(intent.status, '');
      expect(intent.paymentIntentId, isNull);
    });
  });
}
