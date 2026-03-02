import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/providers/config_provider.dart';
import '../helpers/mock_event_repository.dart';

void main() {
  late MockEventRepository mockRepo;
  late ConfigProvider provider;

  setUp(() {
    mockRepo = MockEventRepository();
    provider = ConfigProvider(mockRepo);
  });

  group('ConfigProvider', () {
    test('initial state has defaults', () {
      expect(provider.maxTicketsPerPurchase, 10);
      expect(provider.maxTicketsFrontendEnabled, false);
      expect(provider.featureMilestonesEnabled, true);
      expect(provider.featureScheduleEnabled, true);
      expect(provider.featureSponsorsEnabled, true);
      expect(provider.featureCommunityRulesEnabled, true);
      expect(provider.loaded, false);
    });

    test('fetchConfig success updates values', () async {
      when(() => mockRepo.getPublicConfig()).thenAnswer((_) async => {
            'max_tickets_per_purchase': 5,
            'max_tickets_frontend_enabled': true,
            'feature_milestones_enabled': false,
            'feature_schedule_enabled': true,
            'feature_sponsors_enabled': false,
            'feature_community_rules_enabled': true,
          });

      await provider.fetchConfig();

      expect(provider.maxTicketsPerPurchase, 5);
      expect(provider.maxTicketsFrontendEnabled, true);
      expect(provider.featureMilestonesEnabled, false);
      expect(provider.featureSponsorsEnabled, false);
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
      when(() => mockRepo.getPublicConfig()).thenAnswer((_) async => {
            'max_tickets_per_purchase': 3,
            // Other keys missing
          });

      await provider.fetchConfig();

      expect(provider.maxTicketsPerPurchase, 3);
      expect(provider.featureMilestonesEnabled, true); // default
      expect(provider.loaded, true);
    });
  });
}
