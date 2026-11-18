import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hubrage/services/session.dart';
import 'package:hubrage/services/tenant_api_service.dart';
import 'package:hubrage/theme/app_theme.dart';
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

  testWidgets('tenant can submit a dorm report', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    TenantApiService.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'success': true}), 201);
      }
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'data': {'reviews': [], 'canReview': false, 'hasReviewed': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'data': {'rooms': []},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DormDetailView(dorm: {'id': '1', 'title': 'หอทดสอบ'}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.flag_outlined));
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ราคา/ค่าใช้จ่ายไม่ตรงกับประกาศ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'ราคาไม่ตรงกับประกาศที่ระบุไว้',
    );
    await tester.ensureVisible(find.text('ส่งรายงาน'));
    await tester.tap(find.text('ส่งรายงาน'));
    await tester.pumpAndSettle();

    final submission = requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(submission.url.path, '/api/tenant/dorms/1/reports');
    expect(submission.headers['authorization'], 'Bearer tenant-token');
    expect(jsonDecode(submission.body), {
      'category': 'pricing',
      'description': 'ราคาไม่ตรงกับประกาศที่ระบุไว้',
    });
    expect(
      find.text('ส่งรายงานให้แอดมินแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an eligible tenant can submit a dorm review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    var reviewListCalls = 0;
    TenantApiService.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'success': true}), 201);
      }
      if (request.url.path.endsWith('/reviews')) {
        reviewListCalls++;
        return http.Response(
          jsonEncode({
            'data': {
              'reviews': [],
              'canReview': reviewListCalls == 1,
              'hasReviewed': reviewListCalls > 1,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'data': {'rooms': []},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DormDetailView(dorm: {'id': '1', 'title': 'หอทดสอบ'}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เขียนรีวิวจากประสบการณ์เข้าพัก'));
    final reviewForm = find.ancestor(
      of: find.text('เขียนรีวิวจากประสบการณ์เข้าพัก'),
      matching: find.byType(AppCard),
    );
    await tester.tap(
      find
          .descendant(of: reviewForm, matching: find.byIcon(Icons.star_rounded))
          .at(3),
    );
    await tester.enterText(find.byType(TextField), 'ห้องสะอาดและเดินทางสะดวก');
    await tester.ensureVisible(find.text('ส่งรีวิว'));
    await tester.tap(find.text('ส่งรีวิว'));
    await tester.pumpAndSettle();

    final submission = requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(submission.url.path, '/api/tenant/dorms/1/reviews');
    expect(jsonDecode(submission.body), {
      'rating': 4,
      'comment': 'ห้องสะอาดและเดินทางสะดวก',
    });
    expect(find.text('เขียนรีวิวจากประสบการณ์เข้าพัก'), findsNothing);
    expect(find.text('คุณรีวิวหอนี้แล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review form is hidden when tenant is not eligible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TenantApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'data': {
              'reviews': [
                {
                  'id': 8,
                  'author': 'ผู้เช่าทดสอบ',
                  'rating': 4,
                  'comment': 'ห้องสะอาดและเดินทางสะดวก',
                  'createdAt': '2026-11-18 10:00:00',
                },
              ],
              'canReview': false,
              'hasReviewed': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'data': {'rooms': []},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DormDetailView(dorm: {'id': '1', 'title': 'หอทดสอบ'}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ห้องสะอาดและเดินทางสะดวก'));

    expect(find.text('เขียนรีวิวจากประสบการณ์เข้าพัก'), findsNothing);
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
