import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'owner_api_config.dart';
import 'session.dart';

class OwnerApiException implements Exception {
  final String message;

  const OwnerApiException(this.message);

  @override
  String toString() => message;
}

class OwnerApiService {
  // ใช้ login เดียวกับทั้งแอป (Session) -> login ที่หน้าบัญชีหรือหน้านี้ที่ไหนก็ได้
  // แล้วใช้ได้ทั้งระบบเจ้าของหอและแชท ไม่ต้อง login ซ้ำ
  static String get _token => isLoggedIn ? Session.token : '';
  static int? get ownerId => isLoggedIn ? Session.userId : null;
  static String get ownerName => isLoggedIn ? Session.fullName : '';

  /// login อยู่ และเป็นบัญชีเจ้าของหอ (seller)
  static bool get isLoggedIn => Session.isLoggedIn && Session.role == 'seller';

  static Future<void> login(String email, String password) async {
    final error = await AuthService.login(email, password);
    if (error != null) throw OwnerApiException(error);
    if (Session.role != 'seller') {
      AuthService.logout();
      throw const OwnerApiException(
        'บัญชีนี้ไม่ใช่บัญชีเจ้าของหอ (ต้องเป็น role seller)',
      );
    }
  }

  static void logout() => AuthService.logout();

  static Future<Map<String, dynamic>> getDashboardStats() =>
      _send('GET', '/api/owner/dashboard/stats');

  static Future<List<Map<String, dynamic>>> getDorms() async {
    final response = await _send('GET', '/api/owner/dorms');
    final data = response['data'];
    if (data is! List) {
      throw const OwnerApiException(
        'รูปแบบรายการหอพักจากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> getVisitRequests() async {
    final response = await _send('GET', '/api/owner/visit-requests');
    final data = response['data'];
    if (data is! List) {
      throw const OwnerApiException('รูปแบบคำขอนัดจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
    return {
      ...response,
      'data': data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    };
  }

  /// คำขอจองห้องของหอเรา (owner_booking_routes.js)
  static Future<List<Map<String, dynamic>>> getBookings() async {
    final response = await _send('GET', '/api/owner/bookings');
    final data = response['data'];
    if (data is! List) {
      throw const OwnerApiException('รูปแบบคำขอจองจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// status: confirmed (ห้องจะเปลี่ยนเป็นมีผู้เช่า) | cancelled | completed
  static Future<void> setBookingStatus(String bookingId, String status) async {
    await _send(
      'PATCH',
      '/api/owner/bookings/$bookingId/status',
      body: {'status': status},
    );
  }

  /// status: accepted | declined | completed
  static Future<void> setVisitStatus(
    String visitId,
    String status, {
    String? ownerNote,
  }) async {
    await _send(
      'PATCH',
      '/api/owner/visit-requests/$visitId/status',
      body: {'status': status, if (ownerNote != null) 'ownerNote': ownerNote},
    );
  }

  static Future<void> createDorm(Map<String, dynamic> dorm) async {
    await _send('POST', '/api/owner/dorms', body: dorm);
  }

  static Future<void> updateDorm(String id, Map<String, dynamic> dorm) async {
    await _send('PUT', '/api/owner/dorms/$id', body: dorm);
  }

  static Future<void> setDormClosed(String id, bool isClosed) async {
    await _send(
      'PATCH',
      '/api/owner/dorms/$id/visibility',
      body: {'isClosed': isClosed},
    );
  }

  static Future<Map<String, dynamic>> createRoom(
    String dormId,
    Map<String, dynamic> room,
  ) => _send('POST', '/api/owner/dorms/$dormId/rooms', body: room);

  static Future<void> setRoomStatus(String roomId, String status) async {
    await _send(
      'PATCH',
      '/api/owner/rooms/$roomId/status',
      body: {'status': status},
    );
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${OwnerApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (authenticated && _token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    try {
      final request = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body)),
        _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
      };
      final response = await request.timeout(const Duration(seconds: 15));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw const OwnerApiException('เซิร์ฟเวอร์ตอบกลับข้อมูลไม่ถูกต้อง');
      }
      final data = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) logout();
        throw OwnerApiException(
          (data['message'] ?? data['error'])?.toString() ??
              'เรียกใช้ระบบเจ้าของหอไม่สำเร็จ (${response.statusCode})',
        );
      }
      return data;
    } on OwnerApiException {
      rethrow;
    } catch (error) {
      throw OwnerApiException(
        'เชื่อมต่อ ${OwnerApiConfig.baseUrl} ไม่สำเร็จ: $error',
      );
    }
  }
}
