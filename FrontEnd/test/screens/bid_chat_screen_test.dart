import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/models/chat_message.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/chat_provider.dart';
import '../../lib/screens/chat/bid_chat_screen.dart';
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
    when(() => mockChat.messagesFor(any())).thenReturn([]);
    when(() => mockChat.isTyping(any())).thenReturn(false);
    when(() => mockChat.joinBid(any())).thenReturn(null);
    when(() => mockChat.leaveBid(any())).thenReturn(null);
    when(() => mockChat.clearBid(any())).thenReturn(null);
    when(() => mockChat.loadHistory(any())).thenAnswer((_) async {});
    when(() => mockChat.markRead(any(), any())).thenReturn(null);
  });

  Future<void> pumpBidChat(WidgetTester tester, {
    bool isWritable = true,
    String? participantName,
  }) async {
    await pumpApp(
      tester,
      BidChatScreen(
        bidId: 1,
        participantName: participantName,
        isWritable: isWritable,
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChat),
      ],
    );
  }

  group('BidChatScreen', () {
    testWidgets('renders participant name in AppBar', (tester) async {
      await pumpBidChat(tester, participantName: 'Acme Corp');
      await tester.pumpAndSettle();

      expect(find.text('Acme Corp'), findsOneWidget);
    });

    testWidgets('shows empty state when no messages', (tester) async {
      await pumpBidChat(tester);
      await tester.pumpAndSettle();

      expect(find.text('Start the conversation'), findsOneWidget);
      expect(find.text('Discuss sponsorship details here'), findsOneWidget);
    });

    testWidgets('shows closed banner when not writable', (tester) async {
      await pumpBidChat(tester, isWritable: false);
      await tester.pumpAndSettle();

      expect(find.text('This conversation is closed'), findsOneWidget);
      // Input bar should not be rendered when not writable
      expect(find.text('Type a message...'), findsNothing);
    });
  });
}
