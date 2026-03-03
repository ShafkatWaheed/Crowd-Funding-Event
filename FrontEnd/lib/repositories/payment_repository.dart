import 'base_repository.dart';

/// Stateless repository for Stripe payment API calls.
class PaymentRepository extends BaseRepository {
  PaymentRepository(super.dio);

  Future<Map<String, dynamic>> getStripeConfig() async {
    final resp = await dio.get('/stripe/config');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    required int amountCents,
    required String description,
    String? idempotencyKey,
  }) async {
    final resp = await dio.post('/payments/create-intent', data: {
      'amount_cents': amountCents,
      'description': description,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
