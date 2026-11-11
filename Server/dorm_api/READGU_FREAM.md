# วิธีรัน Dorm Master server

## ครั้งแรก
1. XAMPP → Start **MySQL** → phpMyAdmin → import `dorm_master.sql` (database ชื่อ `dorm_master`)
2. ในโฟลเดอร์ `dorm_api`:
```powershell
npm install               # ต้องได้ express 5 + cors (อยู่ใน package.json แล้ว)
node seed_passwords.js    # ตั้งรหัสผ่าน user ทดสอบเป็น 1234 (ครั้งเดียว)
node seed_dorms.js        # หอตัวอย่าง 4 หอ (หอละ 3 ห้อง) + บัญชีเจ้าของหอ + บัญชีแอดมิน (รันซ้ำได้)
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
node test_chat.js                                # integration 22 ข้อ (ต้องเปิด server)
node test_chat.js https://xxxx.ngrok-free.app    # ทดสอบผ่าน ngrok
node test_booking.js                             # ระบบหอ/จอง/แอดมิน 25 ข้อ (ต้องเปิด server + รัน seed_dorms.js แล้ว)
node chat_cli.js seller@test.com                 # แชทผ่าน terminal แทนเครื่องที่ 2
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
| admin@test.com | แอดมิน (สร้างจาก `seed_dorms.js` เท่านั้น สมัครผ่านแอปไม่ได้) | |

สมัครสมาชิกใหม่ผ่าน `POST /api/register` ได้ แต่รหัสผ่านต้องยาว 8 ตัวขึ้นไป

## ไฟล์ใน server
| ไฟล์ | หน้าที่ | เจ้าของงาน |
|---|---|---|
| `server.js` | จุดเริ่มต้น รวมทุกระบบไว้ที่พอร์ตเดียว (3000) + Socket.IO | รวม |
| `loginandregister.js` | /api/register, /api/login, /api/me | เพื่อน |
| `searchandsort.js` | /api/dorms, /api/dorms/:id, /api/amenities | เพื่อน |
| `chat_routes.js`, `chat_socket.js`, `chat_rules.js` | แชท: /api/conversations + real time | แชท |
| `Troutes/`, `Tcontrollers/`, `Tmiddleware/`, `Tconfig/` | /api/owner/... (เจ้าของหอ) และ /api/tenant/... (ค้นหา/จอง/นัดดูห้อง) | พี่ |
| `owner_booking_routes.js` | เจ้าของหอ: ดูคำขอจอง + ยืนยัน/ปฏิเสธการจองและนัดดูห้อง (เพิ่มให้ ไม่ได้แก้ไฟล์ของพี่) | รวม |
| `admin_routes.js` | /api/admin/... อนุมัติ/ปฏิเสธหอ ระงับ/ปลดระงับบัญชี | รวม |
| `app.json` | port + **jwt_secret** (ทุกระบบใช้ key นี้ ห้ามลบ) | |
| `db-config.json` | ตั้งค่า MySQL | |
| `db.json` | ข้อมูลของ json-server (`/api/<ชื่อ>`) | |
| `seed_passwords.js` / `seed_dorms.js` | ใส่ข้อมูลทดสอบ | |
| `test_booking.js` | ทดสอบระบบหอ/จอง/แอดมินครบวงจร | |

> รัน `node server.js` ตัวเดียวพอ ไม่ต้องรัน `Tserver.js` (พอร์ต 3001) แล้ว
> login ที่เดียว (`POST /api/login`) แล้วใช้ token ตัวเดียวกันกับทุกระบบได้

## API ทั้งหมด (พอร์ต 3000)
| กลุ่ม | เส้นทาง |
|---|---|
| บัญชี | `POST /api/register` · `POST /api/login` · `GET /api/me` · `POST /api/owner/login` (เฉพาะ seller) |
| ค้นหาหอ | `GET /api/dorms` · `GET /api/dorms/:id` · `GET /api/amenities` · `GET /api/tenant/dorms` · `GET /api/tenant/dorms/:id` |
| ผู้เช่า (ต้อง login) | `POST /api/tenant/dorms/favorite` · `POST /api/tenant/visit-requests` · `POST /api/tenant/bookings` · `GET /api/tenant/bookings/my-bookings` · `PATCH /api/tenant/bookings/:id/cancel` |
| เจ้าของหอ (ต้อง login เป็น seller) | `GET /api/owner/dashboard/stats` · `GET/POST /api/owner/dorms` · `PUT /api/owner/dorms/:id` · `PATCH /api/owner/dorms/:id/visibility` · `POST /api/owner/dorms/:dormId/rooms` · `PATCH /api/owner/rooms/:roomId/status` · `GET /api/owner/visit-requests` · `PATCH /api/owner/visit-requests/:id/status` · `GET /api/owner/bookings` · `PATCH /api/owner/bookings/:id/status` |
| แอดมิน (ต้อง login เป็น admin) | `GET /api/admin/overview` · `GET /api/admin/sellers` · `PATCH /api/admin/users/:id/status` · `GET /api/admin/dorms?status=pending\|approved\|rejected\|all` · `PATCH /api/admin/dorms/:id/approval` |
| แชท (ต้อง login) | `POST/GET /api/conversations` · `GET /api/conversations/:id/messages` · Socket.IO |

## ขั้นตอนของระบบหอ (ทดสอบในแอปได้ครบ)
1. เจ้าของหอ (seller@test.com) เพิ่มหอในหน้าเจ้าของหอ → สถานะ **รออนุมัติ** ผู้เช่ายังไม่เห็น
2. แอดมิน (admin@test.com) เปิดโหมดแอดมิน → แท็บคำขอลงประกาศ → **อนุมัติหอ**
3. ผู้เช่า (tenant@test.com) เห็นหอในหน้าแรก/ค้นหา → กดหัวใจ (บันทึกลง DB) → เข้าหน้ารายละเอียด → **จองห้อง** / นัดดูห้อง / แชท
4. เจ้าของหอเห็นคำขอจองและคำขอนัด → กดยืนยัน (ห้องเปลี่ยนเป็น "มีผู้เช่า") หรือปฏิเสธ
5. ผู้เช่าดูสถานะได้ที่เมนู ☰ → **การจองและนัดดูห้องของฉัน**

## ยังไม่มี
- **รีวิว** และ **KYC** ในหน้าแอดมินยังเป็นข้อมูลตัวอย่าง (ฐานข้อมูลยังไม่มีตารางรีวิว / ยังไม่มี API อัปโหลดเอกสาร KYC)
- อัปโหลดรูป/ไฟล์เอกสารจริง (ตอนนี้เก็บแค่ลิงก์รูปและชื่อไฟล์)
