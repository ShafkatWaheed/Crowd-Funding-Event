/// Mock providers for widget tests using mocktail.
library;

import 'package:mocktail/mocktail.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/providers/notification_provider.dart';
import '../../lib/providers/config_provider.dart';
import '../../lib/providers/theme_provider.dart';
import '../../lib/providers/chat_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockEventProvider extends Mock implements EventProvider {}

class MockNotificationProvider extends Mock implements NotificationProvider {}

class MockConfigProvider extends Mock implements ConfigProvider {}

class MockThemeProvider extends Mock implements ThemeProvider {}

class MockChatProvider extends Mock implements ChatProvider {}
