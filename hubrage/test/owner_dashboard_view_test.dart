import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hubrage/models/admin_console_state.dart';
import 'package:hubrage/services/owner_api_service.dart';
import 'package:hubrage/views/owner_dashboard_view.dart';

void main() {
  testWidgets('owner dashboard requires a dedicated owner login', (
    tester,
  ) async {
    OwnerApiService.logout();
    final consoleState = AdminConsoleState();
    addTearDown(consoleState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OwnerDashboardView(consoleState: consoleState),
      ),
    );

    expect(find.text('เข้าสู่ระบบเจ้าของหอ'), findsOneWidget);
    expect(find.text('หอรวย เธะ (รามคำแหง 24)'), findsNothing);
  });
}
