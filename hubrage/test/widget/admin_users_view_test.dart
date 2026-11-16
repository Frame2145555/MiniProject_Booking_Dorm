import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../lib/services/admin_api_service.dart';
import '../../lib/services/session.dart';
import '../../lib/views/admin_users_view.dart';

void main() {
  late List<Map<String, dynamic>> users;
  final requests = <http.Request>[];

  setUp(() {
    users = [
      {
        'id': 1,
        'name': 'ผู้เช่าทดสอบ',
        'email': 'tenant@test.com',
        'phone': '081-000-0000',
        'role': 'tenant',
        'status': 'active',
      },
      {
        'id': 2,
        'name': 'เจ้าของหอทดสอบ',
        'email': 'seller@test.com',
        'phone': '082-000-0000',
        'role': 'seller',
        'status': 'suspended',
      },
    ];
    requests.clear();
    Session.token = 'admin-token';
    Session.role = 'admin';
    AdminApiService.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PATCH') {
        final id = int.parse(request.url.path.split('/')[4]);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        users.firstWhere((user) => user['id'] == id)['status'] =
            body['suspend'] == true ? 'suspended' : 'active';
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response(
        jsonEncode({'data': users}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });

  tearDown(() {
    AdminApiService.client = null;
    Session.clear();
  });

  Future<void> pumpUsers(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdminUsersView())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows users and filters the list by role', (tester) async {
    await pumpUsers(tester);

    expect(find.text('ผู้ใช้งานทั้งหมด 2 บัญชี'), findsOneWidget);
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.text('เจ้าของหอทดสอบ'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'ผู้เช่า'));
    await tester.pumpAndSettle();

    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.text('เจ้าของหอทดสอบ'), findsNothing);
  });

  testWidgets('confirms suspension and sends the status change to the API', (
    tester,
  ) async {
    await pumpUsers(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ระงับบัญชี').last);
    await tester.pumpAndSettle();

    expect(find.text('ระงับบัญชี ผู้เช่าทดสอบ หรือไม่?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    final patch = requests.firstWhere((request) => request.method == 'PATCH');
    expect(patch.url.path, '/api/admin/users/1/status');
    expect(jsonDecode(patch.body), {'suspend': true});
    expect(users.first['status'], 'suspended');
    expect(find.text('ระงับบัญชีแล้ว'), findsOneWidget);
  });
}
