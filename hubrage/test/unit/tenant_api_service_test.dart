import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../lib/services/session.dart';
import '../../lib/services/tenant_api_service.dart';

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
}
