import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/chat_provider.dart';
import 'package:crowd_funding_app/screens/chat/conversations_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockChatProvider mockChat;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockChat = MockChatProvider();

    when(() => mockAuth.user).thenReturn(makeUser(id: 10, role: UserRole.organizer));
    when(() => mockChat.conversationsLoading).thenReturn(false);
    when(() => mockChat.conversations).thenReturn([]);
    when(() => mockChat.loadConversations()).thenAnswer((_) async {});
  });

  Future<void> pumpConversations(WidgetTester tester, {bool embedded = false}) async {
    // When embedded=true, ConversationsScreen returns a Column (no Scaffold),
    // so we wrap in a Scaffold to provide Material ancestor for TextField.
    final child = embedded
        ? Scaffold(body: ConversationsScreen(embedded: embedded))
        : ConversationsScreen(embedded: embedded);

    await pumpApp(
      tester,
      child,
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChat),
      ],
    );
  }

  group('ConversationsScreen', () {
    testWidgets('non-embedded renders AppBar with Messages title', (tester) async {
      await pumpConversations(tester, embedded: false);
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('embedded renders Sponsor Channel header', (tester) async {
      await pumpConversations(tester, embedded: true);
      await tester.pumpAndSettle();

      expect(find.text('Sponsor Channel'), findsOneWidget);
    });

    testWidgets('shows empty state when no conversations', (tester) async {
      await pumpConversations(tester);
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('Chat with organizers or sponsors on bids'), findsOneWidget);
    });
  });
}
