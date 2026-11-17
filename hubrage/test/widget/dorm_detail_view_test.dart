import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hubrage/services/session.dart';
import 'package:hubrage/services/tenant_api_service.dart';
import 'package:hubrage/views/dorm_detail_view.dart';

void main() {
  setUp(() {
    Session.clear();
    Session.token = 'tenant-token';
    Session.role = 'tenant';
    TenantApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': {'rooms': []},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
  });

  tearDown(() {
    TenantApiService.client?.close();
    TenantApiService.client = null;
    Session.clear();
  });

  testWidgets('report dialog closes without disposing its field too early', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: DormDetailView(dorm: {'id': '1', 'title': 'หอทดสอบ'}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.flag_outlined));
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();

    expect(find.text('รายงานประกาศหอพัก'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('รายงานประกาศหอพัก'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
