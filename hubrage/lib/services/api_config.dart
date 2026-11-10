class ApiConfig {
  // รันบน Chrome (flutter run -d chrome) เครื่องเดียวกับ server  -> 'http://localhost:3000'
  // Android emulator เครื่องเดียวกับ server                    -> 'http://10.0.2.2:3000'
  // มือถือจริง / เครื่องอื่น                                     -> URL ของ ngrok
  // แก้แล้วต้อง hot restart (R) หรือรันใหม่ hot reload (r) ค่าไม่เปลี่ยน
  static const _url = 'https://bubbly-scoreless-grazing.ngrok-free.dev';

  // ตัด / ท้ายออกเอง กันได้ //api/login แล้ว 404
  static String get baseUrl => _url.replaceAll(RegExp(r'/+$'), '');
}
