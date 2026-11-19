import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/chat_room_view.dart';
import '../../lib/views/chat_view.dart';
import '../support/chat_widget_test_helpers.dart';
import '../support/fake_chat_service.dart';

/// ห้องแชทจากมุมเจ้าของหอ: อีกฝั่งคือผู้เช่า
Map<String, dynamic> tenantConversation({
  String lastMessage = 'ห้องยังว่างไหมครับ',
  int unread = 0,
}) => chatTestConversation(
  otherName: 'ผู้เช่าทดสอบ',
  lastMessage: lastMessage,
  unread: unread,
);

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = createChatTestService();
  });

  Future<void> openList(WidgetTester tester) async {
    await tester.pumpWidget(
      chatTestApp(ChatView(asSeller: true, service: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the tenant chat heading and the dorm of interest', (
    tester,
  ) async {
    loginChatTestUser(role: 'seller');
    service.conversationList = [chatTestConversation()];

    await openList(tester);

    expect(find.text('แชทผู้เช่า'), findsOneWidget);
    expect(find.text('สนใจ หอรวย เธะ'), findsOneWidget);
  });

  testWidgets('asks the owner to log in without loading conversations', (
    tester,
  ) async {
    await openList(tester);

    expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);
    expect(service.fetchConversationsCount, 0);
  });

  testWidgets('shows an owner empty state when no tenant has written', (
    tester,
  ) async {
    loginChatTestUser(role: 'seller');
    await openList(tester);

    expect(find.text('ยังไม่มีผู้เช่าทักมา'), findsOneWidget);
    expect(find.textContaining('เริ่มแชทได้จากหน้ารายละเอียดหอพัก'), findsNothing);
  });

  testWidgets('shows tenant, dorm of interest, latest message and unread', (
    tester,
  ) async {
    loginChatTestUser(role: 'seller');
    service.conversationList = [tenantConversation(unread: 2)];

    await openList(tester);

    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.text('สนใจ หอรวย เธะ'), findsOneWidget);
    expect(find.text('ห้องยังว่างไหมครับ'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('updates when a tenant sends a new message', (tester) async {
    loginChatTestUser(role: 'seller');
    service.conversationList = [tenantConversation(lastMessage: 'สวัสดีครับ')];
    await openList(tester);

    service.conversationList = [
      tenantConversation(lastMessage: 'ขอนัดดูห้องพรุ่งนี้', unread: 1),
    ];
    service.serverEmit('conversation_updated', {
      'conversation_id': chatTestRoomId,
    });
    await tester.pumpAndSettle();

    expect(find.text('ขอนัดดูห้องพรุ่งนี้'), findsOneWidget);
    expect(find.text('สวัสดีครับ'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('opens the tenant conversation and refreshes on return', (
    tester,
  ) async {
    loginChatTestUser(role: 'seller');
    service.conversationList = [tenantConversation()];
    service.history = [
      chatTestMessage(1, chatTestOtherUser, 'ห้องยังว่างไหมครับ'),
    ];
    await openList(tester);
    final loadsBefore = service.fetchConversationsCount;

    await tester.tap(find.text('ผู้เช่าทดสอบ'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatRoomView), findsOneWidget);
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget); // ชื่อห้อง = ผู้เช่า
    expect(service.joined, [chatTestRoomId]);

    // กลับหน้ารายการ (ห้องแชทใช้ปุ่มย้อนกลับแบบกำหนดเอง จึงสั่ง Navigator โดยตรง)
    Navigator.of(tester.element(find.byType(ChatRoomView))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(ChatRoomView), findsNothing);
    expect(service.fetchConversationsCount, greaterThan(loadsBefore));
  });
}
