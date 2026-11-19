// Unit test ของ Model ระบบจอง + ชำระเงิน (models/booking_models.dart)
// แปลง JSON จาก server (booking_payment_routes.js) เป็น object และ logic เล็กๆ ใน model
// วิธีรัน: flutter test test/unit/booking_models_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/booking_models.dart';

/// JSON รายการจองแบบที่ server ส่งมา (GET /api/booking/reservations/:id)
Map<String, dynamic> reservationJson({
  String status = 'awaiting_payment',
  Object? expiresAt = '2026-11-19T05:30:00.000Z',
}) => {
  'id': 34,
  'bookingId': '17', // บาง driver ส่งเลขมาเป็น string -> ต้องแปลงได้
  'status': status,
  'statusLabel': 'รอชำระเงินภายในเวลาที่กำหนด',
  'plan': 'month',
  'planLabel': '1 เดือน',
  'amount': 4000,
  'paidAmount': null,
  'amountMatches': null,
  'paymentRef': null,
  'paidAt': null,
  'expiresAt': expiresAt,
  'createdAt': '2026-11-19T05:00:00.000Z',
  'startsAt': '2026-12-01',
  'endsAt': '2026-12-31',
  'dormId': 2,
  'dormName': 'หอทดสอบ',
  'ownerName': 'เจ้าของหอทดสอบ',
  'roomId': 8,
  'roomNumber': 'A08',
  'roomType': 'ห้องแอร์',
  'floor': 2,
  'tenantId': 9,
  'tenantName': 'ผู้เช่าทดสอบ',
  'tenantPhone': '0812345678',
};

void main() {
  group('formatBaht / formatThaiDate', () {
    test('ใส่ลูกน้ำทุก 3 หลัก และปัดเศษ', () {
      expect(formatBaht(0), '0');
      expect(formatBaht(999), '999');
      expect(formatBaht(4000), '4,000');
      expect(formatBaht(1234567), '1,234,567');
      expect(formatBaht(4999.6), '5,000');
    });

    test('วันที่ yyyy-mm-dd -> วัน/เดือน/ปี และค่าเพี้ยนได้ "-"', () {
      expect(formatThaiDate('2026-12-01'), '1/12/2026');
      expect(formatThaiDate(null), '-');
      expect(formatThaiDate('ไม่ใช่วันที่'), '-');
    });
  });

  group('ReservationStatus', () {
    test('แปลงรหัสสถานะจาก server ได้ครบทุกแบบ', () {
      for (final status in ReservationStatus.values) {
        expect(ReservationStatus.parse(status.code), status);
      }
    });

    test('รหัสที่ไม่รู้จัก -> ยกเลิกแล้ว (ปลอดภัยไว้ก่อน)', () {
      expect(ReservationStatus.parse('อะไรก็ไม่รู้'), ReservationStatus.cancelled);
      expect(ReservationStatus.parse(null), ReservationStatus.cancelled);
    });

    test('isActive: ยังถือห้องไว้เฉพาะ รอชำระ / รอแอดมิน / รอเจ้าของหอ', () {
      final active = ReservationStatus.values.where((s) => s.isActive).toSet();
      expect(active, {
        ReservationStatus.awaitingPayment,
        ReservationStatus.paid,
        ReservationStatus.approved,
      });
    });

    test('step: ลำดับขั้นของการจอง และสถานะที่จบแบบไม่สำเร็จได้ -1', () {
      expect(ReservationStatus.awaitingPayment.step, 0);
      expect(ReservationStatus.paid.step, 1);
      expect(ReservationStatus.approved.step, 2);
      expect(ReservationStatus.completed.step, 3);
      for (final s in [
        ReservationStatus.rejected,
        ReservationStatus.ownerRejected,
        ReservationStatus.cancelled,
        ReservationStatus.expired,
      ]) {
        expect(s.step, -1, reason: s.code);
      }
    });
  });

  group('Reservation.fromJson', () {
    test('แปลง JSON จาก server ได้ครบ (ตัวเลขที่เป็น string ก็แปลงได้)', () {
      final r = Reservation.fromJson(reservationJson());

      expect(r.id, 34);
      expect(r.bookingId, 17);
      expect(r.status, ReservationStatus.awaitingPayment);
      expect(r.statusLabel, 'รอชำระเงินภายในเวลาที่กำหนด');
      expect(r.planLabel, '1 เดือน');
      expect(r.amount, 4000);
      expect(r.amountText, '4,000 บาท');
      expect(r.stayText, '1/12/2026 - 31/12/2026');
      expect(r.dormName, 'หอทดสอบ');
      expect(r.roomNumber, 'A08');
      expect(r.floor, 2);
      expect(r.tenantPhone, '0812345678');
      expect(r.paidAmount, isNull);
      expect(r.paymentRef, isNull);
      // เวลา UTC จาก server -> เวลาเครื่อง
      expect(r.expiresAt, DateTime.utc(2026, 11, 19, 5, 30).toLocal());
      expect(r.expiresAt!.isUtc, isFalse);
    });

    test('ข้อมูลหลังจ่ายเงิน: ยอดที่จ่าย, ยอดตรงไหม, เลขอ้างอิง', () {
      final r = Reservation.fromJson({
        ...reservationJson(status: 'paid'),
        'paidAmount': 4000,
        'amountMatches': true,
        'paymentRef': 'PAY-34-ABCD',
        'paidAt': '2026-11-19T05:10:00.000Z',
      });

      expect(r.status, ReservationStatus.paid);
      expect(r.paidAmount, 4000);
      expect(r.amountMatches, isTrue);
      expect(r.paymentRef, 'PAY-34-ABCD');
      expect(r.paidAt, isNotNull);
    });

    test('ไม่มี statusLabel -> ใช้ชื่อสถานะสั้นแทน', () {
      final r = Reservation.fromJson({
        ...reservationJson(status: 'approved'),
      }..remove('statusLabel'));

      expect(r.statusLabel, 'รอเจ้าของหอยืนยัน');
    });

    test('ข้อมูลขาด / เพี้ยน -> ไม่ crash ได้ค่าว่างแทน', () {
      final r = Reservation.fromJson({'id': 'abc', 'amountMatches': 'yes'});

      expect(r.id, 0);
      expect(r.amount, 0);
      expect(r.status, ReservationStatus.cancelled);
      expect(r.dormName, '');
      expect(r.amountMatches, isNull);
      expect(r.expiresAt, isNull);
      expect(r.stayText, '- - -');
    });
  });

  group('Reservation.timeLeft (นับถอยหลังจ่ายเงิน)', () {
    final expires = DateTime(2026, 11, 19, 12, 30);
    Reservation withStatus(String status) => Reservation.fromJson(
      reservationJson(status: status, expiresAt: expires.toIso8601String()),
    );

    test('ยังไม่หมดเวลา -> เวลาที่เหลือจริง', () {
      final left = withStatus('awaiting_payment').timeLeft(DateTime(2026, 11, 19, 12, 20));
      expect(left, const Duration(minutes: 10));
    });

    test('เลยเวลาแล้ว -> 0 (ไม่ติดลบ)', () {
      final left = withStatus('awaiting_payment').timeLeft(DateTime(2026, 11, 19, 13));
      expect(left, Duration.zero);
    });

    test('จ่ายแล้ว / ไม่มีเวลาหมด -> 0 (ไม่ต้องนับถอยหลัง)', () {
      final now = DateTime(2026, 11, 19, 12);
      expect(withStatus('paid').timeLeft(now), Duration.zero);
      expect(
        Reservation.fromJson(reservationJson(expiresAt: null)).timeLeft(now),
        Duration.zero,
      );
    });
  });

  group('RentPlan', () {
    test('fromJson: active ไม่ส่งมา = เปิดให้เช่า', () {
      final p = RentPlan.fromJson({'plan': 'month', 'label': '1 เดือน', 'price': '4000'});
      expect(p.plan, 'month');
      expect(p.price, 4000);
      expect(p.active, isTrue);

      final off = RentPlan.fromJson({'plan': 'week', 'label': '1 อาทิตย์', 'price': 0, 'active': false});
      expect(off.active, isFalse);
    });

    test('copyWith เปลี่ยนเฉพาะค่าที่ส่ง และ toJson ส่งเฉพาะที่ server ต้องใช้', () {
      const p = RentPlan(plan: 'term', label: '1 เทอม', price: 18000);
      final changed = p.copyWith(price: 17000);

      expect(changed.price, 17000);
      expect(changed.active, isTrue);
      expect(changed.label, '1 เทอม');
      expect(p.copyWith(active: false).toJson(), {'plan': 'term', 'price': 18000, 'active': false});
    });
  });

  group('DormRoomPlan.fromJson (ผังห้อง 2D)', () {
    final json = {
      'dorm': {'id': 2, 'name': 'หอทดสอบ'},
      'holdMinutes': 15,
      'plans': [
        {'plan': 'month', 'label': '1 เดือน', 'price': 4000},
      ],
      'floors': [
        {
          'floor': 1,
          'rooms': [
            {'id': 1, 'number': '101', 'type': 'พัดลม', 'monthlyPrice': 3000, 'floor': 1, 'state': 'available'},
            {'id': 2, 'number': '102', 'type': 'พัดลม', 'monthlyPrice': 3000, 'floor': 1, 'state': 'occupied'},
          ],
        },
        {
          'floor': 2,
          'rooms': [
            {'id': 3, 'number': '201', 'type': 'แอร์', 'monthlyPrice': 4000, 'floor': 2, 'state': 'reserved', 'myReservationId': 34},
            {'id': 4, 'number': '202', 'type': 'แอร์', 'monthlyPrice': 4000, 'floor': 2, 'state': 'ห้องพัง'},
          ],
        },
      ],
    };

    test('ชั้นบนสุดอยู่ก่อน และนับห้องตามสถานะได้', () {
      final plan = DormRoomPlan.fromJson(json);

      expect(plan.dormName, 'หอทดสอบ');
      expect(plan.holdMinutes, 15);
      expect(plan.floors.map((f) => f.floor), [2, 1]);
      expect(plan.allRooms, hasLength(4));
      expect(plan.count(RoomState.available), 1);
      expect(plan.count(RoomState.reserved), 1);
    });

    test('จองได้เฉพาะห้องว่าง / รู้ว่าห้องไหนเราจองไว้ / สถานะแปลกถือว่าจองไม่ได้', () {
      final plan = DormRoomPlan.fromJson(json);

      expect(plan.roomById(1)!.canBook, isTrue);
      expect(plan.roomById(2)!.canBook, isFalse);
      expect(plan.roomById(3)!.isMine, isTrue);
      expect(plan.roomById(3)!.myReservationId, 34);
      expect(plan.roomById(4)!.state, RoomState.occupied);
      expect(plan.roomById(99), isNull);
    });

    test('ไม่มี holdMinutes -> ค่าเริ่มต้น 30 นาที', () {
      expect(DormRoomPlan.fromJson({'dorm': {'id': 1}}).holdMinutes, 30);
    });
  });
}
