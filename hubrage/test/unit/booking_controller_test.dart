// Unit test ของ Controller ระบบจอง + ชำระเงิน (Logic/Frame_Booking.dart)
// ใช้ MockBookingService (mocktail) แทน server -> ไม่ต้องเปิด node / MySQL
// วิธีรัน: flutter test test/unit/booking_controller_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../lib/Logic/Frame_Booking.dart';
import '../../lib/models/booking_models.dart';
import '../../lib/services/booking_service.dart';
import '../../lib/services/session.dart';
import '../support/mock_booking_service.dart';

const id = bookingTestReservationId;

/// รอให้งาน async ที่ไม่ได้ await (เช่น โหลดผังใหม่หลังจอง) ทำเสร็จก่อน
Future<void> flush() => Future<void>.delayed(Duration.zero);

/// ผังห้อง: ชั้น 1 = 101 ว่าง, 102 มีผู้เช่า / เปิดเช่า 1 เดือน + 1 เทอม
DormRoomPlan roomPlan({String room101 = 'available'}) => DormRoomPlan.fromJson({
  'dorm': {'id': 2, 'name': 'หอทดสอบ'},
  'plans': [
    {'plan': 'term', 'label': '1 เทอม', 'price': 18000},
    {'plan': 'month', 'label': '1 เดือน', 'price': 4000},
  ],
  'floors': [
    {
      'floor': 1,
      'rooms': [
        {'id': 1, 'number': '101', 'type': 'แอร์', 'monthlyPrice': 4000, 'floor': 1, 'state': room101},
        {'id': 2, 'number': '102', 'type': 'แอร์', 'monthlyPrice': 4000, 'floor': 1, 'state': 'occupied'},
      ],
    },
  ],
});

void main() {
  late MockBookingService service;

  setUpAll(() {
    // ค่าสำรองให้ any() ของ mocktail กับชนิดที่ไม่ใช่ตัวเลข/ข้อความ
    registerFallbackValue(<RentPlan>[]);
    registerFallbackValue(DateTime(2000));
  });

  setUp(() {
    Session.clear();
    service = MockBookingService();
  });

  tearDown(Session.clear);

  void loginAs(String role) {
    Session.token = '$role-token';
    Session.userId = 9;
    Session.role = role;
  }

  // ───────────────────────── จองห้อง ─────────────────────────

  group('RoomPlanController (ผังห้อง + กดจอง)', () {
    setUp(() {
      when(() => service.getRoomPlan(2)).thenAnswer((_) async => roomPlan());
    });

    test('โหลดผัง: เลือก "1 เดือน" เป็นค่าเริ่มต้น และยังไม่เลือกห้อง', () async {
      final c = RoomPlanController(2, service: service);
      await c.load();

      verify(() => service.getRoomPlan(2)).called(1);
      expect(c.loading, isFalse);
      expect(c.plan!.dormName, 'หอทดสอบ');
      expect(c.selectedPlan, 'month');
      expect(c.selectedRoom, isNull);
      expect(c.canReserve, isFalse);
    });

    test('ห้องที่เลือกมาจากหน้ารายละเอียดหอ: เลือกให้เลยถ้ายังว่าง', () async {
      final c = RoomPlanController(2, service: service, initialRoomId: 1);
      await c.load();
      expect(c.selectedRoom!.number, '101');

      final occupied = RoomPlanController(2, service: service, initialRoomId: 2);
      await occupied.load();
      expect(occupied.selectedRoom, isNull, reason: 'ห้องมีผู้เช่าแล้ว เลือกไม่ได้');
    });

    test('เลือกห้องว่างได้ กดซ้ำ = ยกเลิกการเลือก / ห้องไม่ว่างกดไม่ได้', () async {
      final c = RoomPlanController(2, service: service);
      await c.load();

      c.selectRoom(c.plan!.roomById(2)!);
      expect(c.selectedRoom, isNull);

      c.selectRoom(c.plan!.roomById(1)!);
      expect(c.selectedRoom!.id, 1);
      expect(c.canReserve, isTrue);

      c.selectRoom(c.plan!.roomById(1)!);
      expect(c.selectedRoom, isNull);
    });

    test('โหลดไม่สำเร็จ -> เก็บข้อความ error', () async {
      when(
        () => service.getRoomPlan(2),
      ).thenThrow(const BookingException('ไม่พบหอพักนี้'));
      final c = RoomPlanController(2, service: service);
      await c.load();

      expect(c.error, 'ไม่พบหอพักนี้');
      expect(c.loading, isFalse);
    });

    test('ยังไม่ login / ไม่ใช่บัญชีผู้เช่า -> จองไม่ได้ และไม่เรียก server', () async {
      final c = RoomPlanController(2, service: service, initialRoomId: 1);
      await c.load();

      expect(await c.reserve(), isNull);
      expect(c.actionError, 'กรุณาเข้าสู่ระบบก่อนจองห้อง');

      loginAs('seller');
      expect(await c.reserve(), isNull);
      expect(c.actionError, 'ต้องเข้าสู่ระบบด้วยบัญชีผู้เช่าจึงจะจองห้องได้');

      verifyNever(
        () => service.reserve(
          roomId: any(named: 'roomId'),
          plan: any(named: 'plan'),
          startsAt: any(named: 'startsAt'),
        ),
      );
    });

    test('จองสำเร็จ -> ส่งห้อง + แบบเช่าที่เลือก แล้วโหลดผังใหม่', () async {
      loginAs('tenant');
      when(
        () => service.reserve(
          roomId: any(named: 'roomId'),
          plan: any(named: 'plan'),
          startsAt: any(named: 'startsAt'),
        ),
      ).thenAnswer((_) async => bookingTestReservation());
      final c = RoomPlanController(2, service: service, initialRoomId: 1);
      await c.load();
      c.selectPlan('term');
      final startsAt = DateTime(2026, 12, 1);
      // หลังจอง server จะเปลี่ยนห้อง 101 เป็น "ติดจอง"
      when(
        () => service.getRoomPlan(2),
      ).thenAnswer((_) async => roomPlan(room101: 'reserved'));

      final r = await c.reserve(startsAt: startsAt);
      await flush();

      expect(r!.status, ReservationStatus.awaitingPayment);
      verify(
        () => service.reserve(roomId: 1, plan: 'term', startsAt: startsAt),
      ).called(1);
      expect(c.selectedRoomId, isNull);
      expect(c.reserving, isFalse);
      verify(() => service.getRoomPlan(2)).called(2); // ครั้งแรก + โหลดใหม่หลังจอง
      expect(c.plan!.roomById(1)!.state, RoomState.reserved);
    });

    test('server ปฏิเสธ (ห้องถูกจองตัดหน้า) -> ได้ null + ข้อความ error', () async {
      loginAs('tenant');
      when(
        () => service.reserve(
          roomId: any(named: 'roomId'),
          plan: any(named: 'plan'),
          startsAt: any(named: 'startsAt'),
        ),
      ).thenThrow(const BookingException('ห้องนี้ถูกจองไปแล้ว'));
      final c = RoomPlanController(2, service: service, initialRoomId: 1);
      await c.load();

      expect(await c.reserve(), isNull);
      await flush();

      expect(c.actionError, 'ห้องนี้ถูกจองไปแล้ว');
      expect(c.reserving, isFalse);
    });

    test('โหลดผังใหม่แล้วห้องที่เลือกไม่ว่างแล้ว -> ยกเลิกการเลือกเอง', () async {
      final c = RoomPlanController(2, service: service, initialRoomId: 1);
      await c.load();
      expect(c.selectedRoomId, 1);

      when(
        () => service.getRoomPlan(2),
      ).thenAnswer((_) async => roomPlan(room101: 'reserved'));
      await c.load();

      expect(c.selectedRoomId, isNull);
    });
  });

  // ───────────────────────── ชำระเงิน ─────────────────────────

  group('PaymentController (จ่ายเงิน / ยกเลิก)', () {
    test('canPay: จ่ายได้เฉพาะ "รอชำระเงิน" ที่ยังไม่หมดเวลา', () {
      expect(PaymentController(id, initial: bookingTestReservation(), service: service).canPay, isTrue);
      expect(
        PaymentController(
          id,
          initial: bookingTestReservation(
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
          service: service,
        ).canPay,
        isFalse,
        reason: 'หมดเวลาแล้ว',
      );
      expect(
        PaymentController(
          id,
          initial: bookingTestWithStatus(bookingTestReservation(), ReservationStatus.paid),
          service: service,
        ).canPay,
        isFalse,
        reason: 'จ่ายไปแล้ว',
      );
      expect(PaymentController(id, service: service).canPay, isFalse, reason: 'ยังไม่ได้โหลด');
    });

    test('โหลดรายการจาก server', () async {
      when(() => service.getReservation(id)).thenAnswer((_) async => bookingTestReservation());
      final c = PaymentController(id, service: service);

      await c.load();

      verify(() => service.getReservation(id)).called(1);
      expect(c.reservation!.roomNumber, 'A08');
      expect(c.loading, isFalse);
      expect(c.error, isNull);
    });

    test('จ่ายสำเร็จ -> สถานะเป็น "รอแอดมินตรวจสอบ"', () async {
      when(() => service.pay(id)).thenAnswer(
        (_) async => bookingTestWithStatus(bookingTestReservation(), ReservationStatus.paid),
      );
      final c = PaymentController(id, initial: bookingTestReservation(), service: service);
      final paying = <bool>[];
      c.addListener(() => paying.add(c.paying));

      expect(await c.pay(), isTrue);

      verify(() => service.pay(id)).called(1);
      expect(c.reservation!.status, ReservationStatus.paid);
      expect(c.reservation!.paymentRef, 'PAY-34-TEST');
      expect(paying, [true, false], reason: 'ปุ่มหมุนระหว่างจ่าย แล้วกลับมาปกติ');
    });

    test('จ่ายไม่ผ่าน -> โหลดสถานะล่าสุดจาก server และเก็บสาเหตุไว้', () async {
      when(() => service.pay(id)).thenThrow(const BookingException('หมดเวลาชำระเงินแล้ว'));
      when(() => service.getReservation(id)).thenAnswer(
        (_) async => bookingTestWithStatus(bookingTestReservation(), ReservationStatus.expired),
      );
      final c = PaymentController(id, initial: bookingTestReservation(), service: service);

      expect(await c.pay(), isFalse);

      verify(() => service.getReservation(id)).called(1);
      expect(c.reservation!.status, ReservationStatus.expired);
      expect(c.error, 'หมดเวลาชำระเงินแล้ว', reason: 'error ต้องไม่ถูก load() ล้างทิ้ง');
      expect(c.paying, isFalse);
    });

    test('จ่ายไม่ได้ (หมดเวลา / จ่ายแล้ว) -> ไม่เรียก server เลย', () async {
      final expired = PaymentController(
        id,
        initial: bookingTestReservation(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        service: service,
      );

      expect(await expired.pay(), isFalse);
      verifyNever(() => service.pay(any()));
    });

    test('ยกเลิกการจอง -> สถานะ "ยกเลิกแล้ว" / ยกเลิกหลังจ่ายเงินแล้วไม่ได้', () async {
      when(() => service.cancel(id)).thenAnswer(
        (_) async => bookingTestWithStatus(bookingTestReservation(), ReservationStatus.cancelled),
      );
      final c = PaymentController(id, initial: bookingTestReservation(), service: service);

      expect(await c.cancel(), isTrue);
      expect(c.reservation!.status, ReservationStatus.cancelled);
      verify(() => service.cancel(id)).called(1);

      final paid = PaymentController(
        id,
        initial: bookingTestWithStatus(bookingTestReservation(), ReservationStatus.paid),
        service: service,
      );
      expect(paid.canCancel, isFalse);
      expect(await paid.cancel(), isFalse);
      verifyNever(() => service.cancel(any()));
    });

    test('ยกเลิกไม่ผ่าน -> เก็บข้อความ error', () async {
      when(() => service.cancel(id)).thenThrow(const BookingException('ยกเลิกไม่ได้แล้ว'));
      final c = PaymentController(id, initial: bookingTestReservation(), service: service);

      expect(await c.cancel(), isFalse);
      expect(c.error, 'ยกเลิกไม่ได้แล้ว');
      expect(c.reservation!.status, ReservationStatus.awaitingPayment);
    });
  });

  // ───────────────────────── รายการการจอง ─────────────────────────

  group('ReservationListController (ผู้เช่า / แอดมิน / เจ้าของหอ)', () {
    Reservation r(int rid, ReservationStatus status) =>
        bookingTestWithStatus(bookingTestReservation(id: rid), status);

    test('ตัวกรองเริ่มต้นตามบทบาท', () {
      expect(ReservationListController(ReservationViewer.tenant, service: service).status, 'all');
      expect(ReservationListController(ReservationViewer.admin, service: service).status, 'paid');
      expect(ReservationListController(ReservationViewer.owner, service: service).status, 'approved');
    });

    test('แต่ละบทบาทเรียก API ของตัวเอง', () async {
      when(() => service.myReservations()).thenAnswer((_) async => [r(1, ReservationStatus.paid)]);
      when(
        () => service.adminPayments(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(2, ReservationStatus.paid)]);
      when(
        () => service.ownerReservations(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(3, ReservationStatus.approved)]);

      final tenant = ReservationListController(ReservationViewer.tenant, service: service);
      final admin = ReservationListController(ReservationViewer.admin, service: service);
      final owner = ReservationListController(ReservationViewer.owner, service: service);
      await tenant.load();
      await admin.load();
      await owner.load();

      expect(tenant.items.single.id, 1);
      expect(admin.items.single.id, 2);
      expect(owner.items.single.id, 3);
      verify(() => service.myReservations()).called(1);
      verify(() => service.adminPayments(status: 'paid')).called(1);
      verify(() => service.ownerReservations(status: 'approved')).called(1);
    });

    test('เปลี่ยนตัวกรอง -> โหลดใหม่ / เลือกตัวกรองเดิม -> ไม่โหลดซ้ำ', () async {
      when(
        () => service.ownerReservations(status: any(named: 'status')),
      ).thenAnswer((_) async => []);
      final c = ReservationListController(ReservationViewer.owner, service: service);
      await c.load();

      await c.setStatus('approved');
      await c.setStatus('completed');

      verify(() => service.ownerReservations(status: 'approved')).called(1);
      verify(() => service.ownerReservations(status: 'completed')).called(1);
      expect(c.status, 'completed');
    });

    test('โหลดไม่สำเร็จ -> เก็บข้อความ error', () async {
      when(() => service.myReservations()).thenThrow(const BookingException('กรุณาเข้าสู่ระบบก่อน'));
      final c = ReservationListController(ReservationViewer.tenant, service: service);

      await c.load();

      expect(c.error, 'กรุณาเข้าสู่ระบบก่อน');
      expect(c.loading, isFalse);
    });

    test('แอดมินอนุมัติ -> ส่ง approve + เหตุผล และเอาออกจากรายการ "รอตรวจ"', () async {
      when(
        () => service.adminPayments(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(id, ReservationStatus.paid)]);
      when(
        () => service.adminReview(id, approve: true, note: null),
      ).thenAnswer((_) async => r(id, ReservationStatus.approved));
      final c = ReservationListController(ReservationViewer.admin, service: service);
      await c.load();

      expect(await c.adminReview(c.items.single, approve: true), isNull);

      verify(() => service.adminReview(id, approve: true, note: null)).called(1);
      expect(c.items, isEmpty);
      expect(c.busy, isEmpty);
    });

    test('แอดมินไม่อนุมัติพร้อมเหตุผล', () async {
      when(
        () => service.adminPayments(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(id, ReservationStatus.paid)]);
      when(
        () => service.adminReview(any(), approve: any(named: 'approve'), note: any(named: 'note')),
      ).thenAnswer((_) async => r(id, ReservationStatus.rejected));
      final c = ReservationListController(ReservationViewer.admin, service: service);
      await c.load();

      await c.adminReview(c.items.single, approve: false, note: 'ยอดเงินไม่ตรง');

      verify(() => service.adminReview(id, approve: false, note: 'ยอดเงินไม่ตรง')).called(1);
    });

    test('ตัวกรอง "ทั้งหมด" -> อัปเดตรายการในที่เดิมแทนการเอาออก', () async {
      when(
        () => service.ownerReservations(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(id, ReservationStatus.approved)]);
      when(
        () => service.ownerDecide(id, confirm: true, note: null),
      ).thenAnswer((_) async => r(id, ReservationStatus.completed));
      final c = ReservationListController(ReservationViewer.owner, service: service, status: 'all');
      await c.load();

      expect(await c.ownerDecide(c.items.single, confirm: true), isNull);

      expect(c.items.single.status, ReservationStatus.completed);
    });

    test('server ปฏิเสธ -> คืนข้อความ error และรายการยังอยู่', () async {
      when(
        () => service.ownerReservations(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(id, ReservationStatus.approved)]);
      when(
        () => service.ownerDecide(any(), confirm: any(named: 'confirm'), note: any(named: 'note')),
      ).thenThrow(const BookingException('ห้องนี้มีผู้เช่าอยู่แล้ว'));
      final c = ReservationListController(ReservationViewer.owner, service: service);
      await c.load();

      final error = await c.ownerDecide(c.items.single, confirm: true);

      expect(error, 'ห้องนี้มีผู้เช่าอยู่แล้ว');
      expect(c.items.single.status, ReservationStatus.approved);
      expect(c.busy, isEmpty);
    });

    test('กดซ้ำระหว่างรอ server -> ส่งไปครั้งเดียว', () async {
      when(
        () => service.ownerReservations(status: any(named: 'status')),
      ).thenAnswer((_) async => [r(id, ReservationStatus.approved)]);
      when(
        () => service.ownerDecide(any(), confirm: any(named: 'confirm'), note: any(named: 'note')),
      ).thenAnswer((_) async => r(id, ReservationStatus.completed));
      final c = ReservationListController(ReservationViewer.owner, service: service);
      await c.load();
      final item = c.items.single;

      final first = c.ownerDecide(item, confirm: true);
      expect(c.busy, {id});
      final second = await c.ownerDecide(item, confirm: true); // ยังรออันแรกอยู่
      await first;

      expect(second, isNull);
      verify(
        () => service.ownerDecide(any(), confirm: any(named: 'confirm'), note: any(named: 'note')),
      ).called(1);
    });
  });

  // ───────────────────────── ตั้งราคาเช่า ─────────────────────────

  group('OwnerRentPlanController (เจ้าของหอตั้งราคาเช่า)', () {
    setUp(() {
      when(() => service.ownerPlans(2)).thenAnswer((_) async => List.of(bookingTestPlans));
      when(() => service.saveOwnerPlans(any(), any())).thenAnswer((_) async {});
    });

    test('โหลดราคาเช่าของหอ', () async {
      final c = OwnerRentPlanController(2, service: service);
      await c.load();

      verify(() => service.ownerPlans(2)).called(1);
      expect(c.plans.map((p) => p.plan), ['week', 'month', 'term', 'year']);
      expect(c.loading, isFalse);
    });

    test('update เปลี่ยนเฉพาะแบบที่เลือก', () async {
      final c = OwnerRentPlanController(2, service: service);
      await c.load();

      c.update('week', active: true, price: 1200);

      final week = c.plans.firstWhere((p) => p.plan == 'week');
      expect(week.active, isTrue);
      expect(week.price, 1200);
      expect(c.plans.firstWhere((p) => p.plan == 'month').price, 4000);
    });

    test('validate: ต้องเปิดอย่างน้อย 1 แบบ และแบบที่เปิดต้องมีราคา', () async {
      final c = OwnerRentPlanController(2, service: service);
      await c.load();
      expect(c.validate(), isNull);

      c.update('week', active: true);
      expect(c.validate(), 'กรุณาใส่ราคา 1 อาทิตย์');

      for (final p in c.plans) {
        c.update(p.plan, active: false);
      }
      expect(c.validate(), 'ต้องเปิดให้เช่าอย่างน้อย 1 แบบ');
    });

    test('ข้อมูลไม่ถูกต้อง -> ไม่ส่งไป server', () async {
      final c = OwnerRentPlanController(2, service: service);
      await c.load();
      c.update('year', active: true, price: 0);

      expect(await c.save(), 'กรุณาใส่ราคา 1 ปี');
      verifyNever(() => service.saveOwnerPlans(any(), any()));
    });

    test('บันทึก -> ส่งราคาทุกแบบไปที่หอนี้', () async {
      final c = OwnerRentPlanController(2, service: service);
      await c.load();
      c.update('week', active: true, price: 1200);

      expect(await c.save(), isNull);

      final sent =
          verify(() => service.saveOwnerPlans(2, captureAny())).captured.single as List<RentPlan>;
      expect(sent, hasLength(4));
      expect(sent.firstWhere((p) => p.plan == 'week').price, 1200);
      expect(c.saving, isFalse);
    });

    test('บันทึกไม่ผ่าน -> คืนข้อความ error จาก server', () async {
      when(
        () => service.saveOwnerPlans(any(), any()),
      ).thenThrow(const BookingException('ไม่ใช่หอของคุณ'));
      final c = OwnerRentPlanController(2, service: service);
      await c.load();

      expect(await c.save(), 'ไม่ใช่หอของคุณ');
      expect(c.saving, isFalse);
    });
  });
}
