import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../lib/services/admin_api_service.dart';
import '../../lib/services/session.dart';

void main() {
  tearDown(() {
    AdminApiService.client = null;
    Session.clear();
  });

  test('getUsers sends the admin token and parses the response', () async {
    Session.token = 'admin-token';
    Session.role = 'admin';
    late http.Request sent;
    AdminApiService.client = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 12, 'name': 'ผู้เช่าทดสอบ', 'role': 'tenant'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final users = await AdminApiService.getUsers();

    expect(sent.method, 'GET');
    expect(sent.url.path, '/api/admin/users');
    expect(sent.headers['authorization'], 'Bearer admin-token');
    expect(users, [
      {'id': 12, 'name': 'ผู้เช่าทดสอบ', 'role': 'tenant'},
    ]);
  });

  test('rejects requests when the session is not an admin', () async {
    Session.token = 'user-token';
    Session.role = 'tenant';

    await expectLater(
      AdminApiService.getUsers(),
      throwsA(isA<AdminApiException>()),
    );
  });
}
