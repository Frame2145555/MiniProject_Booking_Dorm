// Widget test: เปิดหน้าจอจำลองแล้วเช็คว่าแสดงผลถูก (ไม่ต้องมี server)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/session.dart';
import '../lib/views/auth_view.dart';
import '../lib/views/chat_view.dart';

Widget app(Widget page) => MaterialApp(home: page);

void main() {
  setUp(() => Session.clear());

  testWidgets('หน้าแชท: ยังไม่ login ต้องบอกให้เข้าสู่ระบบก่อน', (tester) async {
    await tester.pumpWidget(app(const ChatView()));

    expect(find.textContaining('กรุณาเข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('หน้า login: กดเข้าสู่ระบบโดยไม่กรอก ต้องเตือน', (tester) async {
    await tester.pumpWidget(app(const AuthView()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
    await tester.pump();

    expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
    expect(Session.isLoggedIn, isFalse);
  });

  testWidgets('หน้าบัญชี: login อยู่แล้วแสดงชื่อ และกดออกจากระบบได้', (tester) async {
    Session.token = 'fake-token';
    Session.userId = 1;
    Session.role = 'tenant';
    Session.fullName = 'ผู้เช่าทดสอบ';

    await tester.pumpWidget(app(const AuthView()));
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.textContaining('ผู้เช่า •'), findsOneWidget);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pump();

    expect(Session.isLoggedIn, isFalse);
    expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);
  });
}
