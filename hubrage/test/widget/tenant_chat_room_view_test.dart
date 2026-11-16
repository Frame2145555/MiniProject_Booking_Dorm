import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/chat_room_view.dart';
import '../support/chat_widget_test_helpers.dart';
import '../support/fake_chat_service.dart';

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = createChatTestService();
  });

  Future<void> openRoom(WidgetTester tester) async {
    await tester.pumpWidget(
      chatTestApp(
        ChatRoomView(
          conversationId: chatTestRoomId,
          title: 'เจ้าของหอทดสอบ',
          subtitle: 'หอรวย เธะ',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the owner, dorm and message history', (tester) async {
    loginChatTestUser();
    service.history = [
      chatTestMessage(1, chatTestOtherUser, 'สวัสดีครับ'),
      chatTestMessage(2, chatTestMe, 'ห้องยังว่างไหมครับ'),
    ];

    await openRoom(tester);

    expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
    expect(find.text('หอรวย เธะ'), findsOneWidget);
    expect(find.text('สวัสดีครับ'), findsOneWidget);
    expect(find.text('ห้องยังว่างไหมครับ'), findsOneWidget);
  });

  testWidgets('shows a prompt when the room has no messages', (tester) async {
    loginChatTestUser();
    await openRoom(tester);

    expect(find.text('เริ่มต้นการสนทนากับ เจ้าของหอทดสอบ'), findsOneWidget);
  });

  testWidgets('sends a message and clears the input', (tester) async {
    loginChatTestUser();
    await openRoom(tester);

    await typeAndSend(tester, 'ห้องยังว่างไหมครับ');

    expect(service.sentTexts, ['ห้องยังว่างไหมครับ']);
    expect(find.text('ห้องยังว่างไหมครับ'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('aligns own messages right and other messages left', (
    tester,
  ) async {
    loginChatTestUser();
    service.history = [
      chatTestMessage(1, chatTestOtherUser, 'ข้อความอีกฝั่ง'),
      chatTestMessage(2, chatTestMe, 'ข้อความเรา'),
    ];
    await openRoom(tester);

    Align bubbleOf(String text) => tester.widget<Align>(
      find.ancestor(of: find.text(text), matching: find.byType(Align)).first,
    );
    expect(bubbleOf('ข้อความเรา').alignment, Alignment.centerRight);
    expect(bubbleOf('ข้อความอีกฝั่ง').alignment, Alignment.centerLeft);
  });

  testWidgets('shows new incoming messages immediately', (tester) async {
    loginChatTestUser();
    await openRoom(tester);
    expect(find.text('ว่างครับ มาดูได้เลย'), findsNothing);

    service.serverEmit(
      'new_message',
      chatTestMessage(5, chatTestOtherUser, 'ว่างครับ มาดูได้เลย'),
    );
    await tester.pump();

    expect(find.text('ว่างครับ มาดูได้เลย'), findsOneWidget);
  });

  testWidgets('keeps the draft and shows an error when sending fails', (
    tester,
  ) async {
    loginChatTestUser();
    service.serverAcceptsMessage = false;
    await openRoom(tester);

    await typeAndSend(tester, 'ส่งไม่ออก');

    expect(find.text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ส่งไม่ออก',
    );
  });

  testWidgets('does not send an empty message', (tester) async {
    loginChatTestUser();
    await openRoom(tester);

    await typeAndSend(tester, '   ');

    expect(service.sentTexts, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('marks own message as read when the other user reads it', (
    tester,
  ) async {
    loginChatTestUser();
    await openRoom(tester);
    await typeAndSend(tester, 'อ่านหรือยัง');
    expect(find.textContaining('อ่านแล้ว'), findsNothing);

    service.serverEmit('messages_read', {
      'conversation_id': chatTestRoomId,
      'reader_id': chatTestOtherUser,
    });
    await tester.pump();

    expect(find.textContaining('อ่านแล้ว'), findsOneWidget);
  });
}
