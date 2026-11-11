import 'api_config.dart';

class OwnerApiConfig {
  // ตอนนี้ระบบเจ้าของหอรวมอยู่ใน server.js ตัวเดียวกับ login/แชท (พอร์ต 3000)
  // จึงใช้ URL เดียวกับ ApiConfig (แก้ที่ api_config.dart ที่เดียว ทั้งแอปเปลี่ยนตาม)
  // ถ้าอยากชี้ไป server แยก ใส่ตอนรัน: flutter run --dart-define=OWNER_API_URL=http://...
  static const _override = String.fromEnvironment('OWNER_API_URL');

  static String get baseUrl =>
      (_override.isNotEmpty ? _override : ApiConfig.baseUrl)
          .replaceAll(RegExp(r'/+$'), '');
}
