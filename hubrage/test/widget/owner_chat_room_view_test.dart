import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/chat_room_view.dart';
import '../support/chat_widget_test_helpers.dart';
import '../support/fake_chat_service.dart';

/// ห้องแชทจากมุมเจ้าของหอ (login เป็น seller คุยกับผู้เช่า)
void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = createChatTestService();
    loginChatTestUser(role: 'seller');
  });

  Future<void> openRoom(WidgetTester tester) async {
    await tester.pumpWidget(
      chatTestApp(
        ChatRoomView(
          conversationId: chatTestRoomId,
          title: 'ผู้เช่าทดสอบ',
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

  Align bubbleOf(WidgetTester tester, String text) => tester.widget<Align>(
    find.ancestor(of: find.text(text), matching: find.byType(Align)).first,
  );

  testWidgets('shows the tenant, dorm and an owner-side empty prompt', (
    tester,
  ) async {
    await openRoom(tester);

    expect(find.text('ผู้เช่าทดสอบ'), findsWidgets);
    expect(find.text('หอรวย เธะ'), findsOneWidget);
    expect(find.text('เริ่มต้นการสนทนากับ ผู้เช่าทดสอบ'), findsOneWidget);
    expect(service.joined, [chatTestRoomId]);
  });

  testWidgets('replies to a tenant: own reply on the right, tenant on the left', (
    tester,
  ) async {
    service.history = [
      chatTestMessage(1, chatTestOtherUser, 'ห้องยังว่างไหมครับ'),
    ];
    await openRoom(tester);

    await typeAndSend(tester, 'ว่างครับ มาดูได้เลย');

    expect(service.sentTexts, ['ว่างครับ มาดูได้เลย']);
    expect(bubbleOf(tester, 'ว่างครับ มาดูได้เลย').alignment, Alignment.centerRight);
    expect(bubbleOf(tester, 'ห้องยังว่างไหมครับ').alignment, Alignment.centerLeft);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('shows a booking notice from the system as a centered box', (
    tester,
  ) async {
    service.history = [
      chatTestSystemMessage(
        1,
        'แอดมินตรวจสอบค่ามัดจำห้อง A08 แล้ว รอคุณยืนยันการจอง',
      ),
    ];
    await openRoom(tester);

    const notice = 'แอดมินตรวจสอบค่ามัดจำห้อง A08 แล้ว รอคุณยืนยันการจอง';
    expect(find.text('แจ้งเตือนจากระบบ'), findsOneWidget);
    expect(find.text(notice), findsOneWidget); // ตัดคำนำหน้า "[แจ้งเตือนจากระบบ]" ออกแล้ว
    expect(find.textContaining('[แจ้งเตือนจากระบบ]'), findsNothing);
    // ไม่ใช่ฟองซ้าย/ขวา แต่อยู่กลางจอ
    expect(bubbleOf(tester, notice).alignment, Alignment.center);
  });

  testWidgets('shows a system notice that arrives while the room is open', (
    tester,
  ) async {
    await openRoom(tester);

    service.serverEmit(
      'new_message',
      chatTestSystemMessage(7, 'ผู้เช่าชำระค่ามัดจำแล้ว รอแอดมินตรวจสอบ'),
    );
    await tester.pump();

    expect(find.text('แจ้งเตือนจากระบบ'), findsOneWidget);
    expect(find.text('ผู้เช่าชำระค่ามัดจำแล้ว รอแอดมินตรวจสอบ'), findsOneWidget);
  });

  testWidgets('shows "read" on the owner reply after the tenant reads it', (
    tester,
  ) async {
    await openRoom(tester);
    await typeAndSend(tester, 'ส่งรูปห้องให้แล้วนะครับ');
    expect(find.textContaining('อ่านแล้ว'), findsNothing);

    service.serverEmit('messages_read', {
      'conversation_id': chatTestRoomId,
      'reader_id': chatTestOtherUser,
    });
    await tester.pump();

    expect(find.textContaining('อ่านแล้ว'), findsOneWidget);
  });

  testWidgets('keeps the reply and shows an error when sending fails', (
    tester,
  ) async {
    service.serverAcceptsMessage = false;
    await openRoom(tester);

    await typeAndSend(tester, 'ส่งไม่ออก');

    expect(find.text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ส่งไม่ออก',
    );
  });
}
