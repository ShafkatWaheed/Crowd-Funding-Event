import 'package:flutter/foundation.dart';

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
  bool stripeEnabled = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  ConfigProvider(this._api, [this._paymentRepo]);

  Future<void> fetchConfig() async {
    try {
      final data = await _api.getPublicConfig();
      maxTicketsPerPurchase = data['max_tickets_per_purchase'] as int? ?? 10;
      maxTicketsFrontendEnabled = data['max_tickets_frontend_enabled'] as bool? ?? false;
      featureMilestonesEnabled = data['feature_milestones_enabled'] as bool? ?? true;
      featureScheduleEnabled = data['feature_schedule_enabled'] as bool? ?? true;
      featureSponsorsEnabled = data['feature_sponsors_enabled'] as bool? ?? true;
      featureCommunityRulesEnabled = data['feature_community_rules_enabled'] as bool? ?? true;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Graceful degradation: keep defaults if config fetch fails
    }
    // Fetch Stripe config separately (different endpoint)
    if (_paymentRepo != null) {
      try {
        final stripeData = await _paymentRepo.getStripeConfig();
        stripeEnabled = stripeData['stripe_enabled'] == true;
        notifyListeners();
      } catch (_) {
        // Stripe config unavailable — keep default (false)
      }
    }
  }
}
