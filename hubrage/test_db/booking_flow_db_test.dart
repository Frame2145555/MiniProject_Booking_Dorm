// เทสต์ระบบจอง + ชำระเงินแบบยิงเข้า server + MySQL จริง (ไม่ใช้ mock)
// ใช้ BookingService ตัวจริงของแอป -> ทดสอบทั้งโค้ดฝั่งแอป, API ใน booking_payment_routes.js และข้อมูลใน DB
//
// ก่อนรัน:
//   1. เปิด MySQL (XAMPP) และ  node server.js
//   2. มีบัญชีทดสอบตาม README ฝั่ง Server (รหัสผ่าน 1234):
//      tenant@test.com, other@test.com, seller@test.com, seller2@test.com, admin@test.com
//      (node scripts/seed_dorms.js / node scripts/seed_passwords.js)
//   3. ApiConfig.baseUrl (lib/services/api_config.dart) ชี้ไปที่ server นั้น
//
// วิธีรัน (แยกจาก flutter test ปกติ เพราะต้องเปิด server):
//   flutter test test_db/booking_flow_db_test.dart --reporter expanded
//
// ทุกครั้งที่รันจะสร้างห้องทดสอบใหม่ 2 ห้อง (เลขห้อง F..., ชั้น 9) ในหอ 1 แล้วทิ้งไว้ใน DB
// เหมือน test/integration/payment_smoke.js ฝั่ง Server (ห้อง T...) จะได้รันซ้ำได้เรื่อยๆ
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// import แบบ package: ใช้ได้ไม่ว่าไฟล์นี้จะอยู่โฟลเดอร์ไหน (test_db/ หรือ test/...)
import 'package:hubrage/models/booking_models.dart';
import 'package:hubrage/services/api_config.dart';
import 'package:hubrage/services/booking_service.dart';
import 'package:hubrage/services/session.dart';

const dormId = 1; // หอของ seller@test.com (จาก seed_dorms.js)
const testRoomPrice = 5000;

class TestUser {
  final String email;
  final String token;
  final int id;
  final String role;
  const TestUser(this.email, this.token, this.id, this.role);
}

Map<String, String> jsonHeaders([String? token]) => {
  'Content-Type': 'application/json',
  'ngrok-skip-browser-warning': 'true',
  if (token != null) 'Authorization': 'Bearer $token',
};

Future<TestUser> login(String email) async {
  final res = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/api/login'),
    headers: jsonHeaders(),
    body: jsonEncode({'email': email, 'password': '1234'}),
  );
  if (res.statusCode != 200) {
    throw StateError(
      'login $email ไม่ผ่าน (${res.statusCode}) — มีบัญชีทดสอบใน DB หรือยัง? '
      '(node scripts/seed_dorms.js / node scripts/seed_passwords.js)',
    );
  }
  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  return TestUser(email, '${body['token']}', (body['id'] as num).toInt(), '${body['role']}');
}

/// เจ้าของหอเพิ่มห้องว่างใหม่ผ่าน API (แทนการ INSERT ตรงเข้า MySQL)
Future<int> createTestRoom(TestUser owner, String roomNumber) async {
  final res = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/api/owner/dorms/$dormId/rooms'),
    headers: jsonHeaders(owner.token),
    body: jsonEncode({
      'roomNumber': roomNumber,
      'roomType': 'ห้องทดสอบ Flutter',
      'price': testRoomPrice,
      'floor': 9,
      'status': 'available',
    }),
  );
  if (res.statusCode != 201) {
    throw StateError('สร้างห้องทดสอบไม่ได้ (${res.statusCode}): ${utf8.decode(res.bodyBytes)}');
  }
  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  return ((body['data'] as Map)['id'] as num).toInt();
}

/// BookingService อ่าน token จาก Session -> สลับว่า "ตอนนี้ใคร login อยู่"
void actAs(TestUser? user) {
  Session.clear();
  if (user == null) return;
  Session.token = user.token;
  Session.userId = user.id;
  Session.role = user.role;
}

Matcher throwsBookingError() => throwsA(isA<BookingException>());

void main() {
  final service = BookingService(); // ตัวจริง ยิง HTTP ไป server
  late TestUser tenant, other, owner, owner2, admin;
  late int roomId; // ห้องสำหรับเส้นทางจองสำเร็จ
  late int spareRoomId; // ห้องสำหรับเคสยกเลิก / ไม่อนุมัติ / เจ้าของหอปฏิเสธ
  late Reservation rv; // การจองหลักที่ทดสอบต่อกันทีละขั้น

  setUpAll(() async {
    try {
      await http
          .get(Uri.parse(ApiConfig.baseUrl), headers: jsonHeaders())
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw StateError(
        'ต่อ server ที่ ${ApiConfig.baseUrl} ไม่ได้ — เปิด node server.js และ MySQL ก่อนรันเทสต์นี้ ($e)',
      );
    }
    tenant = await login('tenant@test.com');
    other = await login('other@test.com');
    owner = await login('seller@test.com');
    owner2 = await login('seller2@test.com');
    admin = await login('admin@test.com');

    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    roomId = await createTestRoom(owner, 'F$stamp');
    spareRoomId = await createTestRoom(owner, 'F${stamp}b');
  });

  tearDown(() => actAs(null));

  Future<PlanRoom> roomInPlan(int id) async {
    final plan = await service.getRoomPlan(dormId);
    final room = plan.roomById(id);
    expect(room, isNotNull, reason: 'ต้องเห็นห้อง $id ในผังของหอ $dormId');
    return room!;
  }

  group('เส้นทางจองสำเร็จ: จอง -> จ่าย -> แอดมินอนุมัติ -> เจ้าของหอยืนยัน', () {
    test('ดูผังห้องได้โดยไม่ login และห้องทดสอบยังว่าง', () async {
      actAs(null);
      final plan = await service.getRoomPlan(dormId);

      expect(plan.dormId, dormId);
      expect(plan.floors, isNotEmpty);
      expect(plan.plans.map((p) => p.plan), contains('month'));
      final room = plan.roomById(roomId)!;
      expect(room.state, RoomState.available);
      expect(room.monthlyPrice, testRoomPrice);
      expect(room.floor, 9);
    });

    test('ยังไม่ login / บัญชีเจ้าของหอ จองห้องไม่ได้', () async {
      actAs(null);
      await expectLater(
        service.reserve(roomId: roomId, plan: 'month'),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', 'กรุณาเข้าสู่ระบบก่อน')),
      );
      actAs(owner);
      await expectLater(service.reserve(roomId: roomId, plan: 'month'), throwsBookingError());
    });

    test('ระยะเวลาเช่าที่ไม่มีอยู่จริง -> server ปฏิเสธ', () async {
      actAs(tenant);
      await expectLater(service.reserve(roomId: roomId, plan: 'day'), throwsBookingError());
    });

    test('ผู้เช่าจอง -> "รอชำระเงิน" ยอดล็อกตามค่าเช่าเดือน และมีเวลานับถอยหลัง', () async {
      actAs(tenant);
      rv = await service.reserve(roomId: roomId, plan: 'month');

      expect(rv.status, ReservationStatus.awaitingPayment);
      expect(rv.amount, testRoomPrice);
      expect(rv.roomId, roomId);
      expect(rv.startsAt, isNotNull);
      expect(rv.endsAt, isNotNull);
      expect(rv.timeLeft(), greaterThan(Duration.zero));
    });

    test('ผังห้อง: ห้องกลายเป็น "ติดจอง" และบอกว่าเป็นของฉัน', () async {
      actAs(tenant);
      final room = await roomInPlan(roomId);

      expect(room.state, RoomState.reserved);
      expect(room.myReservationId, rv.id);
      expect(room.canBook, isFalse);
    });

    test('คนอื่นจองห้องที่ติดจอง / จ่ายเงินแทน ไม่ได้', () async {
      actAs(other);
      await expectLater(service.reserve(roomId: roomId, plan: 'week'), throwsBookingError());
      await expectLater(service.pay(rv.id), throwsBookingError());
    });

    test('แอดมินอนุมัติรายการที่ยังไม่จ่ายไม่ได้', () async {
      actAs(admin);
      await expectLater(service.adminReview(rv.id, approve: true), throwsBookingError());
    });

    test('ผู้เช่าจ่ายเงิน -> "รอแอดมินตรวจสอบ" ยอดที่จ่ายตรง + มีเลขอ้างอิง', () async {
      actAs(tenant);
      final paid = await service.pay(rv.id);

      expect(paid.status, ReservationStatus.paid);
      expect(paid.paidAmount, testRoomPrice);
      expect(paid.amountMatches, isTrue);
      expect(paid.paymentRef, startsWith('DM'));
      expect(paid.paidAt, isNotNull);
      expect(paid.timeLeft(), Duration.zero);
    });

    test('จ่ายซ้ำ / ยกเลิกหลังจ่ายแล้ว ไม่ได้', () async {
      actAs(tenant);
      await expectLater(service.pay(rv.id), throwsBookingError());
      await expectLater(service.cancel(rv.id), throwsBookingError());
    });

    test('ผู้เช่าเรียก API ของแอดมินไม่ได้', () async {
      actAs(tenant);
      await expectLater(service.adminPayments(), throwsBookingError());
    });

    test('แอดมินเห็นรายการในคิวรอตรวจ แล้วอนุมัติ -> "รอเจ้าของหอยืนยัน"', () async {
      actAs(admin);
      final queue = await service.adminPayments(status: 'paid');
      final inQueue = queue.where((x) => x.id == rv.id);
      expect(inQueue, hasLength(1));
      expect(inQueue.single.tenantName, isNotEmpty);

      final approved = await service.adminReview(rv.id, approve: true);
      expect(approved.status, ReservationStatus.approved);
    });

    test('เจ้าของหอคนอื่นยืนยันการจองของหอนี้ไม่ได้', () async {
      actAs(owner2);
      await expectLater(service.ownerDecide(rv.id, confirm: true), throwsBookingError());
    });

    test('เจ้าของหอเห็นรายการรอยืนยัน แล้วยืนยัน -> "จองสำเร็จ"', () async {
      actAs(owner);
      final waiting = await service.ownerReservations();
      expect(waiting.map((x) => x.id), contains(rv.id));

      final done = await service.ownerDecide(rv.id, confirm: true);
      expect(done.status, ReservationStatus.completed);
    });

    test('ผู้เช่าเห็น "จองสำเร็จ" และผังห้องเปลี่ยนเป็น "มีผู้เช่า"', () async {
      actAs(tenant);
      final mine = await service.myReservations();
      expect(mine.firstWhere((x) => x.id == rv.id).status, ReservationStatus.completed);

      actAs(null);
      expect((await roomInPlan(roomId)).state, RoomState.occupied);
    });
  });

  group('เคสที่ไม่สำเร็จ (ใช้ห้องสำรอง)', () {
    test('ยกเลิกก่อนจ่าย -> "ยกเลิกแล้ว" และห้องกลับมาว่าง (ยอดรายอาทิตย์ = เดือน ÷ 4)', () async {
      actAs(other);
      final r = await service.reserve(roomId: spareRoomId, plan: 'week');
      expect(r.amount, testRoomPrice ~/ 4);

      final cancelled = await service.cancel(r.id);
      expect(cancelled.status, ReservationStatus.cancelled);
      expect((await roomInPlan(spareRoomId)).state, RoomState.available);
    });

    test('แอดมินไม่อนุมัติพร้อมเหตุผล -> "แอดมินไม่อนุมัติ" และห้องกลับมาจองได้', () async {
      actAs(other);
      final r = await service.reserve(roomId: spareRoomId, plan: 'week');
      await service.pay(r.id);

      actAs(admin);
      final rejected = await service.adminReview(r.id, approve: false, note: 'ยอดไม่ตรง');
      expect(rejected.status, ReservationStatus.rejected);

      actAs(other);
      final again = await service.reserve(roomId: spareRoomId, plan: 'week');
      expect(again.status, ReservationStatus.awaitingPayment);
      await service.cancel(again.id); // คืนห้องให้เคสถัดไป
    });

    test('เจ้าของหอปฏิเสธหลังแอดมินอนุมัติ -> "เจ้าของหอปฏิเสธ" (ยอดรายเทอม = เดือน × 4)', () async {
      actAs(other);
      final r = await service.reserve(roomId: spareRoomId, plan: 'term');
      expect(r.amount, testRoomPrice * 4);
      await service.pay(r.id);

      actAs(admin);
      await service.adminReview(r.id, approve: true);

      actAs(owner);
      final ownerRejected = await service.ownerDecide(r.id, confirm: false, note: 'ห้องต้องซ่อม');
      expect(ownerRejected.status, ReservationStatus.ownerRejected);

      final list = await service.ownerReservations(status: 'owner_rejected');
      expect(list.map((x) => x.id), contains(r.id));
    });
  });

  group('เจ้าของหอตั้งราคาเช่า', () {
    test('เจ้าของหอดูราคาเช่าของหอตัวเองได้ครบ 4 แบบ', () async {
      actAs(owner);
      final plans = await service.ownerPlans(dormId);

      expect(plans.map((p) => p.plan).toSet(), {'week', 'month', 'term', 'year'});
    });

    test('เจ้าของหออื่นดูราคาของหอนี้ไม่ได้', () async {
      actAs(owner2);
      await expectLater(service.ownerPlans(dormId), throwsBookingError());
    });

    test('ปิดให้เช่าทุกแบบ -> server ปฏิเสธ (ราคาเดิมไม่เปลี่ยน)', () async {
      actAs(owner);
      final before = await service.ownerPlans(dormId);

      await expectLater(
        service.saveOwnerPlans(dormId, [for (final p in before) p.copyWith(active: false)]),
        throwsBookingError(),
      );
      final after = await service.ownerPlans(dormId);
      expect(after.map((p) => p.active), before.map((p) => p.active));
    });
  });
}
