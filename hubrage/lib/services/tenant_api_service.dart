import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session.dart';

class TenantApiException implements Exception {
  final String message;
  const TenantApiException(this.message);

  @override
  String toString() => message;
}

/// เรียก API ฝั่งผู้เช่า (/api/tenant/... ของพี่ บน server ตัวรวม พอร์ต 3000)
/// ถ้า login อยู่จะแนบ token ไปด้วยเสมอ -> server รู้ว่าหอไหนเป็นหอโปรดของเรา
class TenantApiService {
  TenantApiService._();

  /// ใส่ MockClient ตอน unit test (null = ใช้ http จริง)
  static http.Client? client;

  /// หอที่อนุมัติแล้วและเปิดประกาศอยู่ (favoritesOnly = เฉพาะหอโปรด ต้อง login)
  static Future<List<Map<String, dynamic>>> getDorms({
    bool favoritesOnly = false,
  }) async {
    final res = await _send(
      'GET',
      '/api/tenant/dorms${favoritesOnly ? '?favoritesOnly=true' : ''}',
    );
    return _list(res['data']);
  }

  /// รายละเอียดหอ + รายการห้อง (server นับยอดเข้าชมให้ด้วย)
  static Future<Map<String, dynamic>> getDorm(int dormId) async {
    final res = await _send('GET', '/api/tenant/dorms/$dormId');
    final data = res['data'];
    if (data is! Map) {
      throw const TenantApiException('ข้อมูลหอพักจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
    return Map<String, dynamic>.from(data);
  }

  /// กดหัวใจ (server สลับสถานะให้) -> คืนสถานะใหม่
  static Future<bool> toggleFavorite(int dormId) async {
    final res = await _send(
      'POST',
      '/api/tenant/dorms/favorite',
      body: {'dormId': dormId},
      needLogin: true,
    );
    return res['isFavorite'] == true;
  }

  static Future<void> createVisitRequest({
    required int dormId,
    int? roomId,
    required DateTime visitAt,
    String note = '',
  }) async {
    await _send(
      'POST',
      '/api/tenant/visit-requests',
      body: {
        'dormId': dormId,
        if (roomId != null) 'roomId': roomId,
        'visitAt': formatDateTime(visitAt),
        'tenantNote': note,
      },
      needLogin: true,
    );
  }

  static Future<void> createBooking({
    required int roomId,
    DateTime? startsAt,
  }) async {
    await _send(
      'POST',
      '/api/tenant/bookings',
      body: {
        'roomId': roomId,
        if (startsAt != null) 'startsAt': formatDateTime(startsAt).substring(0, 10),
      },
      needLogin: true,
    );
  }

  /// { bookings: [...], visitRequests: [...] }
  static Future<Map<String, List<Map<String, dynamic>>>> getMyBookings() async {
    final res = await _send(
      'GET',
      '/api/tenant/bookings/my-bookings',
      needLogin: true,
    );
    final data = res['data'] is Map ? res['data'] as Map : const {};
    return {
      'bookings': _list(data['bookings']),
      'visitRequests': _list(data['visitRequests']),
    };
  }

  static Future<void> cancelBooking(int bookingId) async {
    await _send(
      'PATCH',
      '/api/tenant/bookings/$bookingId/cancel',
      needLogin: true,
    );
  }

  /// 2026-01-05 14:00:00 (รูปแบบที่ MySQL รับได้)
  static String formatDateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:00';
  }

  static List<Map<String, dynamic>> _list(Object? raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool needLogin = false,
  }) async {
    if (needLogin && !Session.isLoggedIn) {
      throw const TenantApiException('กรุณาเข้าสู่ระบบก่อน');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (Session.isLoggedIn) 'Authorization': 'Bearer ${Session.token}',
    };
    final c = client ?? http.Client();
    http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final request = switch (method) {
        'GET' => c.get(uri, headers: headers),
        'POST' => c.post(uri, headers: headers, body: encoded),
        'PATCH' => c.patch(uri, headers: headers, body: encoded),
        _ => throw ArgumentError.value(method, 'method'),
      };
      response = await request.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw TenantApiException(
        'เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้ (เปิด server / ngrok หรือยัง?)',
      );
    } finally {
      if (client == null) c.close();
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (data['message'] ?? data['error'])?.toString();
      if (response.statusCode == 401) {
        throw TenantApiException(message ?? 'กรุณาเข้าสู่ระบบใหม่');
      }
      throw TenantApiException(
        message ?? 'เรียกใช้ระบบไม่สำเร็จ (${response.statusCode})',
      );
    }
    return data;
  }
}
