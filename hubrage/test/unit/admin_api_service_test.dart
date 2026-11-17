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

  test(
    'loads persisted dorm reports and reviews one with an admin note',
    () async {
      Session.token = 'admin-token';
      Session.role = 'admin';
      final requests = <http.Request>[];
      AdminApiService.client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 8, 'dormName': 'หอทดสอบ', 'status': 'pending'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final reports = await AdminApiService.getReports();
      await AdminApiService.reviewReport(
        8,
        status: 'resolved',
        note: 'ตรวจสอบแล้ว',
      );

      expect(reports.single['dormName'], 'หอทดสอบ');
      expect(requests[0].url.path, '/api/admin/reports');
      expect(requests[0].url.queryParameters['status'], 'all');
      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/api/admin/reports/8');
      expect(jsonDecode(requests[1].body), {
        'status': 'resolved',
        'note': 'ตรวจสอบแล้ว',
      });
    },
  );
}
