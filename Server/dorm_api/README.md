# วิธีรัน Dorm Master server

## ครั้งแรก
1. XAMPP → Start **MySQL** → phpMyAdmin → import `dorm_master.sql` (database ชื่อ `dorm_master`)
2. ในโฟลเดอร์ `dorm_api`:
```powershell
npm install               # ต้องได้ express 5 + cors (อยู่ใน package.json แล้ว)
npm run seed:passwords         # ตั้งรหัสผ่าน user ทดสอบเป็น 1234 (ครั้งเดียว)
npm run seed:dorms             # หอตัวอย่าง 4 หอ (หอละ 3 ห้อง) + บัญชีเจ้าของหอ + บัญชีแอดมิน (รันซ้ำได้)
```

## ทุกครั้งที่รัน (ใช้ 2 terminal แยกกัน)
**Terminal 1** — server (เปิดค้างไว้ ห้ามปิด)
```powershell
node server.js            # ต้องขึ้น "Server running on port 3000"
```
**Terminal 2** — ngrok (ใช้ตอนทดสอบบนมือถือ/เครื่องอื่น)
```powershell
ngrok http 127.0.0.1:3000
```
> `ngrok` กับ `node server.js` อยู่ terminal เดียวกันไม่ได้ เพราะทั้งคู่รันค้างไว้

คัดลอก URL ของ ngrok ไปใส่ `lib/services/api_config.dart`
```dart
static const _url = 'https://xxxx.ngrok-free.app';   // รันบน Chrome เครื่องเดียวกันใช้ 'http://localhost:3000'
```
แก้แล้วต้องหยุดแอปแล้วรันใหม่ (hot reload ไม่พอ)

## ทดสอบ
```powershell
npm test                                         # unit test 21 ข้อ (ไม่ต้องเปิด server)
npm run test:chat                                  # integration 30 ข้อ (ต้องเปิด server)
npm run test:chat -- https://xxxx.ngrok-free.app   # ทดสอบผ่าน ngrok
npm run test:booking                               # ระบบหอ/จอง/แอดมิน 25 ข้อ (ต้องเปิด server + รัน seed_dorms.js แล้ว)
npm run chat:cli -- seller@test.com                 # แชทผ่าน terminal แทนเครื่องที่ 2 (/rooms ดูห้อง, /room 3 เลือกห้อง, /auto)
```

## บัญชีทดสอบ (รหัสผ่าน 1234)
| อีเมล | บทบาท | หอในแอป |
|---|---|---|
| tenant@test.com | ผู้เช่า | |
| other@test.com | ผู้เช่าอีกคน (ไว้ทดสอบว่าแอบดูแชทคนอื่นไม่ได้) | |
| seller@test.com | เจ้าของหอ | dorm_1 หอรวย เธะ |
| seller2@test.com | เจ้าของหอ | dorm_2 หออิสลาม แกรนด์ |
| seller3@test.com | เจ้าของหอ | dorm_3 HU 24 อพาร์ตเมนต์ |
| seller4@test.com | เจ้าของหอ | dorm_4 กรีนวิลล์ คอนโดเช่า |
| admin@test.com | แอดมิน (สร้างจาก `scripts/seed_dorms.js` เท่านั้น สมัครผ่านแอปไม่ได้) | |

สมัครสมาชิกใหม่ผ่าน `POST /api/register` ได้ แต่รหัสผ่านต้องยาว 8 ตัวขึ้นไป

## ไฟล์ใน server
| ไฟล์ | หน้าที่ | เจ้าของงาน |
|---|---|---|
| `server.js` | จุดเริ่มต้น รวมทุกระบบไว้ที่พอร์ตเดียว (3000) + Socket.IO | รวม |
| `routes/` | แยก route handlers ของ owner, tenant, admin, booking และ chat | รวม |
| `scripts/` | seed ข้อมูลและสร้าง schema สำหรับระบบจอง | รวม |
| `test/` | unit tests และสคริปต์ integration | รวม |
| `tools/` | เครื่องมือช่วยทดสอบผ่าน terminal | รวม |
| `loginandregister.js` | /api/register, /api/login, /api/me | เพื่อน |
| `searchandsort.js` | /api/dorms, /api/dorms/:id, /api/amenities | เพื่อน |
| `routes/chatRoutes.js`, `chat_socket.js`, `chat_rules.js` | แชท: /api/conversations + real time | แชท |
| `controllers/`, `middleware/`, `config/` | logic, auth และการเชื่อมต่อฐานข้อมูล | พี่ |
| `routes/ownerBookingRoutes.js` | เจ้าของหอ: ดูคำขอจอง + ยืนยัน/ปฏิเสธการจองและนัดดูห้อง (เพิ่มให้ ไม่ได้แก้ไฟล์ของพี่) | รวม |
| `routes/adminRoutes.js` | /api/admin/... อนุมัติ/ปฏิเสธหอ ระงับ/ปลดระงับบัญชี | รวม |
| `routes/ownerRoomRoutes.js` | เจ้าของหอ: แก้ไข/ลบห้อง (เลขห้อง ประเภท ราคา ชั้น) | mamew |
| `routes/ownerRevenueRoutes.js` | เจ้าของหอ: สรุปรายได้รายเดือน/รายหอ | mamew |
| `routes/dormImagesRoutes.js` | เจ้าของหอ: อัปโหลดรูปหน้าปก/รูปเพิ่มเติม (ไฟล์อยู่ใน `uploads/dorms/`) | mamew |
| `routes/notificationRoutes.js` | กระดิ่งแจ้งเตือนทุกบทบาท (ใช้ตาราง `user_notifications`) | mamew |
| `routes/reviewRoutes.js` | รีวิวหอพัก: ผู้เช่าเขียน / แอดมินซ่อน-แสดง-ลบ | mamew |
| `app.json` | port + **jwt_secret** (ทุกระบบใช้ key นี้ ห้ามลบ) | |
| `db-config.json` | ตั้งค่า MySQL | |
| `db.json` | ข้อมูลของ json-server (`/api/<ชื่อ>`) | |
| `scripts/seed_passwords.js` / `scripts/seed_dorms.js` | ใส่ข้อมูลทดสอบ | |
| `test/integration/booking_smoke.js` | ทดสอบระบบหอ/จอง/แอดมินครบวงจร | |
| `test/integration/notifications_smoke.js` | ทดสอบกระดิ่งแจ้งเตือนเจ้าของหอ (`npm run test:notifications`) | |

> รัน `node server.js` ตัวเดียวพอ ไม่ต้องเปิดเซิร์ฟเวอร์ legacy พอร์ต 3001 อีกต่อไป
> login ที่เดียว (`POST /api/login`) แล้วใช้ token ตัวเดียวกันกับทุกระบบได้

## API ทั้งหมด (พอร์ต 3000)
| กลุ่ม | เส้นทาง |
|---|---|
| บัญชี | `POST /api/register` · `POST /api/login` · `GET /api/me` · `POST /api/owner/login` (เฉพาะ seller) |
| ค้นหาหอ | `GET /api/dorms` · `GET /api/dorms/:id` · `GET /api/amenities` · `GET /api/tenant/dorms` · `GET /api/tenant/dorms/:id` |
| ผู้เช่า | `GET /api/tenant/dorms/:dormId/reviews` · `POST /api/tenant/dorms/:dormId/reviews` (ผู้เช่าที่กำลังพัก) · `POST /api/tenant/dorms/favorite` · `POST /api/tenant/visit-requests` · `POST /api/tenant/bookings` · `GET /api/tenant/bookings/my-bookings` · `PATCH /api/tenant/bookings/:id/cancel` · `GET /api/tenant/notifications` · `PATCH /api/tenant/notifications/read` |
| เจ้าของหอ (ต้อง login เป็น seller) | `GET /api/owner/dashboard/stats` · `PUT/DELETE /api/owner/rooms/:roomId` · `GET /api/owner/revenue?year=` · `POST/PUT /api/owner/dorms/:dormId/images` · `GET/POST /api/owner/dorms` · `PUT /api/owner/dorms/:id` · `PATCH /api/owner/dorms/:id/visibility` · `POST /api/owner/dorms/:dormId/rooms` · `PATCH /api/owner/rooms/:roomId/status` · `GET /api/owner/visit-requests` · `PATCH /api/owner/visit-requests/:id/status` · `GET /api/owner/bookings` · `PATCH /api/owner/bookings/:id/status` |
| แอดมิน (ต้อง login เป็น admin) | `GET /api/admin/overview` · `GET /api/admin/sellers` · `GET /api/admin/reviews?status=visible\|hidden\|all` · `PATCH /api/admin/reviews/:id` · `DELETE /api/admin/reviews/:id` · `GET /api/admin/reports?status=pending\|resolved\|dismissed\|all` · `PATCH /api/admin/reports/:id` · `PATCH /api/admin/users/:id/status` · `GET /api/admin/dorms?status=pending\|approved\|rejected\|all` · `PATCH /api/admin/dorms/:id/approval` · `GET /api/admin/dorm-documents/:id` · `GET /api/admin/dorm-documents/:id/link` |
| แจ้งเตือน (ต้อง login ทุกบทบาท) | `GET /api/notifications` · `POST /api/notifications/read-all` · `PATCH /api/notifications/:id/read` |
| แชท (ต้อง login) | `POST/GET /api/conversations` · `GET /api/conversations/:id/messages` · Socket.IO |

## ขั้นตอนของระบบหอ (ทดสอบในแอปได้ครบ)
1. เจ้าของหอ (seller@test.com) เพิ่มหอในหน้าเจ้าของหอ → สถานะ **รออนุมัติ** ผู้เช่ายังไม่เห็น
2. แอดมิน (admin@test.com) เปิดโหมดแอดมิน → แท็บคำขอลงประกาศ → **อนุมัติหอ**
3. ผู้เช่า (tenant@test.com) เห็นหอในหน้าแรก/ค้นหา → กดหัวใจ (บันทึกลง DB) → เข้าหน้ารายละเอียด → **จองห้อง** / นัดดูห้อง / แชท
4. เจ้าของหอเห็นคำขอจองและคำขอนัด → กดยืนยัน (ห้องเปลี่ยนเป็น "มีผู้เช่า") หรือปฏิเสธ
5. ผู้เช่าดูสถานะได้ที่เมนู ☰ → **การจองและนัดดูห้องของฉัน**
6. เมื่อเจ้าของยืนยันและถึงวันเข้าพัก ผู้เช่าที่กำลังพักเขียนรีวิวได้; owner ดูรีวิวหอตนเองและ admin ดู/ซ่อน/ลบได้

## ระบบจองห้องแบบชำระเงินผ่านแอดมิน (`routes/bookingPaymentRoutes.js`)
ตาราง: `dorm_rent_plans`, `booking_payments` + คอลัมน์ `messages.message_type` (ไฟล์ `sql/booking_payment.sql`)
**server สร้างให้เองตอนเปิด** (หรือรัน `npm run setup:booking` / import ไฟล์ SQL ใน phpMyAdmin) แล้วรัน `node scripts/seed_dorms.js` เพื่อใส่ห้อง 3 ชั้น

**ยอดเงิน = ค่าเช่าต่อเดือนของห้อง (ที่เจ้าของหอตั้งตอนเพิ่มห้อง) x ระยะเวลา**: 1 อาทิตย์ = ÷4, 1 เดือน = x1, 1 เทอม = x4, 1 ปี = x12
เจ้าของหอเลือกได้ว่าหอนี้เปิดให้เช่าแบบไหน (ยังไม่ตั้ง = เปิดทุกแบบ)

1. ผู้เช่าเปิดผังห้อง 2D (เขียว ว่าง / เทา มีผู้เช่า / ฟ้า ติดจอง / แดง ปรับปรุง) → เลือกห้อง + ระยะเวลา (1 อาทิตย์ / 1 เดือน / 1 เทอม / 1 ปี ที่หอเปิดให้เช่า) → **จอง** = รอชำระเงิน (ห้องติดจอง 30 นาที)
2. หน้าชำระเงิน: QR จำลอง + ยอดที่ระบบล็อกตามราคาเจ้าของหอ → กด **จ่ายเงิน** = รอแอดมินตรวจสอบ
3. แอดมิน (☰ → ตรวจสอบการชำระเงินค่าจอง) ดูยอดที่ต้องจ่าย vs ยอดที่ได้รับ → **อนุมัติ** → ระบบส่งข้อความแจ้งเตือนเข้าแชทของเจ้าของหอ
4. เจ้าของหอ (☰ → คำขอจอง) → **ยืนยันการจอง** → ห้องเป็น "มีผู้เช่า" + แจ้งเตือนผู้เช่าในแชท (หรือปฏิเสธ → แอดมินคืนเงิน)

ทดสอบ: `npm run test:payment` (45 ข้อ)

| ใคร | API |
|---|---|
| ทุกคน | `GET /api/booking/dorms/:dormId/plan` |
| ผู้เช่า | `POST /api/booking/reservations` · `GET /api/booking/reservations/mine` · `GET /api/booking/reservations/:id` · `POST /api/booking/reservations/:id/pay` · `POST /api/booking/reservations/:id/cancel` |
| แอดมิน | `GET /api/booking/admin/payments?status=paid` · `PATCH /api/booking/admin/payments/:id` `{approve, note}` |
| เจ้าของหอ | `GET /api/booking/owner/reservations?status=approved` · `PATCH /api/booking/owner/reservations/:id` `{action: confirm/reject}` · `GET/PUT /api/booking/owner/dorms/:dormId/plans` |
| เจ้าของหอ | `GET /api/booking/owner/reviews` (ดูรีวิวของหอตนเอง) |

## รายงานประกาศหอจากผู้เช่า
ตาราง `user_dorm_reports` และ `user_notifications` สร้างให้อัตโนมัติตอนเปิด `server.js` จากไฟล์ SQL ที่เกี่ยวข้อง

ผู้เช่าที่เข้าสู่ระบบส่งรายงานหอที่เปิดประกาศอยู่ได้ที่ `POST /api/tenant/dorms/:dormId/reports`
โดยส่ง `{category, description}`; ผู้ใช้ส่งรายงานซ้ำหอเดิมขณะที่มีรายงานรอตรวจไม่ได้
แอดมินดูรายการผ่าน `GET /api/admin/reports?status=pending|resolved|dismissed|all`
และปิดรายการผ่าน `PATCH /api/admin/reports/:id` ด้วย `{status: resolved|dismissed, note}`
คำสั่งปิดเรื่องต้องมีหมายเหตุ และบันทึกผู้ตรวจ/วันตรวจพร้อม audit log และ notification
ให้ผู้รายงานเดิม โดยผู้เช่าดูรายการได้ที่ `GET /api/tenant/notifications` และทำเครื่องหมายอ่านแล้วผ่าน `PATCH /api/tenant/notifications/read`

## รีวิวหอพัก
ตาราง `dorm_reviews` สร้างอัตโนมัติตอนเปิด `server.js` จาก `sql/dorm_reviews.sql`
ผู้เช่าจะรีวิวได้เมื่อมีรายการจองที่เจ้าของหอยืนยันแล้ว, ห้องยังมีสถานะผู้เช่า,
และวันปัจจุบันอยู่ในช่วงเข้าพัก; รีวิวได้หนึ่งครั้งต่อหอ ให้คะแนน 1–5 ดาว
ผู้ใช้ทั่วไปอ่านรีวิวที่แสดงอยู่ได้ เจ้าของหอดูรีวิวของตนผ่านหน้าเจ้าของหอ
และแอดมินซ่อน/แสดงหรือลบรีวิวได้จากหน้ารีวิวใน Dashboard

## ส่วนเสริมเจ้าของหอ (รวมมาจาก mamew)
ตาราง `dorm_images` สร้างให้อัตโนมัติตอนเปิด `server.js`
- แอดมินอนุมัติค่ามัดจำ -> เจ้าของหอได้แจ้งเตือน `deposit_approved` ที่กระดิ่ง (`GET /api/notifications`)
- รายได้ = การจองที่เจ้าของหอกดยืนยันแล้ว (`booking_payments.status = 'completed'`)
- ลบห้องไม่ได้ถ้ามีผู้เช่าอยู่หรือมีประวัติการจอง (ให้ตั้งสถานะ "ปรับปรุง" แทน)

## เอกสารแนบคำขอลงประกาศหอ
เจ้าของหอแนบไฟล์ (PDF/JPG/PNG ไม่เกิน 6 MB) ตอนเพิ่มหอ -> ตัวไฟล์เก็บที่ `storage/dorm_documents/<dormId>/`
ฐานข้อมูลเก็บแค่ที่อยู่ไฟล์ใน `dorm_documents.private_storage_key` (ไม่เก็บไฟล์ลง MySQL เพราะ XAMPP จำกัดขนาดข้อมูลต่อคำสั่งไว้ 1 MB)
โฟลเดอร์ `storage/` ไม่ได้เปิดให้เข้าตรงๆ ต้องเปิดผ่านหน้าแอดมินเท่านั้น และควรสำรองไว้พร้อมฐานข้อมูล
แอดมินกด "ดูเอกสาร" ในหน้าตรวจคำขอ: รูปแสดงในแอป, PDF ใช้ลิงก์ชั่วคราว 10 นาทีเปิดในเบราว์เซอร์
คำขอที่ส่งมาก่อนมีระบบนี้มีแค่ชื่อไฟล์ ต้องให้เจ้าของหอส่งเอกสารใหม่
