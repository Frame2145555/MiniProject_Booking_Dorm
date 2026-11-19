import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../../lib/services/owner_api_service.dart';
import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/owner_kyc_view.dart';
import '../support/fake_owner_api.dart';

void main() {
  late FakeOwnerApi api;

  setUp(() {
    api = FakeOwnerApi();
    OwnerApiService.client = MockClient(api.handle);
    Session.token = 'owner-token';
    Session.userId = 3;
    Session.role = 'seller';
    Session.fullName = 'สมชาย ใจดี มาก';
    Session.phone = '0812345678';
    Session.email = 'somchai@example.com';
  });

  tearDown(() {
    OwnerApiService.client = null;
    Session.clear();
  });

  Future<void> openKyc(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const OwnerKycView()),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  String valueOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> type(WidgetTester tester, String label, String value) =>
      tester.enterText(field(label), value);

  Future<void> fillValid(WidgetTester tester) async {
    await type(tester, 'ชื่อจริง *', 'สมชาย');
    await type(tester, 'นามสกุล *', 'ใจดี');
    await type(tester, 'เบอร์โทรศัพท์ *', '0812345678');
    await type(tester, 'อีเมล *', 'somchai@example.com');
    await type(tester, 'เลขประจำตัวประชาชน (13 หลัก)', '1234567890123');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('ส่งคำขอ KYC'));
    await tester.pump();
  }

  group('OwnerKycView (ยืนยันตัวตนเจ้าของหอพัก)', () {
    testWidgets('shows the form and both upload buttons', (tester) async {
      await openKyc(tester);

      expect(find.text('ยืนยันตัวตนเจ้าของหอพัก'), findsOneWidget);
      expect(find.text('ข้อมูลสำหรับตรวจสอบสิทธิ์'), findsOneWidget);
      expect(find.text('รูปถ่ายบัตรประชาชน *'), findsOneWidget);
      expect(find.text('รูปเซลฟี่คู่บัตรประชาชน (แนะนำ)'), findsOneWidget);
      expect(find.text('ส่งคำขอ KYC'), findsOneWidget);
    });

    testWidgets('fills in the profile the owner registered with', (
      tester,
    ) async {
      await openKyc(tester);

      expect(valueOf(tester, 'ชื่อจริง *'), 'สมชาย');
      expect(valueOf(tester, 'นามสกุล *'), 'ใจดี มาก');
      expect(valueOf(tester, 'เบอร์โทรศัพท์ *'), '0812345678');
      expect(valueOf(tester, 'อีเมล *'), 'somchai@example.com');
      expect(valueOf(tester, 'เลขประจำตัวประชาชน (13 หลัก)'), isEmpty);
    });

    testWidgets('asks for the first and last name', (tester) async {
      Session.fullName = '';
      await openKyc(tester);

      await submit(tester);

      expect(find.text('กรุณากรอกชื่อจริงและนามสกุล'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('rejects a phone number that is too short', (tester) async {
      await openKyc(tester);
      await fillValid(tester);
      await type(tester, 'เบอร์โทรศัพท์ *', '12345');

      await submit(tester);

      expect(
        find.text('เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 0 และมี 9-10 หลัก เช่น 0812345678'),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await openKyc(tester);
      await fillValid(tester);
      await type(tester, 'อีเมล *', 'ไม่ใช่อีเมล');

      await submit(tester);

      expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('rejects an ID card number that is not 13 digits', (
      tester,
    ) async {
      await openKyc(tester);
      await fillValid(tester);
      await type(tester, 'เลขประจำตัวประชาชน (13 หลัก)', '12345');

      await submit(tester);

      expect(
        find.text('เลขประจำตัวประชาชนต้องเป็นตัวเลข 13 หลัก'),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    });

    testWidgets('requires the ID card photo before sending', (tester) async {
      await openKyc(tester);
      await fillValid(tester);

      await submit(tester);

      expect(find.text('กรุณาอัปโหลดรูปถ่ายบัตรประชาชน'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('accepts a phone and ID number written with dashes', (
      tester,
    ) async {
      await openKyc(tester);
      await fillValid(tester);
      await type(tester, 'เบอร์โทรศัพท์ *', '081-234-5678');
      await type(tester, 'เลขประจำตัวประชาชน (13 หลัก)', '1-2345-67890-12-3');

      await submit(tester);

      // ผ่านการตรวจเบอร์/เลขบัตรแล้ว จึงมาติดที่ยังไม่ได้เลือกรูปบัตร (เลือกไฟล์ในเทสต์ไม่ได้)
      expect(find.text('กรุณาอัปโหลดรูปถ่ายบัตรประชาชน'), findsOneWidget);
      expect(find.text('เลขประจำตัวประชาชนต้องเป็นตัวเลข 13 หลัก'), findsNothing);
    });
  });
}
