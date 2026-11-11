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
    if (res.statusCode == 429) return 'ลองเข้าสู่ระบบผิดหลายครั้งเกินไป รอสักครู่แล้วลองใหม่';
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

  /// สมัครสมาชิก -> POST /api/register (server ตัวรวม พอร์ต 3000)
  /// คืนค่า null ถ้าสมัครสำเร็จ ไม่งั้นคืนข้อความ error ไว้โชว์ผู้ใช้
  /// [role] ส่งเป็น String ('tenant' / 'seller') หรือ enum UserRole ก็ได้
  /// สมัครเสร็จยังไม่ login ให้ (ผู้ใช้ไป login ต่อที่แท็บเข้าสู่ระบบ)
  static Future<String?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    Object? role,
    http.Client? client,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/register');
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    final roleName = role == null
        ? 'tenant'
        : (role is Enum ? role.name : role.toString());
    final body = jsonEncode({
      'email': email.trim(),
      'password': password,
      'full_name': fullName.trim(),
      'phone': (phone ?? '').trim(),
      'role': roleName,
    });

    http.Response res;
    try {
      final request = client == null
          ? http.post(url, headers: headers, body: body)
          : client.post(url, headers: headers, body: body);
      res = await request.timeout(const Duration(seconds: 10));
    } catch (e) {
      return 'เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้ (เปิด server / ngrok หรือยัง?)';
    }

    if (res.statusCode == 201 || res.statusCode == 200) return null;

    // server ส่ง { error: '...' } มาเป็นภาษาไทยอยู่แล้ว -> ใช้ข้อความนั้นเลย
    String? serverMessage;
    try {
      final data = jsonDecode(res.body);
      if (data is Map) serverMessage = (data['error'] ?? data['message'])?.toString();
    } catch (_) {}
    if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;

    if (res.statusCode == 409) return 'อีเมลนี้ถูกใช้งานแล้ว';
    if (res.statusCode == 429) return 'สมัครบ่อยเกินไป กรุณาลองใหม่ภายหลัง';
    return 'สมัครสมาชิกไม่สำเร็จ (${res.statusCode}) ที่ ${ApiConfig.baseUrl}/api/register';
  }

  static void logout() {
    ChatService.instance.disconnect();
    Session.clear();
  }
}
