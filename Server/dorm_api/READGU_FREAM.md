### 2.3 ngrok (เปิดอีกหน้าต่าง terminal)
```bash
ngrok http 3000
```
คัดลอก URL `https://xxxx.ngrok-free.app` ไปใส่ `lib/services/api_config.dart`
```dart
class ApiConfig {
  static const baseUrl = 'https://xxxx.ngrok-free.app';   // ไม่มี / ท้าย
}

เปิด `node server.js` ไว้ แล้วอีก terminal:
```bash
node test_chat.js                                # ทดสอบในเครื่อง
node test_chat.js https://xxxx.ngrok-free.app    # ทดสอบผ่าน ngrok (เช็คว่า tunnel + websocket ใช้ได้)
```
ต้องได้ `ผ่าน 22 / 22` เทสต์นี้เช็ค: login, เปิดห้อง, ห้องไม่ซ้ำ, ส่ง/รับข้อความทันที, คนนอกแอบอ่าน/แอบส่งไม่ได้, unread, อ่านแล้ว
(เทสต์จะเพิ่มข้อความจริงลงตาราง `messages` ลบทิ้งใน phpMyAdmin ได้)


Login เพื่อทดสอย
node chat_cli.js seller@test.com //login เป็นผู้ขาย
tenant@test.com / 1234 //login เป็น user รหัสไหนก็ได้