import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/profile_view.dart';

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);

  void signIn({String fullName = 'Jane Doe'}) {
    Session.token = 'test-token';
    Session.userId = 13;
    Session.role = 'seller';
    Session.fullName = fullName;
    Session.email = 'jane@test.com';
    Session.phone = '0812345678';
    Session.loggedIn.value = true;
  }

  Widget testApp(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: child,
  );

  testWidgets('shows profile details without exposing the user id', (
    tester,
  ) async {
    signIn();
    await tester.pumpWidget(testApp(const ProfileView()));

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@test.com'), findsOneWidget);
    expect(find.text('0812345678'), findsOneWidget);
    expect(find.text('13'), findsNothing);
    expect(find.text('รหัสผู้ใช้'), findsNothing);
  });

  testWidgets('edits first and last name and persists the profile', (
    tester,
  ) async {
    signIn();
    late http.Request sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response(
        jsonEncode({
          'full_name': 'Jane Smith',
          'email': 'jane@test.com',
          'phone': '0812345678',
          'role': 'seller',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(testApp(ProfileView(profileClient: client)));
    await tester.tap(find.widgetWithText(FilledButton, 'แก้ไขโปรไฟล์'));
    await tester.pumpAndSettle();

    expect(find.text('ชื่อ'), findsOneWidget);
    expect(find.text('นามสกุล'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jane');
    await tester.enterText(fields.at(1), 'Smith');
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(sentRequest.method, 'PUT');
    expect(sentRequest.url.path, '/api/me');
    expect(sentRequest.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(sentRequest.body), {
      'full_name': 'Jane Smith',
      'email': 'jane@test.com',
      'phone': '0812345678',
    });
    expect(Session.fullName, 'Jane Smith');
    expect(find.text('Jane Smith'), findsOneWidget);
  });
}
