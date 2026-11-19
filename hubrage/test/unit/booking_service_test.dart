// Unit test ของ BookingService (services/booking_service.dart)
// ใช้ http.Client ปลอมด้วย mocktail -> ตรวจว่ายิง path / method / header / body ถูก
// และแปลงคำตอบ + ข้อความ error จาก server ถูก โดยไม่ต้องเปิด server จริง
// วิธีรัน: flutter test test/unit/booking_service_test.dart --reporter expanded
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/api_config.dart';
import '../../lib/services/booking_service.dart';
import '../../lib/services/session.dart';

class MockHttpClient extends Mock implements http.Client {}

/// คำตอบ JSON (เข้ารหัส UTF-8 เหมือน server จริง ภาษาไทยจะได้ไม่เพี้ยน)
http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, dynamic> reservationJson({int id = 34, String status = 'awaiting_payment'}) => {
  'id': id,
  'bookingId': 17,
  'status': status,
  'plan': 'month',
  'planLabel': '1 เดือน',
  'amount': 4000,
  'dormId': 2,
  'dormName': 'หอทดสอบ',
  'roomId': 8,
  'roomNumber': 'A08',
  'tenantName': 'ผู้เช่าทดสอบ',
};

Uri api(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

void main() {
  late MockHttpClient client;
  late BookingService service;

  setUpAll(() => registerFallbackValue(Uri.parse('https://example.test')));

  setUp(() {
    Session.clear();
    Session.token = 'tenant-token';
    Session.userId = 9;
    Session.role = 'tenant';
    client = MockHttpClient();
    service = BookingService(client: client);
  });

  tearDown(Session.clear);

  // ---------- stub ของแต่ละ method ----------
  void stubGet(http.Response response) => when(
    () => client.get(any(), headers: any(named: 'headers')),
  ).thenAnswer((_) async => response);

  void stubPost(http.Response response) => when(
    () => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')),
  ).thenAnswer((_) async => response);

  void stubPatch(http.Response response) => when(
    () => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')),
  ).thenAnswer((_) async => response);

  void stubPut(http.Response response) => when(
    () => client.put(any(), headers: any(named: 'headers'), body: any(named: 'body')),
  ).thenAnswer((_) async => response);

  // ---------- ดึงค่าที่ส่งไป server ออกมาตรวจ ----------
  ({Uri url, Map<String, String> headers}) capturedGet() {
    final c = verify(
      () => client.get(captureAny(), headers: captureAny(named: 'headers')),
    ).captured;
    return (url: c[0] as Uri, headers: c[1] as Map<String, String>);
  }

  ({Uri url, Map<String, dynamic>? body}) capturedSend(String method) {
    final c = switch (method) {
      'POST' => verify(
        () => client.post(captureAny(), headers: any(named: 'headers'), body: captureAny(named: 'body')),
      ).captured,
      'PATCH' => verify(
        () => client.patch(captureAny(), headers: any(named: 'headers'), body: captureAny(named: 'body')),
      ).captured,
      _ => verify(
        () => client.put(captureAny(), headers: any(named: 'headers'), body: captureAny(named: 'body')),
      ).captured,
    };
    final body = c[1] as String?;
    return (
      url: c[0] as Uri,
      body: body == null ? null : jsonDecode(body) as Map<String, dynamic>,
    );
  }

  group('ผู้เช่า', () {
    test('getReservation: GET พร้อม token และแปลงเป็น Reservation', () async {
      stubGet(jsonResponse({'success': true, 'data': reservationJson()}));

      final r = await service.getReservation(34);

      final sent = capturedGet();
      expect(sent.url, api('/api/booking/reservations/34'));
      expect(sent.headers['Authorization'], 'Bearer tenant-token');
      expect(sent.headers['Content-Type'], 'application/json');
      expect(sent.headers['ngrok-skip-browser-warning'], 'true');
      expect(r.id, 34);
      expect(r.status, ReservationStatus.awaitingPayment);
      expect(r.dormName, 'หอทดสอบ');
    });

    test('ยังไม่ login -> ไม่แนบ Authorization', () async {
      Session.clear();
      stubGet(jsonResponse({'data': {'dorm': {'id': 2}, 'plans': [], 'floors': []}}));

      await service.getRoomPlan(2);

      final sent = capturedGet();
      expect(sent.url, api('/api/booking/dorms/2/plan'));
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('reserve: POST ห้อง + แบบเช่า + วันเริ่ม (yyyy-mm-dd)', () async {
      stubPost(jsonResponse({'data': reservationJson()}, 201));

      final r = await service.reserve(roomId: 8, plan: 'month', startsAt: DateTime(2026, 12, 1));

      final sent = capturedSend('POST');
      expect(sent.url, api('/api/booking/reservations'));
      expect(sent.body, {'roomId': 8, 'plan': 'month', 'startsAt': '2026-12-01'});
      expect(r.status, ReservationStatus.awaitingPayment);
    });

    test('reserve ไม่ระบุวันเริ่ม -> ไม่ส่ง startsAt (ให้ server ใช้วันนี้)', () async {
      stubPost(jsonResponse({'data': reservationJson()}, 201));

      await service.reserve(roomId: 8, plan: 'term');

      expect(capturedSend('POST').body, {'roomId': 8, 'plan': 'term'});
    });

    test('pay / cancel: POST ไปที่ path ของรายการนั้น', () async {
      stubPost(jsonResponse({'data': reservationJson(status: 'paid')}));
      final paid = await service.pay(34);
      expect(capturedSend('POST').url, api('/api/booking/reservations/34/pay'));
      expect(paid.status, ReservationStatus.paid);

      stubPost(jsonResponse({'data': reservationJson(status: 'cancelled')}));
      final cancelled = await service.cancel(34);
      expect(capturedSend('POST').url, api('/api/booking/reservations/34/cancel'));
      expect(cancelled.status, ReservationStatus.cancelled);
    });

    test('myReservations: แปลงรายการ และข้ามข้อมูลที่ไม่ใช่ object', () async {
      stubGet(jsonResponse({
        'data': [reservationJson(id: 1), 'ขยะ', reservationJson(id: 2, status: 'completed')],
      }));

      final list = await service.myReservations();

      expect(capturedGet().url, api('/api/booking/reservations/mine'));
      expect(list.map((r) => r.id), [1, 2]);
      expect(list.last.status, ReservationStatus.completed);
    });

    test('data ไม่ใช่ list -> ได้รายการว่าง', () async {
      stubGet(jsonResponse({'data': null}));
      expect(await service.myReservations(), isEmpty);
    });
  });

  group('แอดมิน', () {
    test('adminPayments: ส่งตัวกรองสถานะใน query', () async {
      stubGet(jsonResponse({'data': [reservationJson(status: 'paid')]}));

      final list = await service.adminPayments(status: 'all');

      expect(capturedGet().url, api('/api/booking/admin/payments?status=all'));
      expect(list.single.status, ReservationStatus.paid);
    });

    test('adminReview: PATCH approve + เหตุผล / เหตุผลว่างไม่ส่ง', () async {
      stubPatch(jsonResponse({'data': reservationJson(status: 'rejected')}));
      await service.adminReview(34, approve: false, note: 'ยอดเงินไม่ตรง');
      final rejected = capturedSend('PATCH');
      expect(rejected.url, api('/api/booking/admin/payments/34'));
      expect(rejected.body, {'approve': false, 'note': 'ยอดเงินไม่ตรง'});

      stubPatch(jsonResponse({'data': reservationJson(status: 'approved')}));
      await service.adminReview(34, approve: true, note: '');
      expect(capturedSend('PATCH').body, {'approve': true});
    });
  });

  group('เจ้าของหอ', () {
    test('ownerReservations: ค่าเริ่มต้นคือ "รอเจ้าของหอยืนยัน"', () async {
      stubGet(jsonResponse({'data': []}));

      await service.ownerReservations();

      expect(capturedGet().url, api('/api/booking/owner/reservations?status=approved'));
    });

    test('ownerDecide: ยืนยัน = action confirm / ปฏิเสธ = action reject + เหตุผล', () async {
      stubPatch(jsonResponse({'data': reservationJson(status: 'completed')}));
      final done = await service.ownerDecide(34, confirm: true);
      final confirm = capturedSend('PATCH');
      expect(confirm.url, api('/api/booking/owner/reservations/34'));
      expect(confirm.body, {'action': 'confirm'});
      expect(done.status, ReservationStatus.completed);

      stubPatch(jsonResponse({'data': reservationJson(status: 'owner_rejected')}));
      await service.ownerDecide(34, confirm: false, note: 'ห้องต้องซ่อม');
      expect(capturedSend('PATCH').body, {'action': 'reject', 'note': 'ห้องต้องซ่อม'});
    });

    test('ownerPlans: แปลงราคาเช่าแต่ละแบบ', () async {
      stubGet(jsonResponse({
        'data': [
          {'plan': 'month', 'label': '1 เดือน', 'price': 4000, 'active': true},
          {'plan': 'week', 'label': '1 อาทิตย์', 'price': 0, 'active': false},
        ],
      }));

      final plans = await service.ownerPlans(2);

      expect(capturedGet().url, api('/api/booking/owner/dorms/2/plans'));
      expect(plans.map((p) => p.plan), ['month', 'week']);
      expect(plans.last.active, isFalse);
    });

    test('saveOwnerPlans: PUT รายการราคาในรูปที่ server ต้องการ', () async {
      stubPut(jsonResponse({'success': true}));

      await service.saveOwnerPlans(2, const [
        RentPlan(plan: 'month', label: '1 เดือน', price: 4000),
        RentPlan(plan: 'week', label: '1 อาทิตย์', price: 1200, active: false),
      ]);

      final sent = capturedSend('PUT');
      expect(sent.url, api('/api/booking/owner/dorms/2/plans'));
      expect(sent.body, {
        'plans': [
          {'plan': 'month', 'price': 4000, 'active': true},
          {'plan': 'week', 'price': 1200, 'active': false},
        ],
      });
    });
  });

  group('ข้อความ error จาก server', () {
    Future<String> errorOf(http.Response response) async {
      stubPost(response);
      try {
        await service.pay(34);
      } on BookingException catch (e) {
        return e.message;
      }
      fail('ต้อง throw BookingException');
    }

    test('401 -> ให้เข้าสู่ระบบก่อน', () async {
      expect(await errorOf(jsonResponse({'error': 'jwt expired'}, 401)), 'กรุณาเข้าสู่ระบบก่อน');
    });

    test('403 -> ใช้ข้อความจาก server / ไม่มีข้อความใช้ข้อความกลาง', () async {
      expect(await errorOf(jsonResponse({'message': 'ไม่ใช่การจองของคุณ'}, 403)), 'ไม่ใช่การจองของคุณ');
      expect(await errorOf(jsonResponse({}, 403)), 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้');
    });

    test('400 / 409 -> ใช้ message หรือ error จาก server', () async {
      expect(await errorOf(jsonResponse({'message': 'หมดเวลาชำระเงินแล้ว'}, 400)), 'หมดเวลาชำระเงินแล้ว');
      expect(await errorOf(jsonResponse({'error': 'ห้องนี้ถูกจองไปแล้ว'}, 409)), 'ห้องนี้ถูกจองไปแล้ว');
    });

    test('server พังแบบไม่ใช่ JSON -> บอกรหัสสถานะ', () async {
      expect(
        await errorOf(http.Response('<html>Internal Server Error</html>', 500)),
        'ทำรายการไม่สำเร็จ (500)',
      );
    });

    test('ตอบ 200 แต่ไม่มี data -> ข้อมูลไม่ถูกต้อง', () async {
      expect(await errorOf(jsonResponse({'success': true})), 'ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    });

    test('ต่อ server ไม่ได้ -> บอกให้เช็ก server / ngrok', () async {
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenThrow(http.ClientException('Connection refused'));

      await expectLater(
        service.getReservation(34),
        throwsA(
          isA<BookingException>().having(
            (e) => e.message,
            'message',
            contains('เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้'),
          ),
        ),
      );
    });
  });
}
