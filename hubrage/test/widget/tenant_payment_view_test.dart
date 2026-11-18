import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/my_reservations_view.dart';
import '../../lib/views/payment_view.dart';
import '../../lib/widgets/reservation_widgets.dart';
import '../support/fake_booking_service.dart';

// หมายเหตุ: หน้าชำระเงินนับถอยหลังทุก 1 วินาทีตอน "รอชำระเงิน"
// pumpAndSettle จะรอไม่จบ จึงใช้ pumpFrames (เดินเวลาทีละช่วง) แทนในสถานะนั้น
Future<void> pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeBookingService service;

  setUp(() {
    Session.token = 'tenant-token';
    Session.userId = 9;
    Session.role = 'tenant';
    service = FakeBookingService();
  });

  tearDown(Session.clear);

  Future<void> openPayment(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentView(
          reservationId: bookingTestReservationId,
          service: service,
        ),
      ),
    );
    await pumpFrames(tester);
  }

  group('PaymentView (ผู้เช่าชำระเงิน)', () {
    testWidgets('shows the locked amount, mock QR and countdown', (
      tester,
    ) async {
      service.add(bookingTestReservation());
      await openPayment(tester);

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('ชำระเงิน')),
        findsOneWidget,
      ); // ชื่อหน้า (แถบขั้นตอนก็มีคำว่า "ชำระเงิน" จึงหาเฉพาะใน AppBar)
      expect(find.text('หอทดสอบ • ห้อง A08'), findsOneWidget);
      expect(find.text('PromptPay (จำลอง)'), findsOneWidget);
      expect(find.textContaining('เหลือเวลาชำระ'), findsOneWidget);
      expect(find.text('จ่ายเงิน 4,000 บาท'), findsOneWidget);
      expect(
        find.text('ยอดเงินถูกกำหนดตามราคาที่เจ้าของหอตั้ง แก้ไขไม่ได้'),
        findsOneWidget,
      );
    });

    testWidgets('pays after confirming and moves to admin review', (
      tester,
    ) async {
      service.add(bookingTestReservation());
      await openPayment(tester);

      await tester.tap(find.text('จ่ายเงิน 4,000 บาท'));
      await pumpFrames(tester);
      expect(find.text('ยืนยันการชำระเงิน'), findsOneWidget);
      expect(find.textContaining('ชำระ 4,000 บาท'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'จ่ายเงิน'));
      await pumpFrames(tester);

      expect(service.payCalls, [bookingTestReservationId]);
      expect(find.text('ชำระเงินแล้ว รอแอดมินตรวจสอบ'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('สถานะการจอง')),
        findsOneWidget,
      ); // ชื่อหน้าเปลี่ยน
      expect(find.text('PAY-34-TEST'), findsOneWidget); // เลขอ้างอิง
      expect(find.text('PromptPay (จำลอง)'), findsNothing);
    });

    testWidgets('does not pay when the confirmation is dismissed', (
      tester,
    ) async {
      service.add(bookingTestReservation());
      await openPayment(tester);

      await tester.tap(find.text('จ่ายเงิน 4,000 บาท'));
      await pumpFrames(tester);
      await tester.tap(find.text('ยกเลิก'));
      await pumpFrames(tester);

      expect(service.payCalls, isEmpty);
      expect(find.text('จ่ายเงิน 4,000 บาท'), findsOneWidget);
    });

    testWidgets('shows the server error and stays on payment when paying fails', (
      tester,
    ) async {
      service
        ..add(bookingTestReservation())
        ..payError = 'ยอดเงินไม่ตรงกับราคาที่เจ้าของหอตั้ง';
      await openPayment(tester);

      await tester.tap(find.text('จ่ายเงิน 4,000 บาท'));
      await pumpFrames(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'จ่ายเงิน'));
      await pumpFrames(tester);

      expect(service.payCalls, [bookingTestReservationId]);
      // SnackBar + ข้อความใต้กล่องชำระเงิน
      expect(
        find.text('ยอดเงินไม่ตรงกับราคาที่เจ้าของหอตั้ง'),
        findsNWidgets(2),
      );
      expect(find.text('PromptPay (จำลอง)'), findsOneWidget);
    });

    testWidgets('cancels the reservation after confirming', (tester) async {
      service.add(bookingTestReservation());
      await openPayment(tester);

      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิกการจอง'));
      await pumpFrames(tester);
      expect(find.text('ยกเลิกการจอง?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ยกเลิกการจอง'));
      await pumpFrames(tester);

      expect(service.cancelCalls, [bookingTestReservationId]);
      expect(find.text('สถานะการจอง'), findsOneWidget);
      expect(find.text('ยกเลิกการจองแล้ว'), findsWidgets);
      expect(find.text('PromptPay (จำลอง)'), findsNothing);
    });

    testWidgets('disables paying when time is up and reloads as expired', (
      tester,
    ) async {
      service.add(
        bookingTestReservation(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      await openPayment(tester);

      final payButton = find.ancestor(
        of: find.text('จ่ายเงิน 4,000 บาท'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(payButton).onPressed, isNull);

      // server เปลี่ยนเป็น "หมดเวลาชำระเงิน" -> หน้าโหลดใหม่เองเมื่อครบเวลา
      service.nextLoadStatus = ReservationStatus.expired;
      await tester.pump(const Duration(seconds: 1));
      await pumpFrames(tester);

      expect(
        find.textContaining('ไม่ได้ชำระเงินภายในเวลาที่กำหนด'),
        findsOneWidget,
      );
      expect(service.payCalls, isEmpty);
    });

    testWidgets('shows next step and payment reference after admin approval', (
      tester,
    ) async {
      service.add(
        bookingTestWithStatus(
          bookingTestReservation(),
          ReservationStatus.approved,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PaymentView(
            reservationId: bookingTestReservationId,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle(); // ไม่ใช่สถานะรอชำระ -> ไม่มีนับถอยหลัง

      expect(find.textContaining('รอเจ้าของหอยืนยัน'), findsWidgets);
      expect(find.text('PAY-34-TEST'), findsOneWidget);
      expect(find.text('4,000 บาท'), findsWidgets);
      expect(find.textContaining('จ่ายเงิน'), findsNothing);
    });
  });

  group('MyReservationsView (การจองของฉัน)', () {
    Future<void> openList(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MyReservationsView(service: service),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks to log in without loading reservations', (tester) async {
      Session.clear();
      await openList(tester);

      expect(find.text('เข้าสู่ระบบเพื่อดูการจอง'), findsOneWidget);
      expect(service.myReservationsCalls, 0);
    });

    testWidgets('shows an empty state when there is no reservation', (
      tester,
    ) async {
      await openList(tester);

      expect(find.textContaining('ยังไม่มีการจอง'), findsOneWidget);
      expect(service.myReservationsCalls, 1);
    });

    testWidgets('shows the server error', (tester) async {
      service.listError = 'กรุณาเข้าสู่ระบบก่อน';
      await openList(tester);

      expect(find.text('กรุณาเข้าสู่ระบบก่อน'), findsOneWidget);
    });

    testWidgets('lists reservations and opens payment for one', (tester) async {
      service.add(bookingTestReservation());
      await openList(tester);

      expect(find.byType(ReservationCard), findsOneWidget);
      expect(find.text('หอทดสอบ • ห้อง A08'), findsOneWidget);
      expect(find.text('รอชำระเงิน'), findsOneWidget);

      await tester.tap(find.byType(ReservationCard));
      await pumpFrames(tester, 8); // หน้าชำระเงินมีนับถอยหลัง

      expect(find.byType(PaymentView), findsOneWidget);
      expect(find.text('PromptPay (จำลอง)'), findsOneWidget);
    });
  });
}
