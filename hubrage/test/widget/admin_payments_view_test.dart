import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/booking_service.dart';
import '../../lib/services/session.dart';
import '../../lib/views/admin_payments_view.dart';

class FakeBookingService extends BookingService {
  final List<Reservation> payments = [_reservation()];
  final List<Map<String, Object?>> reviews = [];

  @override
  Future<List<Reservation>> adminPayments({String status = 'paid'}) async =>
      payments
          .where((payment) => status == 'all' || payment.status.code == status)
          .toList();

  @override
  Future<Reservation> adminReview(
    int reservationId, {
    required bool approve,
    String? note,
  }) async {
    reviews.add({'id': reservationId, 'approve': approve, 'note': note});
    final updated = _reservation(
      status: approve ? ReservationStatus.approved : ReservationStatus.rejected,
    );
    final index = payments.indexWhere((payment) => payment.id == reservationId);
    if (index >= 0) payments[index] = updated;
    return updated;
  }
}

Reservation _reservation({ReservationStatus status = ReservationStatus.paid}) =>
    Reservation(
      id: 34,
      bookingId: 17,
      status: status,
      statusLabel: status.shortLabel,
      plan: 'month',
      planLabel: '1 เดือน',
      amount: 5000,
      paidAmount: 5000,
      amountMatches: true,
      dormId: 2,
      dormName: 'หอทดสอบ',
      ownerName: 'เจ้าของหอทดสอบ',
      roomId: 8,
      roomNumber: 'A08',
      roomType: 'ห้องแอร์',
      floor: 2,
      tenantId: 9,
      tenantName: 'ผู้เช่าทดสอบ',
    );

void main() {
  late FakeBookingService service;

  setUp(() {
    Session.token = 'admin-token';
    Session.role = 'admin';
    service = FakeBookingService();
  });

  tearDown(Session.clear);

  testWidgets('shows pending payment and approves after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPaymentsView(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ผู้เช่าทดสอบ'), findsOneWidget);
    expect(find.textContaining('หอทดสอบ'), findsOneWidget);
    expect(find.text('อนุมัติ'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').first);
    await tester.pumpAndSettle();
    expect(find.text('อนุมัติการชำระเงิน?'), findsOneWidget);
    expect(find.textContaining('5,000'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'อนุมัติ').last);
    await tester.pumpAndSettle();

    expect(service.reviews, [
      {'id': 34, 'approve': true, 'note': null},
    ]);
    expect(find.text('ไม่มีรายการ'), findsOneWidget);
  });

  testWidgets('requires an admin session to access payment review', (
    tester,
  ) async {
    Session.clear();
    await tester.pumpWidget(
      MaterialApp(home: AdminPaymentsView(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('เข้าสู่ระบบด้วยบัญชีแอดมิน'), findsOneWidget);
    expect(find.text('ผู้เช่าทดสอบ'), findsNothing);
  });
}
