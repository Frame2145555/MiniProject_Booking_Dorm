import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/booking_service.dart';
import '../../lib/services/session.dart';
import '../../lib/views/admin_payments_view.dart';
import '../support/mock_booking_service.dart';

/// ผู้เช่าจ่ายค่าจองแล้ว รอแอดมินตรวจ (ยอด 5,000 บาท)
Reservation paidReservation() => bookingTestWithStatus(
  bookingTestReservation(amount: 5000),
  ReservationStatus.paid,
);

void main() {
  late BookingTestServer server; // ข้อมูลการจองฝั่ง server
  late MockBookingService service; // mocktail

  setUp(() {
    Session.token = 'admin-token';
    Session.role = 'admin';
    server = BookingTestServer()..add(paidReservation());
    service = server.service;
  });

  tearDown(Session.clear);

  Future<void> openPayments(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPaymentsView(service: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows pending payment and approves after confirmation', (
    tester,
  ) async {
    await openPayments(tester);

    verify(() => service.adminPayments(status: 'paid')).called(1);
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.textContaining('หอทดสอบ'), findsOneWidget);
    expect(find.text('อนุมัติ'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').first);
    await tester.pumpAndSettle();
    expect(find.text('อนุมัติการชำระเงิน?'), findsOneWidget);
    expect(find.textContaining('5,000'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').last);
    await tester.pumpAndSettle();

    verify(
      () => service.adminReview(
        bookingTestReservationId,
        approve: true,
        note: null,
      ),
    ).called(1);
    expect(find.text('ไม่มีรายการ'), findsOneWidget);
  });

  testWidgets('does not review when the confirmation is cancelled', (
    tester,
  ) async {
    await openPayments(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    verifyNever(
      () => service.adminReview(
        any(),
        approve: any(named: 'approve'),
        note: any(named: 'note'),
      ),
    );
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
  });

  testWidgets('keeps the payment and shows the error when review fails', (
    tester,
  ) async {
    when(
      () => service.adminReview(
        any(),
        approve: any(named: 'approve'),
        note: any(named: 'note'),
      ),
    ).thenThrow(const BookingException('รายการนี้ถูกตรวจไปแล้ว'));
    await openPayments(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').last);
    await tester.pumpAndSettle();

    expect(find.text('รายการนี้ถูกตรวจไปแล้ว'), findsOneWidget);
    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
  });

  testWidgets('requires an admin session to access payment review', (
    tester,
  ) async {
    Session.clear();
    await openPayments(tester);

    expect(find.textContaining('เข้าสู่ระบบด้วยบัญชีแอดมิน'), findsOneWidget);
    expect(find.text('ผู้เช่าทดสอบ'), findsNothing);
    verifyNever(() => service.adminPayments(status: any(named: 'status')));
  });
}
