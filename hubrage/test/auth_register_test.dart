// Unit test AuthService.register โดยใช้ MockClient (ไม่ต้องเปิด server จริง)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/models/user_role.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/session.dart';

http.Response fakeResponse(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => Session.clear());

  test('สมัครสำเร็จ: ยิง /api/register พร้อมข้อมูลครบ และยังไม่ login ให้', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return fakeResponse(
          {'token': 't', 'id': 9, 'role': 'seller', 'full_name': 'สมชาย'}, 201);
    });

    final error = await AuthService.register(
      email: ' new@test.com ',
      password: '12345678',
      fullName: 'สมชาย',
      phone: '0812345678',
      role: UserRole.seller, // ส่ง enum ได้
      client: client,
    );

    expect(error, isNull);
    expect(sent.url.path, '/api/register');
    expect(jsonDecode(sent.body), {
      'email': 'new@test.com',
      'password': '12345678',
      'full_name': 'สมชาย',
      'phone': '0812345678',
      'role': 'seller',
    });
    expect(Session.isLoggedIn, isFalse);
  });

  test('ส่ง role เป็น String ก็ได้ / ไม่ส่ง = tenant', () async {
    final roles = <String>[];
    final client = MockClient((request) async {
      roles.add(jsonDecode(request.body)['role']);
      return fakeResponse({'id': 1}, 201);
    });
    await AuthService.register(
        email: 'a@test.com', password: '12345678', fullName: 'A',
        role: 'tenant', client: client);
    await AuthService.register(
        email: 'b@test.com', password: '12345678', fullName: 'B',
        client: client);
    expect(roles, ['tenant', 'tenant']);
  });

  test('อีเมลซ้ำ (409): ได้ข้อความจาก server', () async {
    final client = MockClient(
        (_) async => fakeResponse({'error': 'อีเมลนี้ถูกใช้งานแล้ว'}, 409));
    final error = await AuthService.register(
        email: 'dup@test.com', password: '12345678', fullName: 'X',
        client: client);
    expect(error, 'อีเมลนี้ถูกใช้งานแล้ว');
  });

  test('ต่อ server ไม่ได้: ได้ข้อความ error ไม่ crash', () async {
    final client =
        MockClient((_) async => throw http.ClientException('offline'));
    final error = await AuthService.register(
        email: 'a@test.com', password: '12345678', fullName: 'A',
        client: client);
    expect(error, contains('ไม่ได้'));
  });
}
