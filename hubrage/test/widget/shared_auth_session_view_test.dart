import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/auth_view.dart';
import '../support/chat_widget_test_helpers.dart';

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);

  testWidgets('prompts for login when the account tab is submitted empty', (
    tester,
  ) async {
    await tester.pumpWidget(chatTestApp(const AuthView()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
    await tester.pump();

    expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
    expect(Session.isLoggedIn, isFalse);
  });

  testWidgets('shows the signed-in account and supports logout', (
    tester,
  ) async {
    loginChatTestUser();
    await tester.pumpWidget(chatTestApp(const AuthView()));

    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบเป็น ผู้เช่า'), findsOneWidget);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pump();

    expect(Session.isLoggedIn, isFalse);
    expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);
  });

  testWidgets('updates an embedded account tab when another view logs in', (
    tester,
  ) async {
    await tester.pumpWidget(chatTestApp(const AuthView(embedded: true)));
    expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);

    loginChatTestUser(role: 'seller');
    await tester.pump();

    expect(find.text('เข้าสู่ระบบเป็น เจ้าของหอ'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
  });
}
