// Payment-related models (Stripe config, payment intents).

class StripeConfig {
  final bool stripeEnabled;
  final String? publishableKey;

  StripeConfig({
    required this.stripeEnabled,
    this.publishableKey,
  });

  factory StripeConfig.fromJson(Map<String, dynamic> json) {
    return StripeConfig(
      stripeEnabled: json['stripe_enabled'] as bool? ?? false,
      publishableKey: json['publishable_key'] as String?,
    );
  }
}

class PaymentIntent {
  final String clientSecret;
  final int amountCents;
  final String status;
  final String? paymentIntentId;

  PaymentIntent({
    required this.clientSecret,
    required this.amountCents,
    required this.status,
    this.paymentIntentId,
  });

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      clientSecret: json['client_secret'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? json['amount'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      paymentIntentId: json['payment_intent_id'] as String?,
    );
  }
}
