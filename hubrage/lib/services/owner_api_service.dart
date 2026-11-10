import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owner_api_config.dart';

class OwnerApiException implements Exception {
  final String message;

  const OwnerApiException(this.message);

  @override
  String toString() => message;
}

class OwnerApiService {
  static String _token = '';
  static int? ownerId;
  static String ownerName = '';

  static bool get isLoggedIn => _token.isNotEmpty;

  static Future<void> login(String email, String password) async {
    final response = await _send(
      'POST',
      '/api/owner/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    _token = response['token']?.toString() ?? '';
    ownerId = int.tryParse(response['id'].toString());
    ownerName = response['full_name']?.toString() ?? '';
    if (_token.isEmpty || ownerId == null) {
      logout();
      throw const OwnerApiException(
        'ข้อมูลเข้าสู่ระบบจากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }
  }

  static void logout() {
    _token = '';
    ownerId = null;
    ownerName = '';
  }

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
          data['message']?.toString() ??
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
