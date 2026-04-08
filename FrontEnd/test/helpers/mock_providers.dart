/// Mock providers for widget tests using mocktail.
library;

import 'package:mocktail/mocktail.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/providers/notification_provider.dart';
import 'package:crowd_funding_app/providers/config_provider.dart';
import 'package:crowd_funding_app/providers/theme_provider.dart';
import 'package:crowd_funding_app/providers/chat_firebase_provider.dart';
import 'package:crowd_funding_app/providers/poll_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockPollProvider extends Mock implements PollProvider {}

class MockEventProvider extends Mock implements EventProvider {
  @override
  int get registrationVersion => 0;
}

class MockNotificationProvider extends Mock implements NotificationProvider {}

class MockConfigProvider extends Mock implements ConfigProvider {}

class MockThemeProvider extends Mock implements ThemeProvider {}

class MockChatFirebaseProvider extends Mock implements ChatFirebaseProvider {}
