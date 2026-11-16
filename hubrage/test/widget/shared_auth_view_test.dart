// Widget test: หน้า Login / สมัครสมาชิก (AuthView)
// ทดสอบฟอร์มและ flow login/register ด้วย Mocktail โดยไม่ยิง server จริง
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/auth_view.dart';

const lblEmail = 'อีเมล';
const lblPassword = 'รหัสผ่าน (Password)';
const lblFirst = 'ชื่อจริง (First Name)';
const lblLast = 'นามสกุล (Last Name)';
const lblPhone = 'เบอร์โทรศัพท์ (Phone) — ไม่บังคับ';
const lblRegEmail = 'อีเมล (E-mail)';
const lblRegPassword = 'รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)';

class MockHttpClient extends Mock implements http.Client {}

void stubPostResponse(
  MockHttpClient client,
  http.Response response, {
  void Function(Uri url, Object? body)? onPost,
}) {
  when(
    () => client.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((invocation) async {
    onPost?.call(
      invocation.positionalArguments.single as Uri,
      invocation.namedArguments[#body],
    );
    return response;
  });
}

http.Response fakeResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpAuth(
  WidgetTester tester, {
  bool embedded = true,
  http.Client? authClient,
  bool connectSocket = true,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: AuthView(
        embedded: embedded,
        authClient: authClient,
        connectSocket: connectSocket,
      ),
    ),
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
  if (password.isNotEmpty)
    await tester.enterText(field(lblRegPassword), password);
  await tester.pump();
}

Future<void> submitRegister(WidgetTester tester) async {
  await tester.tap(find.text('ยืนยันสมัครสมาชิก'));
  await tester.pump(); // แสดง SnackBar
}

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);
  setUpAll(() => registerFallbackValue(Uri.parse('https://example.test')));

  group('แท็บเข้าสู่ระบบ', () {
    testWidgets('แสดงช่องอีเมล/รหัสผ่าน/ปุ่มเข้าสู่ระบบ และรหัสผ่านถูกซ่อน', (
      tester,
    ) async {
      await pumpAuth(tester);
      expect(field(lblEmail), findsOneWidget);
      expect(field(lblPassword), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field(lblPassword)).obscureText, isTrue);
    });

    testWidgets('มีแท็บ เข้าสู่ระบบ / สมัครสมาชิก', (tester) async {
      await pumpAuth(tester);
      expect(find.widgetWithText(Tab, 'เข้าสู่ระบบ'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'สมัครสมาชิก'), findsOneWidget);
    });

    testWidgets('ไม่กรอกอะไรเลย -> แจ้งให้กรอกอีเมลและรหัสผ่าน', (
      tester,
    ) async {
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

    testWidgets('login สำเร็จ -> ส่งข้อมูลและแสดงบัญชีผู้ใช้', (tester) async {
      late Uri sentUrl;
      late Object? sentBody;
      final client = MockHttpClient();
      stubPostResponse(
        client,
        fakeResponse({
          'token': 'test-token',
          'id': 42,
          'role': 'seller',
          'full_name': 'สมชาย ใจดี',
        }, 200),
        onPost: (url, body) {
          sentUrl = url;
          sentBody = body;
        },
      );

      await pumpAuth(tester, authClient: client, connectSocket: false);
      await tester.enterText(field(lblEmail), ' user@test.com ');
      await tester.enterText(field(lblPassword), 'secret-pass');
      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();

      expect(sentUrl.path, '/api/login');
      expect(jsonDecode(sentBody! as String), {
        'email': 'user@test.com',
        'password': 'secret-pass',
      });
      expect(Session.token, 'test-token');
      expect(Session.userId, 42);
      expect(Session.role, 'seller');
      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบสำเร็จ'), findsOneWidget);
    });

    testWidgets('login ไม่สำเร็จ -> แสดง error และยังไม่ login', (
      tester,
    ) async {
      final client = MockHttpClient();
      stubPostResponse(
        client,
        fakeResponse({'error': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'}, 401),
      );

      await pumpAuth(tester, authClient: client, connectSocket: false);
      await tester.enterText(field(lblEmail), 'user@test.com');
      await tester.enterText(field(lblPassword), 'wrong-pass');
      await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();

      expect(find.text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });

    for (final entry in const {
      'tenant': 'ผู้เช่า',
      'seller': 'เจ้าของหอ',
      'admin': 'แอดมิน',
    }.entries) {
      testWidgets('login เป็น ${entry.value} แล้วแสดง role ถูกต้อง', (
        tester,
      ) async {
        final client = MockHttpClient();
        stubPostResponse(
          client,
          fakeResponse({
            'token': 'test-token',
            'id': 8,
            'role': entry.key,
            'full_name': 'ผู้ใช้ทดสอบ',
          }, 200),
        );

        await pumpAuth(tester, authClient: client, connectSocket: false);
        await tester.enterText(field(lblEmail), 'user@test.com');
        await tester.enterText(field(lblPassword), 'secret-pass');
        await tester.tap(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'));
        await tester.pumpAndSettle();

        expect(find.text('เข้าสู่ระบบเป็น ${entry.value}'), findsOneWidget);
      });
    }
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

    testWidgets('กดออกจากระบบ -> ล้าง Session กลับไปเห็นฟอร์ม login', (
      tester,
    ) async {
      loginAs('tenant');
      await pumpAuth(tester);

      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pump();

      expect(Session.isLoggedIn, isFalse);
      expect(Session.loggedIn.value, isFalse);
      expect(find.text('ออกจากระบบแล้ว'), findsOneWidget);
      expect(field(lblEmail), findsOneWidget);
    });

    testWidgets(
      'login/logout จากที่อื่น (Session.loggedIn เปลี่ยน) -> แท็บนี้อัปเดตเอง',
      (tester) async {
        await pumpAuth(tester);
        expect(field(lblEmail), findsOneWidget);

        loginAs('tenant', name: 'คนอื่น');
        await tester.pump();
        expect(find.text('เข้าสู่ระบบเป็น ผู้เช่า'), findsOneWidget);

        Session.clear();
        await tester.pump();
        expect(field(lblEmail), findsOneWidget);
      },
    );
  });

  group('แท็บสมัครสมาชิก', () {
    testWidgets('สลับไปแท็บสมัครแล้วเห็นฟอร์มครบ + ตัวเลือกผู้เช่า/เจ้าของหอ', (
      tester,
    ) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);

      for (final l in [
        lblFirst,
        lblLast,
        lblPhone,
        lblRegEmail,
        lblRegPassword,
      ]) {
        expect(field(l), findsOneWidget, reason: l);
      }
      expect(find.text('ผู้เช่า'), findsOneWidget);
      expect(find.text('เจ้าของหอ'), findsOneWidget);
      expect(find.text('ยืนยันสมัครสมาชิก'), findsOneWidget);
      expect(
        tester.widget<TextField>(field(lblRegPassword)).obscureText,
        isTrue,
      );
    });

    testWidgets('ว่างทั้งหมด -> แจ้งให้กรอกชื่อ อีเมล และรหัสผ่าน', (
      tester,
    ) async {
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
      await fillRegister(
        tester,
        first: '   ',
        last: '  ',
        email: 'a@b.com',
        password: '12345678',
      );
      await submitRegister(tester);
      expect(find.text('กรุณากรอกชื่อ อีเมล และรหัสผ่าน'), findsOneWidget);
    });

    for (final bad in ['abc', 'abc@', 'a@b', 'a@b.c', 'a b@c.com', '@b.com']) {
      testWidgets('อีเมลรูปแบบผิด "$bad" -> แจ้งรูปแบบอีเมลไม่ถูกต้อง', (
        tester,
      ) async {
        await pumpAuth(tester);
        await openRegisterTab(tester);
        await fillRegister(
          tester,
          first: 'สมชาย',
          email: bad,
          password: '12345678',
        );
        await submitRegister(tester);
        expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
        expect(Session.isLoggedIn, isFalse);
      });
    }

    testWidgets('รหัสผ่านสั้นกว่า 8 ตัว -> ไม่ผ่าน', (tester) async {
      await pumpAuth(tester);
      await openRegisterTab(tester);
      await fillRegister(
        tester,
        first: 'สมชาย',
        email: 'a@b.com',
        password: '1234567',
      );
      await submitRegister(tester);
      expect(find.text('รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });

    for (final role in const {
      'ผู้เช่า': 'tenant',
      'เจ้าของหอ': 'seller',
    }.entries) {
      testWidgets('สมัครเป็น${role.key}สำเร็จ -> ส่งข้อมูลและกลับแท็บ login', (
        tester,
      ) async {
        late Uri sentUrl;
        late Object? sentBody;
        final client = MockHttpClient();
        stubPostResponse(
          client,
          fakeResponse({'id': 9}, 201),
          onPost: (url, body) {
            sentUrl = url;
            sentBody = body;
          },
        );

        await pumpAuth(tester, authClient: client);
        await openRegisterTab(tester);
        if (role.key == 'เจ้าของหอ') {
          await tester.tap(find.text(role.key));
          await tester.pump();
        }
        await fillRegister(
          tester,
          first: ' สมชาย ',
          last: ' ใจดี ',
          phone: ' 0812345678 ',
          email: ' user@test.com ',
          password: 'secret-pass',
        );
        await submitRegister(tester);
        await tester.pumpAndSettle();

        expect(sentUrl.path, '/api/register');
        expect(jsonDecode(sentBody! as String), {
          'email': 'user@test.com',
          'password': 'secret-pass',
          'full_name': 'สมชาย ใจดี',
          'phone': '0812345678',
          'role': role.value,
        });
        expect(find.text('สมัครสมาชิกสำเร็จ'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'เข้าสู่ระบบ'), findsOneWidget);
        expect(Session.isLoggedIn, isFalse);
      });
    }

    testWidgets('สมัครไม่สำเร็จ -> แสดงข้อความจาก server', (tester) async {
      final client = MockHttpClient();
      stubPostResponse(
        client,
        fakeResponse({'error': 'อีเมลนี้ถูกใช้งานแล้ว'}, 409),
      );

      await pumpAuth(tester, authClient: client);
      await openRegisterTab(tester);
      await fillRegister(
        tester,
        first: 'สมชาย',
        email: 'user@test.com',
        password: 'secret-pass',
      );
      await submitRegister(tester);
      await tester.pumpAndSettle();

      expect(find.text('อีเมลนี้ถูกใช้งานแล้ว'), findsOneWidget);
      expect(find.text(lblFirst), findsOneWidget);
      expect(Session.isLoggedIn, isFalse);
    });
  });
}
