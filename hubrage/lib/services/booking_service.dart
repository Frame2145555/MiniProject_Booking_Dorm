import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/booking_models.dart';
import 'api_config.dart';
import 'session.dart';

class BookingException implements Exception {
  final String message;
  const BookingException(this.message);

  @override
  String toString() => message;
}

/// Service (MVC) ของระบบจองแบบจ่ายเงิน: คุยกับ server อย่างเดียว (/api/booking/... ใน booking_payment_routes.js)
/// ได้ JSON มาแล้วแปลงเป็น model ก่อนส่งให้ controller
/// ตอน test ส่ง BookingService ปลอม (หรือ MockClient) เข้า controller แทนได้
class BookingService {
  BookingService({http.Client? client}) : _client = client;

  static final BookingService instance = BookingService();

  final http.Client? _client;

  // ───────────── ผู้เช่า ─────────────

  Future<DormRoomPlan> getRoomPlan(int dormId) async {
    final res = await _send('GET', '/api/booking/dorms/$dormId/plan');
    return DormRoomPlan.fromJson(_map(res['data']));
  }

  /// จองห้อง -> ได้รายการสถานะ "รอชำระเงิน" (ห้องติดจองตามเวลาที่ server กำหนด)
  Future<Reservation> reserve({
    required int roomId,
    required String plan,
    DateTime? startsAt,
  }) async {
    final res = await _send('POST', '/api/booking/reservations', body: {
      'roomId': roomId,
      'plan': plan,
      if (startsAt != null) 'startsAt': _ymd(startsAt),
    });
    return Reservation.fromJson(_map(res['data']));
  }

  /// จ่ายเงิน (mock) — server บังคับยอดตามราคาที่เจ้าของหอตั้งเอง
  Future<Reservation> pay(int reservationId) async =>
      Reservation.fromJson(_map((await _send('POST', '/api/booking/reservations/$reservationId/pay'))['data']));

  Future<Reservation> cancel(int reservationId) async =>
      Reservation.fromJson(_map((await _send('POST', '/api/booking/reservations/$reservationId/cancel'))['data']));

  Future<Reservation> getReservation(int reservationId) async =>
      Reservation.fromJson(_map((await _send('GET', '/api/booking/reservations/$reservationId'))['data']));

  Future<List<Reservation>> myReservations() async =>
      _list((await _send('GET', '/api/booking/reservations/mine'))['data']);

  // ───────────── แอดมิน ─────────────

  /// status: paid (รอตรวจ) | approved | rejected | completed | all
  Future<List<Reservation>> adminPayments({String status = 'paid'}) async =>
      _list((await _send('GET', '/api/booking/admin/payments?status=$status'))['data']);

  Future<Reservation> adminReview(int reservationId, {required bool approve, String? note}) async =>
      Reservation.fromJson(_map((await _send('PATCH', '/api/booking/admin/payments/$reservationId', body: {
        'approve': approve,
        if (note != null && note.isNotEmpty) 'note': note,
      }))['data']));

  // ───────────── เจ้าของหอ ─────────────

  /// status: approved (รอเจ้าของยืนยัน) | completed | owner_rejected | all
  Future<List<Reservation>> ownerReservations({String status = 'approved'}) async =>
      _list((await _send('GET', '/api/booking/owner/reservations?status=$status'))['data']);

  Future<Reservation> ownerDecide(int reservationId, {required bool confirm, String? note}) async =>
      Reservation.fromJson(_map((await _send('PATCH', '/api/booking/owner/reservations/$reservationId', body: {
        'action': confirm ? 'confirm' : 'reject',
        if (note != null && note.isNotEmpty) 'note': note,
      }))['data']));

  Future<List<RentPlan>> ownerPlans(int dormId) async {
    final data = (await _send('GET', '/api/booking/owner/dorms/$dormId/plans'))['data'];
    return (data is List ? data : const [])
        .whereType<Map>()
        .map((p) => RentPlan.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<void> saveOwnerPlans(int dormId, List<RentPlan> plans) async {
    await _send('PUT', '/api/booking/owner/dorms/$dormId/plans', body: {
      'plans': plans.map((p) => p.toJson()).toList(),
    });
  }

  // ───────────── ส่วนกลาง ─────────────

  static String _ymd(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _map(Object? data) {
    if (data is! Map) throw const BookingException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    return Map<String, dynamic>.from(data);
  }

  static List<Reservation> _list(Object? data) => (data is List ? data : const [])
      .whereType<Map>()
      .map((e) => Reservation.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (Session.isLoggedIn) 'Authorization': 'Bearer ${Session.token}',
    };
    final c = _client ?? http.Client();
    http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final request = switch (method) {
        'GET' => c.get(uri, headers: headers),
        'POST' => c.post(uri, headers: headers, body: encoded),
        'PUT' => c.put(uri, headers: headers, body: encoded),
        'PATCH' => c.patch(uri, headers: headers, body: encoded),
        _ => throw ArgumentError.value(method, 'method'),
      };
      response = await request.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw BookingException('เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้ (เปิด server / ngrok หรือยัง?)');
    } finally {
      if (_client == null) c.close();
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) throw const BookingException('กรุณาเข้าสู่ระบบก่อน');
      final message = (data['message'] ?? data['error'])?.toString();
      if (response.statusCode == 403) {
        throw BookingException(message ?? 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้');
      }
      throw BookingException(message ?? 'ทำรายการไม่สำเร็จ (${response.statusCode})');
    }
    return data;
  }
}
