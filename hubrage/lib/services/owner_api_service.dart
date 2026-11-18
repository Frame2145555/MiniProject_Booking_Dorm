import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  /// รายได้จากการจองที่เจ้าของหอยืนยันแล้ว (owner_revenue_routes.js)
  static Future<Map<String, dynamic>> getRevenue({int? year}) =>
      _send('GET', '/api/owner/revenue${year == null ? '' : '?year=$year'}');
  static Future<Map<String, dynamic>?> getKyc() async {
    final data = (await _send('GET', '/api/owner/kyc'))['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<Map<String, dynamic>> submitKyc({
    required String fullName,
    required String phone,
    required String email,
    required String idCardNumber,
    required String idCardImage,
    String? selfieImage,
  }) => _send(
    'POST',
    '/api/owner/kyc',
    body: {
      'idCardNumber': idCardNumber,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'idCardImage': idCardImage,
      if (selfieImage != null) 'selfieImage': selfieImage,
    },
  );

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

  static Future<List<Map<String, dynamic>>> getReviews() async {
    final response = await _send('GET', '/api/booking/owner/reviews');
    final data = response['data'];
    if (data is! List) {
      throw const OwnerApiException('รูปแบบรีวิวจากเซิร์ฟเวอร์ไม่ถูกต้อง');
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

  /// คืนรหัสหอพักที่สร้างใหม่ (ใช้อัปโหลดรูปเพิ่มเติมต่อ)
  static Future<int?> createDorm(Map<String, dynamic> dorm) async {
    final response = await _send('POST', '/api/owner/dorms', body: dorm);
    final data = response['data'];
    return data is Map ? int.tryParse('${data['dormId']}') : null;
  }

  /// อัปโหลดรูปเพิ่มเติม 1 รูป (ไบต์ดิบ) -> คืน url แบบ /uploads/dorms/<id>/<file>
  /// (dorm_images_routes.js: รองรับ jpg/png/webp/gif ไม่เกิน 8 MB)
  static Future<String> uploadDormImage(String dormId, Uint8List bytes) async {
    final uri = Uri.parse('${OwnerApiConfig.baseUrl}/api/owner/dorms/$dormId/images');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/octet-stream',
              'ngrok-skip-browser-warning': 'true',
              if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
      final decoded = response.body.isEmpty ? {} : jsonDecode(response.body);
      final data = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) logout();
        throw OwnerApiException(
          (data['message'] ?? data['error'])?.toString() ??
              'อัปโหลดรูปไม่สำเร็จ (${response.statusCode})',
        );
      }
      final url = (data['data'] is Map ? data['data']['url'] : null)?.toString();
      if (url == null || url.isEmpty) {
        throw const OwnerApiException('เซิร์ฟเวอร์ไม่ส่งลิงก์รูปกลับมา');
      }
      return url;
    } on OwnerApiException {
      rethrow;
    } catch (error) {
      throw OwnerApiException('อัปโหลดรูปไม่สำเร็จ: $error');
    }
  }

  /// บันทึกรายการรูปเพิ่มเติมของหอ (ลำดับตามที่ส่ง สูงสุด 10) -- ลิงก์ http(s) หรือ /uploads/...
  static Future<void> setDormImages(String dormId, List<String> urls) async {
    await _send('PUT', '/api/owner/dorms/$dormId/images', body: {'images': urls});
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

  /// แก้ไขข้อมูลห้อง (เลขห้อง / ประเภท / ราคา) -- สถานะห้องใช้ setRoomStatus
  static Future<Map<String, dynamic>> updateRoom(
    String roomId,
    Map<String, dynamic> room,
  ) => _send('PUT', '/api/owner/rooms/$roomId', body: room);

  /// ลบห้อง (server จะไม่ให้ลบถ้ามีผู้เช่าอยู่หรือมีประวัติการจอง)
  static Future<Map<String, dynamic>> deleteRoom(String roomId) =>
      _send('DELETE', '/api/owner/rooms/$roomId');

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
      debugPrint(
        '[OWNER API DEBUG] request $method $uri '
        'auth=${authenticated && _token.isNotEmpty} '
        'bodyBytes=${body == null ? 0 : utf8.encode(jsonEncode(body)).length}',
      );
      final request = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => http.delete(uri, headers: headers),
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
      debugPrint('[OWNER API DEBUG] $method $path -> ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[OWNER API DEBUG] response: ${data['error'] ?? data['message'] ?? data}',
        );
        if (response.statusCode == 401) logout();
        debugPrint('[OWNER API DEBUG] debugId: ${data['debugId'] ?? '-'}');
        throw OwnerApiException(
          (data['message'] ?? data['error'])?.toString() ??
              'เรียกใช้ระบบเจ้าของหอไม่สำเร็จ (${response.statusCode})',
        );
      }
      return data;
    } on OwnerApiException {
      rethrow;
    } catch (error) {
      debugPrint('[OWNER API ERROR] $method $uri -> $error');
      throw OwnerApiException(
        'เชื่อมต่อ ${OwnerApiConfig.baseUrl} ไม่สำเร็จ: $error',
      );
    }
  }
}
