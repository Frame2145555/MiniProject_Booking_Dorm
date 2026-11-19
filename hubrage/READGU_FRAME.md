ngrok http 3000

node server.js
node tools/chat_cli.js seller@test.com //login เป็นผู้ขาย
tenant@test.com / 1234 //login เป็น user รหัสไหนก็ได้

flutter test test/unit/shared_auth_register_test.dart --reporter expanded
flutter test test/widget/tenant_chat_room_view_test.dart test/widget/tenant_chat_list_view_test.dart --reporter expanded
flutter test test/unit/shared_chat_logic_test.dart --reporter expanded
flutter test test/unit/shared_chat_controller_test.dart --reporter expanded

widget chat
flutter test test/widget/tenant_chat_list_view_test.dart --reporter expanded
flutter test test/widget/tenant_chat_room_view_test.dart --reporter expanded
flutter test test/widget/owner_chat_list_view_test.dart --reporter expanded
flutter test test/widget/owner_chat_room_view_test.dart --reporter expanded
flutter test test/widget/owner_chat_room_view_test.dart --reporter expanded

payment
flutter test test/widget/tenant_payment_view_test.dart --reporter expanded
flutter test test/widget/admin_payments_view_test.dart --reporter expanded
flutter test test/widget/owner_reservations_view_test.dart --reporter expanded

flutter test test/widget/tenant_search_view_test.dart --reporter expanded

flutter test test/widget --reporter expanded


flutter test test/unit/tenant_dorm_catalog_test.dart test/unit/admin_dorm_catalog_test.dart test/unit/owner_dorm_request_test.dart --reporter expanded
flutter test test/widget/tenant_search_view_test.dart --reporter expanded
flutter test test/widget/shared_auth_view_test.dart test/widget/shared_auth_session_view_test.dart --reporter expanded

เปิด `node server.js` ไว้ แล้วอีก terminal:
```bash
node test/integration/chat_smoke.js                                # ทดสอบในเครื่อง
node test/integration/chat_smoke.js https://xxxx.ngrok-free.app    # ทดสอบผ่าน ngrok (เช็คว่า tunnel + websocket ใช้ได้)
```
ต้องได้ `ผ่าน 22 / 22` เทสต์นี้เช็ค: login, เปิดห้อง, ห้องไม่ซ้ำ, ส่ง/รับข้อความทันที, คนนอกแอบอ่าน/แอบส่งไม่ได้, unread, อ่านแล้ว
(เทสต์จะเพิ่มข้อความจริงลงตาราง `messages` ลบทิ้งใน phpMyAdmin ได้)
flutter test test/widget/admin_dashboard_view_test.dart test/widget/admin_kyc_detail_view_test.dart test/widget/admin_payments_view_test.dart test/widget/admin_users_view_test.dart --reporter expanded
flutter test test/widget/owner_chat_list_view_test.dart test/widget/shared_admin_tenant_visibility_test.dart --reporter expanded
