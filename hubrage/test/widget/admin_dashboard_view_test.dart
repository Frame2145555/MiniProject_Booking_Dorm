import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/admin_console_state.dart';
import '../../lib/services/session.dart';
import '../../lib/views/admin_dashboard_view.dart';

void main() {
  late AdminConsoleState consoleState;

  setUp(() {
    Session.clear();
    consoleState = AdminConsoleState();
  });

  tearDown(() {
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
}
