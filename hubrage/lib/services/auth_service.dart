import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'chat_service.dart';
import 'session.dart';

class AuthService {
  /// คืนค่า null ถ้า login สำเร็จ ไม่งั้นคืนข้อความ error ไว้โชว์ผู้ใช้
  /// [client] กับ [connectSocket] ไว้ใช้ตอน unit test (ส่ง MockClient เข้ามาแทน server จริง)
  static Future<String?> login(
    String email,
    String password, {
    http.Client? client,
    bool connectSocket = true,
  }) =>
      _authenticate(
        '/api/login',
        {'email': email, 'password': password},
        client: client,
        connectSocket: connectSocket,
      );

  /// สมัครสมาชิก แล้ว login ให้เลย (server ตอบ token ชุดเดียวกับ login)
  /// [role] = 'tenant' (ผู้เช่า) หรือ 'seller' (เจ้าของหอ) — คืน null ถ้าสำเร็จ ไม่งั้นคืนข้อความ error
  static Future<String?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'tenant',
    http.Client? client,
    bool connectSocket = true,
  }) =>
      _authenticate(
        '/api/register',
        {
          'email': email,
          'password': password,
          'full_name': fullName,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'role': role,
        },
        client: client,
        connectSocket: connectSocket,
      );

  static Future<String?> _authenticate(
    String path,
    Map<String, dynamic> payload, {
    http.Client? client,
    required bool connectSocket,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    final body = jsonEncode(payload);

    http.Response res;
    try {
      final request = client == null
          ? http.post(url, headers: headers, body: body)
          : client.post(url, headers: headers, body: body);
      res = await request.timeout(const Duration(seconds: 10));
    } catch (e) {
      return 'เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้ (เปิด server / ngrok หรือยัง?)';
    }

    if (res.statusCode == 401) return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    if (res.statusCode == 403) return 'บัญชีนี้ถูกระงับ';
    // 400 ข้อมูลไม่ครบ/ไม่ถูกต้อง, 409 อีเมลซ้ำ, 429 ลองบ่อยเกินไป -> server ส่งข้อความไทยมาให้แล้ว
    if (res.statusCode == 400 || res.statusCode == 409 || res.statusCode == 429) {
      return _serverMessage(res) ?? 'ข้อมูลไม่ถูกต้อง (${res.statusCode})';
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      return 'เข้าสู่ระบบไม่สำเร็จ (${res.statusCode}) ที่ ${ApiConfig.baseUrl}$path';
    }

    if (Session.isLoggedIn) logout(); // login เป็นคนใหม่ = ออกจากบัญชีเดิมก่อน
    final data = jsonDecode(res.body);
    Session.token = data['token'];
    Session.userId = data['id'];
    Session.role = data['role'];
    Session.fullName = data['full_name'] ?? '';

    if (connectSocket) ChatService.instance.connect(); // ต่อ socket ก่อน แล้วค่อยแจ้งหน้าอื่น
    Session.loggedIn.value = true; // หน้าแชท/บัญชีที่ฟังอยู่จะอัปเดตเอง
    return null;
  }

  static String? _serverMessage(http.Response res) {
    try {
      final msg = jsonDecode(res.body)['error'];
      return msg is String && msg.isNotEmpty ? msg : null;
    } catch (_) {
      return null;
    }
  }

  static void logout() {
    ChatService.instance.disconnect();
    Session.clear();
  }
}
