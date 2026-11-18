import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/owner_reservations_view.dart';
import '../support/fake_booking_service.dart';

/// คำขอจองที่ผู้เช่าจ่ายเงินแล้ว + แอดมินตรวจแล้ว (รอเจ้าของหอยืนยัน)
Reservation approvedReservation({int id = bookingTestReservationId, String room = 'A08'}) =>
    bookingTestWithStatus(
      bookingTestReservation(id: id, roomNumber: room),
      ReservationStatus.approved,
    );

void main() {
  late FakeBookingService service;

  setUp(() {
    Session.token = 'owner-token';
    Session.userId = 3;
    Session.role = 'seller';
    service = FakeBookingService();
  });

  tearDown(Session.clear);

  Future<void> openReservations(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OwnerReservationsView(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OwnerReservationsView (เจ้าของหอยืนยันการจอง)', () {
    testWidgets('requires an owner account', (tester) async {
      Session.role = 'tenant';
      await openReservations(tester);

      expect(
        find.text('เข้าสู่ระบบด้วยบัญชีเจ้าของหอเพื่อดูคำขอจอง'),
        findsOneWidget,
      );
      expect(service.ownerStatusRequests, isEmpty);
      expect(find.text('ตั้งราคาเช่า'), findsNothing);
    });

    testWidgets('shows an empty state when nothing waits for confirmation', (
      tester,
    ) async {
      await openReservations(tester);

      expect(service.ownerStatusRequests, ['approved']);
      expect(find.textContaining('ไม่มีรายการ'), findsOneWidget);
    });

    testWidgets('shows tenant, plan and the deposit already paid', (
      tester,
    ) async {
      service.add(approvedReservation());
      await openReservations(tester);

      expect(find.text('หอทดสอบ • ห้อง A08'), findsOneWidget);
      expect(find.text('ผู้เช่าทดสอบ • 0812345678'), findsOneWidget);
      expect(find.text('ค่ามัดจำที่ชำระแล้ว'), findsOneWidget);
      expect(find.text('4,000 บาท'), findsWidgets);
      expect(find.text('PAY-34-TEST'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ปฏิเสธ'), findsOneWidget);
    });

    testWidgets('confirms a booking after the confirmation dialog', (
      tester,
    ) async {
      service.add(approvedReservation());
      await openReservations(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'));
      await tester.pumpAndSettle();
      expect(find.text('ยืนยันการจอง?'), findsOneWidget);
      expect(find.textContaining('ผู้เช่าทดสอบ • ห้อง A08'), findsOneWidget);

      // ปุ่มในกล่องยืนยัน (ปุ่มบนการ์ดอยู่ด้านหลัง)
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง').last);
      await tester.pumpAndSettle();

      expect(service.ownerDecisions, [
        {'id': bookingTestReservationId, 'confirm': true, 'note': null},
      ]);
      expect(find.text('จองสำเร็จ แจ้งเตือนผู้เช่าในแชทแล้ว'), findsOneWidget);
      // ไม่ใช่ "รอยืนยัน" แล้ว -> หายจากรายการ
      expect(find.text('หอทดสอบ • ห้อง A08'), findsNothing);
      expect(find.textContaining('ไม่มีรายการ'), findsOneWidget);
    });

    testWidgets('does nothing when the confirmation dialog is cancelled', (
      tester,
    ) async {
      service.add(approvedReservation());
      await openReservations(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
      await tester.pumpAndSettle();

      expect(service.ownerDecisions, isEmpty);
      expect(find.text('หอทดสอบ • ห้อง A08'), findsOneWidget);
    });

    testWidgets('rejects a booking with a reason', (tester) async {
      service.add(approvedReservation());
      await openReservations(tester);

      await tester.tap(find.widgetWithText(TextButton, 'ปฏิเสธ'));
      await tester.pumpAndSettle();
      expect(find.text('ปฏิเสธการจอง'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ห้องต้องซ่อม');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยัน'));
      await tester.pumpAndSettle();

      expect(service.ownerDecisions, [
        {'id': bookingTestReservationId, 'confirm': false, 'note': 'ห้องต้องซ่อม'},
      ]);
      expect(find.text('ปฏิเสธแล้ว แอดมินจะคืนเงินผู้เช่า'), findsOneWidget);
      expect(find.text('หอทดสอบ • ห้อง A08'), findsNothing);
    });

    testWidgets('keeps the booking and shows the error when the server refuses', (
      tester,
    ) async {
      service
        ..add(approvedReservation())
        ..decideError = 'ห้องนี้มีผู้เช่าอยู่แล้ว';
      await openReservations(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง').last);
      await tester.pumpAndSettle();

      expect(find.text('ห้องนี้มีผู้เช่าอยู่แล้ว'), findsOneWidget);
      expect(find.text('หอทดสอบ • ห้อง A08'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'), findsOneWidget);
    });

    testWidgets('filters by status and hides actions on finished bookings', (
      tester,
    ) async {
      service
        ..add(approvedReservation())
        ..add(
          bookingTestWithStatus(
            bookingTestReservation(id: 35, roomNumber: 'B01'),
            ReservationStatus.completed,
          ),
        );
      await openReservations(tester);
      expect(find.text('หอทดสอบ • ห้อง B01'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'จองสำเร็จ'));
      await tester.pumpAndSettle();

      expect(service.ownerStatusRequests, ['approved', 'completed']);
      expect(find.text('หอทดสอบ • ห้อง B01'), findsOneWidget);
      expect(find.text('หอทดสอบ • ห้อง A08'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'ยืนยันการจอง'), findsNothing);
    });

    testWidgets('shows the server error when loading fails', (tester) async {
      service.listError = 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้';
      await openReservations(tester);

      expect(find.text('บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้'), findsOneWidget);
      expect(find.textContaining('ไม่มีรายการ'), findsNothing);
    });
  });

  group('OwnerRentPlanView (ตั้งราคาเช่า)', () {
    /// เปิดหน้าตั้งราคาจากหน้าอื่น (หน้าจะปิดตัวเองหลังบันทึกสำเร็จ)
    Future<void> openPlans(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerRentPlanView(
                        dormId: 2,
                        dormName: 'หอทดสอบ',
                        service: service,
                      ),
                    ),
                  ),
                  child: const Text('เปิดหน้าตั้งราคา'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิดหน้าตั้งราคา'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows each plan with its current price', (tester) async {
      await openPlans(tester);

      expect(find.text('ราคาเช่า • หอทดสอบ'), findsOneWidget);
      for (final label in ['1 อาทิตย์', '1 เดือน', '1 เทอม', '1 ปี']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('4000'), findsOneWidget);
      expect(find.text('18000'), findsOneWidget);
    });

    testWidgets('requires a price for every plan that is turned on', (
      tester,
    ) async {
      await openPlans(tester);

      await tester.tap(find.byType(Switch).first); // เปิด "1 อาทิตย์" แต่ยังไม่ใส่ราคา
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      expect(find.text('กรุณาใส่ราคา 1 อาทิตย์'), findsOneWidget);
      expect(service.savedPlans, isEmpty);
      expect(find.byType(OwnerRentPlanView), findsOneWidget);
    });

    testWidgets('saves the new prices and closes the page', (tester) async {
      await openPlans(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('price-week')), '1200');
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      expect(service.savedPlans, hasLength(1));
      final week = service.savedPlans.single.firstWhere((p) => p.plan == 'week');
      expect(week.active, isTrue);
      expect(week.price, 1200);
      expect(find.text('บันทึกราคาเช่าแล้ว'), findsOneWidget);
      expect(find.byType(OwnerRentPlanView), findsNothing);
    });
  });
}
