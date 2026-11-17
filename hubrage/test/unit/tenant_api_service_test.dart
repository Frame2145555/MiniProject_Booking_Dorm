import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hubrage/services/session.dart';
import 'package:hubrage/services/tenant_api_service.dart';

void main() {
  tearDown(() {
    TenantApiService.client = null;
    Session.clear();
  });

  test('createDormReport sends the authenticated report details', () async {
    Session.token = 'tenant-token';
    Session.role = 'tenant';
    late http.Request request;
    TenantApiService.client = MockClient((sent) async {
      request = sent;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 5},
        }),
        201,
      );
    });

    await TenantApiService.createDormReport(
      dormId: 4,
      category: 'pricing',
      description: 'ราคาไม่ตรงกับประกาศ',
    );

    expect(request.method, 'POST');
    expect(request.url.path, '/api/tenant/dorms/4/reports');
    expect(request.headers['authorization'], 'Bearer tenant-token');
    expect(jsonDecode(request.body), {
      'category': 'pricing',
      'description': 'ราคาไม่ตรงกับประกาศ',
    });
  });

  test(
    'loads notifications and marks them read for the signed-in tenant',
    () async {
      Session.token = 'tenant-token';
      Session.role = 'tenant';
      final requests = <http.Request>[];
      TenantApiService.client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 9,
                'type': 'dorm_report_resolved',
                'title': 'รายงานของคุณได้รับการจัดการแล้ว',
                'message': 'ตรวจสอบรายงานแล้ว',
                'isRead': 0,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final notifications = await TenantApiService.getNotifications();
      await TenantApiService.markNotificationsRead();

      expect(notifications.single['id'], 9);
      expect(notifications.single['isRead'], isFalse);
      expect(requests.map((request) => request.method), ['GET', 'PATCH']);
      expect(requests.first.url.path, '/api/tenant/notifications');
      expect(requests.first.headers['authorization'], 'Bearer tenant-token');
      expect(requests.last.url.path, '/api/tenant/notifications/read');
      expect(requests.last.headers['authorization'], 'Bearer tenant-token');
    },
  );
}
