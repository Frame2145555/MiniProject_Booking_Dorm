// Widget test: หน้า Login / สมัครสมาชิก (AuthView)
// ทดสอบเฉพาะส่วนที่ไม่ยิงเครือข่าย: การตรวจข้อมูลฝั่งแอป, การสลับแท็บ, การ์ดผู้ใช้ที่ login แล้ว, logout
// (การยิง API จริงของ login/register ทดสอบใน auth_service_test.dart ด้วย MockClient)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/session.dart';
import '../lib/theme/app_theme.dart';
import '../lib/views/auth_view.dart';

const lblEmail = 'อีเมล';
const lblPassword = 'รหัสผ่าน (Password)';
const lblFirst = 'ชื่อจริง (First Name)';
const lblLast = 'นามสกุล (Last Name)';
const lblPhone = 'เบอร์โทรศัพท์ (Phone) — ไม่บังคับ';
const lblRegEmail = 'อีเมล (E-mail)';
const lblRegPassword = 'รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)';

Future<void> pumpAuth(WidgetTester tester, {bool embedded = true}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: AuthView(embedded: embedded)),
  );
  await tester.pump();
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> openRegisterTab(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'สมัครสมาชิก'));
  await tester.pumpAndSettle();
}

Future<void> fillRegister(
  WidgetTester tester, {
  String first = '',
  String last = '',
  String phone = '',
  String email = '',
  String password = '',
}) async {
  if (first.isNotEmpty) await tester.enterText(field(lblFirst), first);
  if (last.isNotEmpty) await tester.enterText(field(lblLast), last);
  if (phone.isNotEmpty) await tester.enterText(field(lblPhone), phone);
  if (email.isNotEmpty) await tester.enterText(field(lblRegEmail), email);
  if (password.isNotEmpty) await tester.enterText(field(lblRegPassword), password);
  await tester.pump();
}

Future<void> submitRegister(WidgetTester tester) async {
  await tester.tap(find.text('ยืนยันสมัครสมาชิก'));
  await tester.pump(); // แสดง SnackBar
}

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);

  group('แท็บเข้าสู่ระบบ', () {
    testWidgets('แสดงช่องอีเมล/รหัสผ่าน/ปุ่มเข้าสู่ระบบ และรหัสผ่านถูกซ่อน', (tester) async {
      await pumpAuth(tester);
      expect(field(lblEmail), findsOneWidget);
      expect(field(lblPassword), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'), findsOneWidget);
      expect(tester.widget<TextField>(field(lblPassword)).obscureText, isTrue);
    });

    testWidgets('มีแท็บ เข้าสู่ระบบ / สมัครสมาชิก', (tester) async {
      await pumpAuth(tester);
      expect(find.widgetWithText(Tab, 'เข้าสู่ระบบ'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'สมัครสมาชิก'), findsOneWidget);
    });

    testWidgets('ไม่กรอกอะไรเลย -> แจ้งให้กรอกอีเมลและรหัสผ่าน', (tester) async {
      await pumpAuth(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pump();
      expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });

    testWidgets('กรอกแต่อีเมล -> แจ้งให้กรอกรหัสผ่าน', (tester) async {
      await pumpAuth(tester);
      await tester.enterText(field(lblEmail), 'a@b.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pump();
      expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
    });

    testWidgets('อีเมลเป็นช่องว่างล้วน (ถูก trim) -> ไม่ผ่าน', (tester) async {
      await pumpAuth(tester);
      await tester.enterText(field(lblEmail), '    ');
      await tester.enterText(field(lblPassword), 'secret-pass');
      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pump();
      expect(find.text('กรุณากรอกอีเมลและรหัสผ่าน'), findsOneWidget);
    });
  });

  group('การ์ดผู้ใช้ที่ login แล้ว / logout', () {
    void loginAs(String role, {String name = 'สมชาย ใจดี', int id = 5}) {
      Session.token = 'tok';
      Session.userId = id;
      Session.role = role;
      Session.fullName = name;
      Session.loggedIn.value = true;
    }

    testWidgets('แสดงชื่อ บทบาท และ user id แทนฟอร์ม login', (tester) async {
      loginAs('seller');
      await pumpAuth(tester);
      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบเป็น เจ้าของหอ'), findsOneWidget);
      expect(find.text('user id 5'), findsOneWidget);
      expect(field(lblEmail), findsNothing);
    });

    for (final c in const {
      'seller': 'เจ้าของหอ',
      'admin': 'แอดมิน',
      'tenant': 'ผู้เช่า',
      '': 'ผู้เช่า',
      'อื่นๆ': 'ผู้เช่า',
    }.entries) {
      testWidgets('ป้ายบทบาท "${c.key}" -> "${c.value}"', (tester) async {
        loginAs(c.key);
        await pumpAuth(tester);
        expect(find.text('เข้าสู่ระบบเป็น ${c.value}'), findsOneWidget);
      });
    }

    testWidgets('กดออกจากระบบ -> ล้าง Session กลับไปเห็นฟอร์ม login', (tester) async {
      loginAs('tenant');
      await pumpAuth(tester);

      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pump();

      expect(Session.isLoggedIn, isFalse);
      expect(Session.loggedIn.value, isFalse);
      expect(find.text('ออกจากระบบแล้ว'), findsOneWidget);
      expect(field(lblEmail), findsOneWidget);
    });

    testWidgets('login/logout จากที่อื่น (Session.loggedIn เปลี่ยน) -> แท็บนี้อัปเดตเอง', (tester) async {
      await pumpAuth(tester);
      expect(field(lblEmail), findsOneWidget);

      loginAs('tenant', name: 'คนอื่น');
      await tester.pump();
      expect(find.text('เข้าสู่ระบบเป็น ผู้เช่า'), findsOneWidget);

      Session.clear();
      await tester.pump();
      expect(field(lblEmail), findsOneWidget);
    });
  });

  group('แท็บสมัครสมาชิก', () {
    testWidgets('สลับไปแท็บสมัครแล้วเห็นฟอร์มครบ + ตัวเลือกผู้เช่า/เจ้าของหอ', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);

      for (final l in [lblFirst, lblLast, lblPhone, lblRegEmail, lblRegPassword]) {
        expect(field(l), findsOneWidget, reason: l);
      }
      expect(find.text('ผู้เช่า'), findsOneWidget);
      expect(find.text('เจ้าของหอ'), findsOneWidget);
      expect(find.text('ยืนยันสมัครสมาชิก'), findsOneWidget);
      expect(tester.widget<TextField>(field(lblRegPassword)).obscureText, isTrue);
    });

    testWidgets('ว่างทั้งหมด -> แจ้งให้กรอกชื่อ อีเมล และรหัสผ่าน', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);
      await submitRegister(tester);
      expect(find.text('กรุณากรอกชื่อ อีเมล และรหัสผ่าน'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });

    testWidgets('ไม่ใส่ชื่อ -> ไม่ผ่าน', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);
      await fillRegister(tester, email: 'a@b.com', password: '12345678');
      await submitRegister(tester);
      expect(find.text('กรุณากรอกชื่อ อีเมล และรหัสผ่าน'), findsOneWidget);
    });

    testWidgets('ชื่อเป็นช่องว่างล้วน -> ไม่ผ่าน', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);
      await fillRegister(tester, first: '   ', last: '  ', email: 'a@b.com', password: '12345678');
      await submitRegister(tester);
      expect(find.text('กรุณากรอกชื่อ อีเมล และรหัสผ่าน'), findsOneWidget);
    });

    for (final bad in ['abc', 'abc@', 'a@b', 'a@b.c', 'a b@c.com', '@b.com']) {
      testWidgets('อีเมลรูปแบบผิด "$bad" -> แจ้งรูปแบบอีเมลไม่ถูกต้อง', (tester) async {
        await pumpAuth(tester);
        await openRegisterTab(tester);
        await fillRegister(tester, first: 'สมชาย', email: bad, password: '12345678');
        await submitRegister(tester);
        expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
        expect(Session.isLoggedIn, isFalse);
      });
    }

    testWidgets('รหัสผ่านสั้นกว่า 8 ตัว -> ไม่ผ่าน', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);
      await fillRegister(tester, first: 'สมชาย', email: 'a@b.com', password: '1234567');
      await submitRegister(tester);
      expect(find.text('รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });
  });
}
