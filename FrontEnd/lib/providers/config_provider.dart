import 'package:flutter/foundation.dart';

import '../models/payment.dart';
import '../repositories/event_repository.dart';
import '../repositories/payment_repository.dart';

class ConfigProvider extends ChangeNotifier {
  final EventRepository _api;
  final PaymentRepository? _paymentRepo;

  int maxTicketsPerPurchase = 10;
  bool maxTicketsFrontendEnabled = false;
  bool featureMilestonesEnabled = true;
  bool featureScheduleEnabled = true;
  bool featureSponsorsEnabled = true;
  bool featureCommunityRulesEnabled = true;
  bool offlineTicketAutoDownloadEnabled = false;
  int completedEventChatRetentionDays = 7;
  bool stripeEnabled = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  ConfigProvider(this._api, [this._paymentRepo]);

  Future<void> fetchConfig() async {
    try {
      final config = await _api.getPublicConfig();
      maxTicketsPerPurchase = config.maxTicketsPerPurchase;
      maxTicketsFrontendEnabled = config.maxTicketsFrontendEnabled;
      featureMilestonesEnabled = config.featureMilestonesEnabled;
      featureScheduleEnabled = config.featureScheduleEnabled;
      featureSponsorsEnabled = config.featureSponsorsEnabled;
      featureCommunityRulesEnabled = config.featureCommunityRulesEnabled;
      offlineTicketAutoDownloadEnabled = config.offlineTicketAutoDownloadEnabled;
      completedEventChatRetentionDays = config.completedEventChatRetentionDays;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Graceful degradation: keep defaults if config fetch fails
    }
    // Fetch Stripe config separately (different endpoint)
    if (_paymentRepo != null) {
      try {
        final stripeData = await _paymentRepo.getStripeConfig();
        stripeEnabled = stripeData.stripeEnabled;
        notifyListeners();
      } catch (_) {
        // Stripe config unavailable — keep default (false)
      }
    }
  }

  Future<PaymentIntent> createPaymentIntent({
    required int amountCents,
    required String description,
    String? idempotencyKey,
  }) async {
    return _paymentRepo!.createPaymentIntent(
      amountCents: amountCents,
      description: description,
      idempotencyKey: idempotencyKey,
    );
  }
}
