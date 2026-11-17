import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hubrage/models/admin_console_state.dart';
import 'package:hubrage/services/admin_api_service.dart';
import 'package:hubrage/services/session.dart';
import 'package:hubrage/views/admin_dashboard_view.dart';

void main() {
  late AdminConsoleState consoleState;

  setUp(() {
    Session.clear();
    consoleState = AdminConsoleState();
  });

  tearDown(() {
    AdminApiService.client = null;
    consoleState.dispose();
    Session.clear();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AdminDashboardView(consoleState: consoleState)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the dashboard and switches between admin sections', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('ศูนย์ควบคุมหลังบ้าน (Admin)'), findsOneWidget);
    expect(find.text('บัญชีเจ้าของหอ'), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('รายงานจากผู้ใช้งาน (2)'), findsOneWidget);

    await tester.tap(find.text('คำขอลงหอ'));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีคำขอลงประกาศหอ'), findsOneWidget);
  });

  testWidgets('admin can open a KYC request and approve it', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('ตรวจ KYC'));
    await tester.pumpAndSettle();
    expect(find.text('คำขอ KYC รอตรวจ 2 รายการ'), findsOneWidget);

    await tester.tap(find.text('นายสมชาย ใจดี'));
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดคำขอ KYC'), findsOneWidget);
    expect(find.text('1-1002-34567-89-0'), findsOneWidget);

    await tester.tap(find.text('อนุมัติเอกสาร (Approve)'));
    await tester.pumpAndSettle();

    expect(find.text('คำขอ KYC รอตรวจ 1 รายการ'), findsOneWidget);
    expect(find.text('อนุมัติแล้ว'), findsOneWidget);
  });

  testWidgets('admin can resolve a report without a disposed note controller', (
    tester,
  ) async {
    Session.token = 'admin-token';
    Session.role = 'admin';
    expect(AdminApiService.isAdmin, isTrue);
    final requests = <http.Request>[];
    var reportResolved = false;
    final report = {
      'id': 17,
      'dormName': 'หอทดสอบ',
      'ownerName': 'เจ้าของหอ',
      'reporterName': 'ผู้เช่าทดสอบ',
      'reporterEmail': 'tenant@example.com',
      'category': 'safety',
      'description': 'พบปัญหาด้านความปลอดภัย',
      'status': 'pending',
    };
    AdminApiService.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PATCH') {
        reportResolved = true;
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/admin/reports') {
        return http.Response(
          jsonEncode({
            'data': reportResolved ? [] : [report],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    consoleState.reports.add(report);

    await pumpDashboard(tester);
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    consoleState
      ..serverMode = true
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(consoleState.reports, hasLength(1));
    expect(find.text('พบปัญหาด้านความปลอดภัย'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'จัดการแล้ว'));
    await tester.pumpAndSettle();

    expect(find.text('ปิดรายงาน'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ตรวจสอบและแก้ไขแล้ว');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      contains('PATCH /api/admin/reports/17'),
    );
  });
}
