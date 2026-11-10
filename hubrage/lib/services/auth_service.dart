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
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/login');
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    final body = jsonEncode({'email': email, 'password': password});

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
    if (res.statusCode != 200) {
      return 'เข้าสู่ระบบไม่สำเร็จ (${res.statusCode}) ที่ ${ApiConfig.baseUrl}/api/login';
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

  static void logout() {
    ChatService.instance.disconnect();
    Session.clear();
  }
}
