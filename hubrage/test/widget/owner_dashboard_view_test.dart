import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../../lib/models/admin_console_state.dart';
import '../../lib/services/owner_api_service.dart';
import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/owner_dashboard_view.dart';
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
    Session.fullName = 'สมชาย ใจดี';
  });

  tearDown(() {
    OwnerApiService.client = null;
    Session.clear();
  });

  Future<void> openDashboard(WidgetTester tester) async {
    // จอสูง ๆ เพื่อให้ ListView สร้างทุกส่วนของหน้า (ไม่งั้นส่วนล่างยังไม่ถูกสร้าง หา text ไม่เจอ)
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OwnerDashboardView(consoleState: AdminConsoleState()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ElevatedButton.icon เป็นคลาสย่อยส่วนตัว -> ต้องหาด้วย bySubtype ไม่ใช่ byType
  ElevatedButton addDormButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('เพิ่มหอพัก'),
          matching: find.bySubtype<ElevatedButton>(),
        ),
      );

  group('OwnerDashboardView (หน้าแดชบอร์ดเจ้าของหอ)', () {
    group('ก่อน login', () {
      testWidgets('shows the login form when nobody is logged in', (
        tester,
      ) async {
        Session.clear();
        await openDashboard(tester);

        expect(find.text('เข้าสู่ระบบเจ้าของหอ'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'อีเมล'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'รหัสผ่าน'), findsOneWidget);
        expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
        expect(find.text('ออกจากระบบ'), findsNothing);
        expect(api.requests, isEmpty);
      });

      testWidgets('a tenant account cannot use the owner dashboard', (
        tester,
      ) async {
        Session.role = 'tenant';
        await openDashboard(tester);

        expect(find.text('เข้าสู่ระบบเจ้าของหอ'), findsOneWidget);
        expect(find.text('ออกจากระบบ'), findsNothing);
        expect(api.requests, isEmpty);
      });
    });

    group('หลัง login เป็นเจ้าของหอ', () {
      testWidgets('loads the owner data with the owner token', (tester) async {
        api.dorms = [
          ownerDormJson(id: 1, title: 'หอทดสอบ A'),
          ownerDormJson(
            id: 2,
            title: 'หอทดสอบ B',
            approvalStatus: 'pending',
            listingStatus: 'closed',
          ),
        ];
        await openDashboard(tester);

        expect(
          api.requests.map((request) => request.url.path).toSet(),
          containsAll(<String>[
            '/api/owner/dashboard/stats',
            '/api/owner/dorms',
            '/api/owner/visit-requests',
            '/api/owner/bookings',
            '/api/booking/owner/reviews',
            '/api/owner/revenue',
          ]),
        );
        expect(
          api.requests.every(
            (request) => request.headers['authorization'] == 'Bearer owner-token',
          ),
          isTrue,
        );

        expect(find.text('สมชาย ใจดี'), findsWidgets);
        expect(find.text('ออกจากระบบ'), findsOneWidget);
        expect(find.text('รายได้'), findsWidgets);
        expect(find.text('รายการหอพักของคุณ'), findsWidgets);
        expect(find.text('2 หอพัก'), findsOneWidget);
        expect(find.text('หอทดสอบ A'), findsWidgets);
        expect(find.text('หอทดสอบ B'), findsWidgets);
        expect(find.text('กำลังแสดง'), findsWidgets);
        expect(find.text('รออนุมัติ'), findsWidgets);
        expect(find.text('คำขอจองห้อง'), findsWidgets);
        expect(find.text('คำขอนัดดูห้อง'), findsWidgets);
      });

      testWidgets('shows the revenue from confirmed bookings', (tester) async {
        api.revenue = {
          ...api.revenue,
          'yearRevenue': 12500,
          'yearCount': 3,
          'totalRevenue': 30000,
          'completedCount': 7,
          'pendingAmount': 4000,
          'pendingCount': 1,
        };
        await openDashboard(tester);

        expect(find.text('฿12,500'), findsOneWidget);
        expect(find.text('฿30,000'), findsOneWidget);
        expect(find.text('฿4,000'), findsOneWidget);
        expect(api.to('/api/owner/revenue'), hasLength(1));
      });

      testWidgets('shows zero dorms when the owner has not posted any', (
        tester,
      ) async {
        await openDashboard(tester);

        expect(find.text('0 หอพัก'), findsOneWidget);
        expect(find.text('หอทดสอบ'), findsNothing);
        expect(addDormButton(tester).onPressed, isNotNull);
      });

      testWidgets('shows the error message from the server', (tester) async {
        api.statsError = 'ระบบขัดข้อง';
        await openDashboard(tester);

        expect(find.text('ระบบขัดข้อง'), findsOneWidget);
        expect(find.text('ออกจากระบบ'), findsOneWidget);
      });

      testWidgets('goes back to the login form when the token expires (401)', (
        tester,
      ) async {
        api.unauthorized = true;
        await openDashboard(tester);

        expect(find.text('เข้าสู่ระบบเจ้าของหอ'), findsOneWidget);
        expect(Session.isLoggedIn, isFalse);
      });

      testWidgets('the refresh button reloads the dashboard stats', (
        tester,
      ) async {
        await openDashboard(tester);
        expect(api.to('/api/owner/dashboard/stats'), hasLength(1));

        await tester.tap(find.byTooltip('โหลดข้อมูลใหม่'));
        await tester.pumpAndSettle();

        expect(api.to('/api/owner/dashboard/stats'), hasLength(2));
        expect(api.to('/api/owner/dorms'), hasLength(2));
      });

      testWidgets('logout clears the session and shows the login form', (
        tester,
      ) async {
        await openDashboard(tester);

        await tester.tap(find.text('ออกจากระบบ'));
        await tester.pumpAndSettle();

        expect(find.text('เข้าสู่ระบบเจ้าของหอ'), findsOneWidget);
        expect(find.text('ออกจากระบบ'), findsNothing);
        expect(Session.isLoggedIn, isFalse);
        expect(Session.role, isEmpty);
      });
    });

    group('บัญชีถูกระงับ', () {
      testWidgets('shows the banner and disables adding dorms', (
        tester,
      ) async {
        api.stats = {'account_status': 'suspended', 'verified_owner': false};
        await openDashboard(tester);

        expect(find.text('บัญชีผู้ขายถูกระงับ'), findsOneWidget);
        expect(addDormButton(tester).onPressed, isNull);
      });
    });

    group('ฟอร์มลงประกาศหอพัก', () {
      testWidgets('opens with a device picker for the cover image', (
        tester,
      ) async {
        await openDashboard(tester);

        await tester.tap(find.text('เพิ่มหอพัก'));
        await tester.pumpAndSettle();

        expect(find.text('ลงประกาศหอพัก'), findsOneWidget);
        // รูปหน้าปกเลือกจากเครื่อง ไม่ใช่ช่องวางลิงก์แล้ว
        expect(find.text('รูปหน้าปก'), findsWidgets);
        expect(find.text('เลือกรูปจากเครื่อง'), findsWidgets);
        expect(find.text('ลิงก์รูปหน้าปก (ถ้ามี)'), findsNothing);
      });

      testWidgets('closes when cancelled', (tester) async {
        await openDashboard(tester);
        await tester.tap(find.text('เพิ่มหอพัก'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();

        expect(find.text('ลงประกาศหอพัก'), findsNothing);
      });
    });

    group('ยืนยันตัวตน (KYC)', () {
      testWidgets('the shield button opens the KYC form', (tester) async {
        await openDashboard(tester);

        await tester.tap(find.byTooltip('ยืนยันตัวตนเจ้าของหอพัก'));
        await tester.pumpAndSettle();

        expect(find.byType(OwnerKycView), findsOneWidget);
        expect(find.text('ส่งคำขอ KYC'), findsOneWidget);
      });

      testWidgets('the shield stays dark until the owner is verified', (
        tester,
      ) async {
        await openDashboard(tester);

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.verified_user_outlined),
        );
        expect(icon.color, AppColors.ink);
      });

      testWidgets('the shield turns green once the owner is verified', (
        tester,
      ) async {
        api.stats = {'account_status': 'active', 'verified_owner': true};
        await openDashboard(tester);

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.verified_user_outlined),
        );
        expect(icon.color, AppColors.success);
      });
    });
  });
}
