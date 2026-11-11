// Unit test: AuthService (login / register / logout) + Session
// ใช้ MockClient แทน server จริง และ connectSocket: false เสมอ (ไม่ต่อ socket)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/services/api_config.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/session.dart';

/// ต้องใส่ charset=utf-8 ไม่งั้น http.Response จะเข้ารหัสเป็น latin1 แล้วภาษาไทยพัง
http.Response jsonRes(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> sessionBody({
  int id = 7,
  String role = 'tenant',
  String? fullName = 'สมชาย ใจดี',
}) =>
    {
      'token': 'jwt-token-abc',
      'id': id,
      'role': role,
      if (fullName != null) 'full_name': fullName,
      'email': 'a@b.com',
    };

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);

  group('Session', () {
    test('เริ่มต้น: ยังไม่ login', () {
      expect(Session.isLoggedIn, isFalse);
      expect(Session.token, '');
      expect(Session.userId, 0);
      expect(Session.role, '');
      expect(Session.fullName, '');
    });

    test('มี token = login แล้ว และ clear() ล้างทุกค่า + แจ้ง listener', () {
      Session.token = 't';
      Session.userId = 3;
      Session.role = 'seller';
      Session.fullName = 'ก';
      Session.loggedIn.value = true;
      expect(Session.isLoggedIn, isTrue);

      final events = <bool>[];
      void listener() => events.add(Session.loggedIn.value);
      Session.loggedIn.addListener(listener);
      addTearDown(() => Session.loggedIn.removeListener(listener));

      Session.clear();

      expect(Session.isLoggedIn, isFalse);
      expect([Session.token, Session.userId, Session.role, Session.fullName], ['', 0, '', '']);
      expect(Session.loggedIn.value, isFalse);
      expect(events, [false]);
    });
  });

  group('AuthService.login', () {
    test('สำเร็จ (200) -> คืน null และตั้งค่า Session ครบ', () async {
      final client = MockClient((_) async => jsonRes(sessionBody(role: 'seller'), 200));

      final err = await AuthService.login('a@b.com', '12345678', client: client, connectSocket: false);

      expect(err, isNull);
      expect(Session.isLoggedIn, isTrue);
      expect(Session.token, 'jwt-token-abc');
      expect(Session.userId, 7);
      expect(Session.role, 'seller');
      expect(Session.fullName, 'สมชาย ใจดี');
      expect(Session.loggedIn.value, isTrue);
    });

    test('ส่ง request ถูกต้อง: POST /api/login, JSON {email,password}, header ngrok', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return jsonRes(sessionBody(), 200);
      });

      await AuthService.login('a@b.com', 'pw-12345', client: client, connectSocket: false);

      expect(captured.method, 'POST');
      expect(captured.url, Uri.parse('${ApiConfig.baseUrl}/api/login'));
      expect(captured.headers['Content-Type'] ?? captured.headers['content-type'], contains('application/json'));
      expect(captured.headers['ngrok-skip-browser-warning'], 'true');
      expect(jsonDecode(captured.body), {'email': 'a@b.com', 'password': 'pw-12345'});
    });

    test('full_name ไม่มีใน response -> ใช้ค่าว่าง ไม่พัง', () async {
      final client = MockClient((_) async => jsonRes(sessionBody(fullName: null), 200));
      final err = await AuthService.login('a@b.com', 'x', client: client, connectSocket: false);
      expect(err, isNull);
      expect(Session.fullName, '');
    });

    test('401 -> อีเมลหรือรหัสผ่านไม่ถูกต้อง และ Session ไม่เปลี่ยน', () async {
      final client = MockClient((_) async => jsonRes({'error': 'อะไรก็ได้'}, 401));
      final err = await AuthService.login('a@b.com', 'bad', client: client, connectSocket: false);
      expect(err, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      expect(Session.isLoggedIn, isFalse);
      expect(Session.loggedIn.value, isFalse);
    });

    test('403 -> บัญชีนี้ถูกระงับ', () async {
      final client = MockClient((_) async => jsonRes({'error': 'x'}, 403));
      final err = await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
      expect(err, 'บัญชีนี้ถูกระงับ');
      expect(Session.isLoggedIn, isFalse);
    });

    test('429 -> แสดงข้อความไทยที่ server ส่งมา', () async {
      final client = MockClient(
        (_) async => jsonRes({'error': 'ลองเข้าสู่ระบบผิดหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่'}, 429),
      );
      final err = await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
      expect(err, 'ลองเข้าสู่ระบบผิดหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่');
    });

    test('400 ที่ body ไม่ใช่ JSON / ไม่มี error -> ข้อความสำรองมีรหัสสถานะ', () async {
      for (final body in ['<html>bad</html>', '{}', '{"error": ""}', '{"error": 5}']) {
        final client = MockClient(
          (_) async => http.Response(body, 400, headers: {'content-type': 'text/plain; charset=utf-8'}),
        );
        final err = await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
        expect(err, 'ข้อมูลไม่ถูกต้อง (400)', reason: body);
      }
    });

    test('500 -> เข้าสู่ระบบไม่สำเร็จ (500) พร้อม URL', () async {
      final client = MockClient((_) async => http.Response('oops', 500));
      final err = await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
      expect(err, contains('500'));
      expect(err, contains('${ApiConfig.baseUrl}/api/login'));
      expect(Session.isLoggedIn, isFalse);
    });

    test('เชื่อมต่อ server ไม่ได้ (exception) -> ข้อความบอกให้เช็ค server', () async {
      final client = MockClient((_) async => throw http.ClientException('connection refused'));
      final err = await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
      expect(err, startsWith('เชื่อมต่อ'));
      expect(err, contains(ApiConfig.baseUrl));
      expect(Session.isLoggedIn, isFalse);
    });

    test('login ซ้อนขณะมีบัญชีเดิม -> แทนที่ด้วยบัญชีใหม่ทั้งหมด', () async {
      Session.token = 'old-token';
      Session.userId = 1;
      Session.role = 'admin';
      Session.fullName = 'คนเก่า';
      Session.loggedIn.value = true;

      final events = <bool>[];
      void listener() => events.add(Session.loggedIn.value);
      Session.loggedIn.addListener(listener);
      addTearDown(() => Session.loggedIn.removeListener(listener));

      final client = MockClient((_) async => jsonRes(sessionBody(id: 9, role: 'tenant', fullName: 'คนใหม่'), 200));
      final err = await AuthService.login('new@b.com', 'pw', client: client, connectSocket: false);

      expect(err, isNull);
      expect(Session.token, 'jwt-token-abc');
      expect(Session.userId, 9);
      expect(Session.role, 'tenant');
      expect(Session.fullName, 'คนใหม่');
      expect(Session.loggedIn.value, isTrue);
      expect(events.last, isTrue, reason: 'สถานะสุดท้ายที่หน้าอื่นเห็นต้องเป็น login แล้ว');
    });
  });

  group('AuthService.register', () {
    test('สำเร็จ (201) -> login ให้อัตโนมัติ', () async {
      final client = MockClient((_) async => jsonRes(sessionBody(id: 21, role: 'seller'), 201));

      final err = await AuthService.register(
        email: 'new@b.com',
        password: '12345678',
        fullName: 'ผู้ใช้ ใหม่',
        role: 'seller',
        client: client,
        connectSocket: false,
      );

      expect(err, isNull);
      expect(Session.isLoggedIn, isTrue);
      expect(Session.userId, 21);
      expect(Session.role, 'seller');
      expect(Session.loggedIn.value, isTrue);
    });

    test('body: full_name / role ถูกส่งตาม API, role เริ่มต้น tenant', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return jsonRes(sessionBody(), 201);
      });

      await AuthService.register(
        email: 'new@b.com',
        password: '12345678',
        fullName: 'ผู้ใช้ ใหม่',
        client: client,
        connectSocket: false,
      );

      expect(captured.method, 'POST');
      expect(captured.url, Uri.parse('${ApiConfig.baseUrl}/api/register'));
      expect(jsonDecode(captured.body), {
        'email': 'new@b.com',
        'password': '12345678',
        'full_name': 'ผู้ใช้ ใหม่',
        'role': 'tenant',
      });
    });

    test('phone: ถูก trim / ว่าง-null ไม่ถูกส่ง', () async {
      Future<Map<String, dynamic>> bodyFor(String? phone) async {
        late http.Request captured;
        final client = MockClient((req) async {
          captured = req;
          return jsonRes(sessionBody(), 201);
        });
        await AuthService.register(
          email: 'a@b.com',
          password: '12345678',
          fullName: 'ก',
          phone: phone,
          client: client,
          connectSocket: false,
        );
        Session.clear();
        return jsonDecode(captured.body) as Map<String, dynamic>;
      }

      expect((await bodyFor('  081-234-5678 '))['phone'], '081-234-5678');
      expect((await bodyFor('   ')).containsKey('phone'), isFalse);
      expect((await bodyFor('')).containsKey('phone'), isFalse);
      expect((await bodyFor(null)).containsKey('phone'), isFalse);
    });

    test('409 อีเมลซ้ำ -> แสดงข้อความไทยจาก server และไม่ login', () async {
      final client = MockClient((_) async => jsonRes({'error': 'อีเมลนี้ถูกใช้งานแล้ว'}, 409));
      final err = await AuthService.register(
        email: 'dup@b.com',
        password: '12345678',
        fullName: 'ก',
        client: client,
        connectSocket: false,
      );
      expect(err, 'อีเมลนี้ถูกใช้งานแล้ว');
      expect(Session.isLoggedIn, isFalse);
    });

    test('400 ข้อมูลไม่ถูกต้อง -> ข้อความจาก server / ไม่มีข้อความ -> ข้อความสำรอง', () async {
      var client = MockClient((_) async => jsonRes({'error': 'รูปแบบอีเมลไม่ถูกต้อง'}, 400));
      expect(
        await AuthService.register(email: 'x', password: '12345678', fullName: 'ก', client: client, connectSocket: false),
        'รูปแบบอีเมลไม่ถูกต้อง',
      );

      client = MockClient((_) async => http.Response('', 400));
      expect(
        await AuthService.register(email: 'x', password: '12345678', fullName: 'ก', client: client, connectSocket: false),
        'ข้อมูลไม่ถูกต้อง (400)',
      );
    });

    test('429 สมัครบ่อยเกินไป -> ข้อความจาก server', () async {
      final client = MockClient((_) async => jsonRes({'error': 'สมัครบ่อยเกินไป กรุณาลองใหม่ภายหลัง'}, 429));
      final err = await AuthService.register(
        email: 'a@b.com',
        password: '12345678',
        fullName: 'ก',
        client: client,
        connectSocket: false,
      );
      expect(err, 'สมัครบ่อยเกินไป กรุณาลองใหม่ภายหลัง');
    });

    test('server ล่ม -> ข้อความเชื่อมต่อไม่ได้', () async {
      final client = MockClient((_) async => throw http.ClientException('down'));
      final err = await AuthService.register(
        email: 'a@b.com',
        password: '12345678',
        fullName: 'ก',
        client: client,
        connectSocket: false,
      );
      expect(err, startsWith('เชื่อมต่อ'));
    });
  });

  group('AuthService.logout', () {
    test('ล้าง Session และแจ้ง loggedIn = false', () async {
      final client = MockClient((_) async => jsonRes(sessionBody(), 200));
      await AuthService.login('a@b.com', 'pw', client: client, connectSocket: false);
      expect(Session.isLoggedIn, isTrue);

      AuthService.logout();

      expect(Session.isLoggedIn, isFalse);
      expect(Session.userId, 0);
      expect(Session.role, '');
      expect(Session.fullName, '');
      expect(Session.loggedIn.value, isFalse);
    });

    test('logout ตอนยังไม่ login ไม่ throw', () {
      expect(AuthService.logout, returnsNormally);
    });
  });
}
