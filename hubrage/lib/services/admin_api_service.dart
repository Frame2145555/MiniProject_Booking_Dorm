
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session.dart';

class AdminApiException implements Exception {
  final String message;
  const AdminApiException(this.message);

  @override
  String toString() => message;
}

/// เรียก API แอดมิน (/api/admin/... ใน admin_routes.js) ต้อง login ด้วยบัญชี role = admin
class AdminApiService {
  AdminApiService._();

  /// ใส่ MockClient ตอน unit test (null = ใช้ http จริง)
  static http.Client? client;

  static bool get isAdmin => Session.isLoggedIn && Session.role == 'admin';

  static Future<List<Map<String, dynamic>>> getSellers() async =>
      _list((await _send('GET', '/api/admin/sellers'))['data']);

  /// status: pending | approved | rejected | all
  static Future<List<Map<String, dynamic>>> getDorms({String status = 'all'}) async =>
      _list((await _send('GET', '/api/admin/dorms?status=$status'))['data']);

  static Future<void> setDormApproval(int dormId, bool approve, {String? reason}) =>
      _send('PATCH', '/api/admin/dorms/$dormId/approval', body: {
        'approve': approve,
        if (reason != null) 'reason': reason,
      });

  static Future<void> setUserSuspended(int userId, bool suspend, {String? reason}) =>
      _send('PATCH', '/api/admin/users/$userId/status', body: {
        'suspend': suspend,
        if (reason != null) 'reason': reason,
      });

  static List<Map<String, dynamic>> _list(Object? raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!isAdmin) {
      throw const AdminApiException('กรุณาเข้าสู่ระบบด้วยบัญชีแอดมิน');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      'Authorization': 'Bearer ${Session.token}',
    };
    final c = client ?? http.Client();
    http.Response response;
    try {
      final request = method == 'GET'
          ? c.get(uri, headers: headers)
          : c.patch(uri, headers: headers, body: jsonEncode(body ?? const {}));
      response = await request.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AdminApiException(
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
      throw AdminApiException(
        (data['message'] ?? data['error'])?.toString() ??
            'เรียกใช้ระบบแอดมินไม่สำเร็จ (${response.statusCode})',
      );
    }
    return data;
  }
}
