// Unit test AuthService.login โดยใช้ MockClient แทน server จริง (ไม่ต้องเปิด node / MySQL)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/services/auth_service.dart';
import '../lib/services/session.dart';

// สร้าง response ปลอม (ต้องบอก charset=utf-8 ไม่งั้นภาษาไทยพัง)
http.Response fakeResponse(Object body, int status) => http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => Session.clear());

  test('login สำเร็จ: ยิงไปที่ /api/login และเก็บข้อมูลลง Session', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return fakeResponse({
        'token': 'jwt-token',
        'id': 1,
        'role': 'tenant',
        'full_name': 'ผู้เช่าทดสอบ',
      }, 200);
    });

    final error = await AuthService.login(
      'tenant@test.com',
      '1234',
      client: client,
      connectSocket: false,
    );

    expect(error, isNull);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/login'); // ต้องไม่ใช่ //api/login
    expect(jsonDecode(sent.body), {'email': 'tenant@test.com', 'password': '1234'});
    expect(Session.isLoggedIn, isTrue);
    expect(Session.token, 'jwt-token');
    expect(Session.userId, 1);
    expect(Session.role, 'tenant');
    expect(Session.fullName, 'ผู้เช่าทดสอบ');
  });

  test('รหัสผิด (401): ได้ข้อความ error และยังไม่ login', () async {
    final client = MockClient((_) async => fakeResponse('Wrong password', 401));
    final error = await AuthService.login('tenant@test.com', 'wrong',
        client: client, connectSocket: false);

    expect(error, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    expect(Session.isLoggedIn, isFalse);
  });

  test('บัญชีถูกระงับ (403)', () async {
    final client = MockClient((_) async => fakeResponse('Account suspended', 403));
    final error = await AuthService.login('seller@test.com', '1234',
        client: client, connectSocket: false);

    expect(error, 'บัญชีนี้ถูกระงับ');
    expect(Session.isLoggedIn, isFalse);
  });

  test('URL ผิด (404): ข้อความ error บอกรหัส 404 และ URL ที่ยิงไป', () async {
    final client = MockClient((_) async => fakeResponse('Not Found', 404));
    final error = await AuthService.login('tenant@test.com', '1234',
        client: client, connectSocket: false);

    expect(error, contains('404'));
    expect(error, contains('/api/login'));
    expect(Session.isLoggedIn, isFalse);
  });

  test('ต่อ server ไม่ได้: ได้ข้อความ error ไม่ crash', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    final error = await AuthService.login('tenant@test.com', '1234',
        client: client, connectSocket: false);

    expect(error, contains('ไม่ได้'));
    expect(Session.isLoggedIn, isFalse);
  });

  test('logout ล้าง Session', () async {
    final client = MockClient((_) async => fakeResponse(
        {'token': 't', 'id': 2, 'role': 'seller', 'full_name': 'เจ้าของหอ'}, 200));
    await AuthService.login('seller@test.com', '1234',
        client: client, connectSocket: false);
    expect(Session.isLoggedIn, isTrue);

    AuthService.logout();
    expect(Session.isLoggedIn, isFalse);
  });
}
