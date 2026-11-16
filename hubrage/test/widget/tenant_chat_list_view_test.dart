import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/chat_room_view.dart';
import '../../lib/views/chat_view.dart';
import '../support/chat_widget_test_helpers.dart';
import '../support/fake_chat_service.dart';

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = createChatTestService();
  });

  testWidgets('asks the tenant to log in without loading conversations', (
    tester,
  ) async {
    await tester.pumpWidget(chatTestApp(ChatView(service: service)));

    expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);
    expect(find.text('ไปหน้าเข้าสู่ระบบ'), findsOneWidget);
    expect(service.fetchConversationsCount, 0);
  });

  testWidgets('refreshes an embedded chat list after login', (tester) async {
    service.conversationList = [chatTestConversation()];
    await tester.pumpWidget(
      chatTestApp(ChatView(embedded: true, service: service)),
    );
    expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);

    loginChatTestUser();
    await tester.pumpAndSettle();

    expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
    expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsNothing);
  });

  testWidgets('clears the conversation list after logout', (tester) async {
    loginChatTestUser();
    service.conversationList = [chatTestConversation()];
    await tester.pumpWidget(
      chatTestApp(ChatView(embedded: true, service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);

    Session.clear();
    await tester.pumpAndSettle();

    expect(find.text('เจ้าของหอทดสอบ'), findsNothing);
    expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);
  });

  testWidgets('shows an empty state when the tenant has no conversations', (
    tester,
  ) async {
    loginChatTestUser();
    await tester.pumpWidget(chatTestApp(ChatView(service: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('ยังไม่มีห้องแชท'), findsOneWidget);
  });

  testWidgets('shows owner, dorm, latest message and unread count', (
    tester,
  ) async {
    loginChatTestUser();
    service.conversationList = [
      chatTestConversation(lastMessage: 'ว่างครับ', unread: 3),
    ];

    await tester.pumpWidget(chatTestApp(ChatView(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
    expect(find.text('หอรวย เธะ'), findsOneWidget);
    expect(find.text('ว่างครับ'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('updates the list when a new message arrives', (tester) async {
    loginChatTestUser();
    service.conversationList = [chatTestConversation(lastMessage: 'เก่า')];
    await tester.pumpWidget(chatTestApp(ChatView(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('เก่า'), findsOneWidget);

    service.conversationList = [
      chatTestConversation(lastMessage: 'ใหม่', unread: 1),
    ];
    service.serverEmit('conversation_updated', {
      'conversation_id': chatTestRoomId,
    });
    await tester.pumpAndSettle();

    expect(find.text('ใหม่'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('opens the selected conversation', (tester) async {
    loginChatTestUser();
    service.conversationList = [chatTestConversation()];
    service.history = [chatTestMessage(1, chatTestOtherUser, 'สวัสดีครับ')];
    await tester.pumpWidget(chatTestApp(ChatView(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เจ้าของหอทดสอบ'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatRoomView), findsOneWidget);
    expect(find.text('สวัสดีครับ'), findsOneWidget);
    expect(service.joined, [chatTestRoomId]);
  });
}
