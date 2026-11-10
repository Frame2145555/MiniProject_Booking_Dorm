// Widget test: เปิดหน้าจอจำลอง แล้วพิมพ์/กด/เช็คว่าแสดงผลถูก (ไม่ต้องมี server)
// ใช้แทนไฟล์ widget_test.dart (counter) ของ template เดิม
// วิธีรัน: flutter test test/widget_test.dart --reporter expanded
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/session.dart';
import '../lib/theme/app_theme.dart';
import '../lib/views/auth_view.dart';
import '../lib/views/chat_room_view.dart';
import '../lib/views/chat_view.dart';
import 'fake_chat_service.dart';

const me = 1;
const otherUser = 2;
const roomId = 10;

Widget app(Widget page) => MaterialApp(theme: AppTheme.light(), home: page);

Map<String, dynamic> message(int id, int senderId, String text) => {
      'id': id,
      'conversation_id': roomId,
      'sender_id': senderId,
      'text': text,
      'sent_at': '2026-11-09T08:00:00.000Z',
      'read_at': null,
    };

Map<String, dynamic> conversation({String lastMessage = 'ว่างครับ', int unread = 0}) => {
      'id': roomId,
      'other_name': 'เจ้าของหอทดสอบ',
      'dorm_name': 'หอรวย เธะ',
      'last_message': lastMessage,
      'unread': unread,
    };

/// จำลองว่า login แล้ว (เหมือนที่ AuthService.login ทำ แต่ไม่ต้องมี server)
void loginAs(int userId, {String role = 'tenant'}) {
  Session.token = 'fake-token';
  Session.userId = userId;
  Session.role = role;
  Session.fullName = 'ผู้เช่าทดสอบ';
  Session.loggedIn.value = true;
}

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = FakeChatService(myId: me);
  });

  // เปิดหน้าห้องแชทแล้วรอโหลดประวัติเสร็จ
  Future<void> openRoom(WidgetTester tester) async {
    await tester.pumpWidget(app(ChatRoomView(
      conversationId: roomId,
      title: 'เจ้าของหอทดสอบ',
      subtitle: 'หอรวย เธะ',
      service: service,
    )));
    await tester.pumpAndSettle();
  }

  // พิมพ์ข้อความแล้วกดปุ่มส่ง
  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  //=================== หน้าห้องแชท =======================
  group('หน้าห้องแชท (ChatRoomView)', () {
    testWidgets('แสดงชื่อคู่แชท ชื่อหอ และประวัติข้อความ', (tester) async {
      loginAs(me);
      service.history = [
        message(1, otherUser, 'สวัสดีครับ'),
        message(2, me, 'ห้องยังว่างไหมครับ'),
      ];

      await openRoom(tester);

      expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
      expect(find.text('หอรวย เธะ'), findsOneWidget);
      expect(find.text('สวัสดีครับ'), findsOneWidget);
      expect(find.text('ห้องยังว่างไหมครับ'), findsOneWidget);
    });

    testWidgets('ยังไม่มีข้อความ แสดงข้อความชวนเริ่มคุย', (tester) async {
      loginAs(me);
      await openRoom(tester);

      expect(find.text('เริ่มต้นการสนทนากับ เจ้าของหอทดสอบ'), findsOneWidget);
    });

    testWidgets('พิมพ์แล้วกดส่ง -> ข้อความขึ้นบนจอ และช่องพิมพ์ว่าง', (tester) async {
      loginAs(me);
      await openRoom(tester);

      await typeAndSend(tester, 'ห้องยังว่างไหมครับ');

      expect(service.sentTexts, ['ห้องยังว่างไหมครับ']);
      expect(find.text('ห้องยังว่างไหมครับ'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('ข้อความของเราอยู่ขวา ของอีกฝั่งอยู่ซ้าย', (tester) async {
      loginAs(me);
      service.history = [
        message(1, otherUser, 'ข้อความอีกฝั่ง'),
        message(2, me, 'ข้อความเรา'),
      ];
      await openRoom(tester);

      Align bubbleOf(String text) => tester.widget<Align>(
          find.ancestor(of: find.text(text), matching: find.byType(Align)).first);
      expect(bubbleOf('ข้อความเรา').alignment, Alignment.centerRight);
      expect(bubbleOf('ข้อความอีกฝั่ง').alignment, Alignment.centerLeft);
    });

    testWidgets('อีกฝั่งส่งข้อความมา -> ขึ้นบนจอทันที', (tester) async {
      loginAs(me);
      await openRoom(tester);
      expect(find.text('ว่างครับ มาดูได้เลย'), findsNothing);

      service.serverEmit('new_message', message(5, otherUser, 'ว่างครับ มาดูได้เลย'));
      await tester.pump();

      expect(find.text('ว่างครับ มาดูได้เลย'), findsOneWidget);
    });

    testWidgets('ส่งไม่สำเร็จ -> แจ้งเตือน และข้อความยังอยู่ในช่องพิมพ์', (tester) async {
      loginAs(me);
      service.serverAcceptsMessage = false;
      await openRoom(tester);

      await typeAndSend(tester, 'ส่งไม่ออก');

      expect(find.text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ส่งไม่ออก'); // ไม่ต้องพิมพ์ใหม่
    });

    testWidgets('กดส่งตอนช่องว่าง -> ไม่ส่ง ไม่แจ้งเตือน', (tester) async {
      loginAs(me);
      await openRoom(tester);

      await typeAndSend(tester, '   ');

      expect(service.sentTexts, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('อีกฝั่งอ่านแล้ว -> ข้อความเราขึ้น "อ่านแล้ว"', (tester) async {
      loginAs(me);
      await openRoom(tester);
      await typeAndSend(tester, 'อ่านหรือยัง');
      expect(find.textContaining('อ่านแล้ว'), findsNothing);

      service.serverEmit('messages_read', {'conversation_id': roomId, 'reader_id': otherUser});
      await tester.pump();

      expect(find.textContaining('อ่านแล้ว'), findsOneWidget);
    });
  });

  //=================== หน้ารายการแชท =======================
  group('หน้ารายการแชท (ChatView)', () {
    testWidgets('ยังไม่ login -> ชวนเข้าสู่ระบบ และไม่โหลดรายการ', (tester) async {
      await tester.pumpWidget(app(ChatView(service: service)));

      expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);
      expect(find.text('ไปหน้าเข้าสู่ระบบ'), findsOneWidget);
      expect(service.fetchConversationsCount, 0);
    });

    testWidgets('เปิดหน้าไว้ก่อน แล้วค่อย login -> รายการแชทขึ้นเอง', (tester) async {
      // เหมือนใน NavigationShell ที่สร้างหน้าแชทไว้ตั้งแต่เปิดแอป
      service.conversationList = [conversation()];
      await tester.pumpWidget(app(ChatView(embedded: true, service: service)));
      expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);

      loginAs(me);
      await tester.pumpAndSettle();

      expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
      expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsNothing);
    });

    testWidgets('logout -> รายการแชทหาย กลับเป็นหน้าชวนเข้าสู่ระบบ', (tester) async {
      loginAs(me);
      service.conversationList = [conversation()];
      await tester.pumpWidget(app(ChatView(embedded: true, service: service)));
      await tester.pumpAndSettle();
      expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);

      Session.clear();
      await tester.pumpAndSettle();

      expect(find.text('เจ้าของหอทดสอบ'), findsNothing);
      expect(find.text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท'), findsOneWidget);
    });

    testWidgets('login แล้วไม่มีห้อง -> แสดงว่ายังไม่มีห้องแชท', (tester) async {
      loginAs(me);
      await tester.pumpWidget(app(ChatView(service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('ยังไม่มีห้องแชท'), findsOneWidget);
    });

    testWidgets('แสดงชื่อ ชื่อหอ ข้อความล่าสุด และจำนวนที่ยังไม่อ่าน', (tester) async {
      loginAs(me);
      service.conversationList = [conversation(lastMessage: 'ว่างครับ', unread: 3)];

      await tester.pumpWidget(app(ChatView(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);
      expect(find.text('หอรวย เธะ'), findsOneWidget);
      expect(find.text('ว่างครับ'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // ป้ายจำนวนยังไม่อ่าน
    });

    testWidgets('มุมมองเจ้าของหอ: หัวข้อ "แชทผู้เช่า" และขึ้นว่าผู้เช่าสนใจหอไหน', (tester) async {
      loginAs(me, role: 'seller');
      service.conversationList = [conversation()];

      await tester.pumpWidget(app(ChatView(asSeller: true, service: service)));
      await tester.pumpAndSettle();

      expect(find.text('แชทผู้เช่า'), findsOneWidget);
      expect(find.text('สนใจ หอรวย เธะ'), findsOneWidget);
    });

    testWidgets('มีข้อความใหม่ -> รายการอัปเดตเองโดยไม่ต้องรีเฟรช', (tester) async {
      loginAs(me);
      service.conversationList = [conversation(lastMessage: 'เก่า')];
      await tester.pumpWidget(app(ChatView(service: service)));
      await tester.pumpAndSettle();
      expect(find.text('เก่า'), findsOneWidget);

      service.conversationList = [conversation(lastMessage: 'ใหม่', unread: 1)];
      service.serverEmit('conversation_updated', {'conversation_id': roomId});
      await tester.pumpAndSettle();

      expect(find.text('ใหม่'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('กดที่ห้อง -> เปิดหน้าห้องแชทของห้องนั้น', (tester) async {
      loginAs(me);
      service.conversationList = [conversation()];
      service.history = [message(1, otherUser, 'สวัสดีครับ')];
      await tester.pumpWidget(app(ChatView(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('เจ้าของหอทดสอบ'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatRoomView), findsOneWidget);
      expect(find.text('สวัสดีครับ'), findsOneWidget);
      expect(service.joined, [roomId]);
    });
  });

  //=================== หน้าบัญชี =======================
  group('หน้าบัญชี (AuthView)', () {
    testWidgets('กดเข้าสู่ระบบโดยไม่กรอก -> เตือน', (tester) async {
      await tester.pumpWidget(app(const AuthView()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pump();

      expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });

    testWidgets('login อยู่แล้ว -> แสดงชื่อ และกดออกจากระบบได้', (tester) async {
      loginAs(me);
      await tester.pumpWidget(app(const AuthView()));
      expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบเป็น ผู้เช่า'), findsOneWidget);

      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pump();

      expect(Session.isLoggedIn, isFalse);
      expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);
    });

    testWidgets('แท็บบัญชี (embedded) เปลี่ยนเป็น "เข้าสู่ระบบแล้ว" เองเมื่อ login จากที่อื่น',
        (tester) async {
      await tester.pumpWidget(app(const AuthView(embedded: true)));
      expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);

      loginAs(me, role: 'seller');
      await tester.pump();

      expect(find.text('เข้าสู่ระบบเป็น เจ้าของหอ'), findsOneWidget);
      expect(find.text('ออกจากระบบ'), findsOneWidget);
    });
  });
}
