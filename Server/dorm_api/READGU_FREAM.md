# วิธีรัน Dorm Master server

## ครั้งแรก
1. XAMPP → Start **MySQL** → phpMyAdmin → import `dorm_master.sql` (database ชื่อ `dorm_master`)
2. ในโฟลเดอร์ `dorm_api`:
```powershell
npm install               # ต้องได้ express 5 + cors (อยู่ใน package.json แล้ว)
node seed_passwords.js    # ตั้งรหัสผ่าน user ทดสอบเป็น 1234 (ครั้งเดียว)
node seed_dorms.js        # ใส่หอตัวอย่าง 4 หอให้ตรงกับในแอป + บัญชีเจ้าของหอ (รันซ้ำได้)
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
node chat_cli.js seller@test.com                 # แชทผ่าน terminal แทนเครื่องที่ 2
```

## บัญชีทดสอบ (รหัสผ่าน 1234)
| อีเมล | บทบาท | หอในแอป |
|---|---|---|
| tenant@test.com | ผู้เช่า | |
| other@test.com | ผู้เช่าอีกคน (ไว้ทดสอบว่าแอบดูแชทคนอื่นไม่ได้) | |
| seller@test.com | เจ้าของหอ | dorm_1 หอรวย เธะ |
| seller2@test.com | เจ้าของหอ | dorm_2 หออิสลาม แกรนด์ |
| seller3@test.com | เจ้าของหอ | dorm_3 HU 24 อพาร์ตเมนต์ (ในแอปถูกซ่อน เพราะ mock ตั้งผู้ขายคนนี้เป็น "ถูกระงับ") |
| seller4@test.com | เจ้าของหอ | dorm_4 กรีนวิลล์ คอนโดเช่า |

สมัครสมาชิกใหม่ผ่าน `POST /api/register` ได้ แต่รหัสผ่านต้องยาว 8 ตัวขึ้นไป

## ไฟล์ใน server
| ไฟล์ | หน้าที่ | เจ้าของงาน |
|---|---|---|
| `server.js` | จุดเริ่มต้น รวมทุกระบบไว้ที่พอร์ตเดียว (3000) + Socket.IO | รวม |
| `loginandregister.js` | /api/register, /api/login, /api/me | เพื่อน |
| `searchandsort.js` | /api/dorms, /api/dorms/:id, /api/amenities | เพื่อน |
| `chat_routes.js`, `chat_socket.js`, `chat_rules.js` | แชท: /api/conversations + real time | แชท |
| `Troutes/`, `Tcontrollers/`, `Tmiddleware/`, `Tconfig/` | /api/owner/... (เจ้าของหอ) และ /api/tenant/... (ค้นหา/จอง/นัดดูห้อง) | พี่ |
| `app.json` | port + **jwt_secret** (ทุกระบบใช้ key นี้ ห้ามลบ) | |
| `db-config.json` | ตั้งค่า MySQL | |
| `db.json` | ข้อมูลของ json-server (`/api/<ชื่อ>`) | |
| `seed_passwords.js` / `seed_dorms.js` | ใส่ข้อมูลทดสอบ | |

> รัน `node server.js` ตัวเดียวพอ ไม่ต้องรัน `Tserver.js` (พอร์ต 3001) แล้ว
> login ที่เดียว (`POST /api/login`) แล้วใช้ token ตัวเดียวกันกับทุกระบบได้

## API ทั้งหมด (พอร์ต 3000)
| กลุ่ม | เส้นทาง |
|---|---|
| บัญชี | `POST /api/register` · `POST /api/login` · `GET /api/me` · `POST /api/owner/login` (เฉพาะ seller) |
| ค้นหาหอ | `GET /api/dorms` · `GET /api/dorms/:id` · `GET /api/amenities` · `GET /api/tenant/dorms` · `GET /api/tenant/dorms/:id` |
| ผู้เช่า (ต้อง login) | `POST /api/tenant/dorms/favorite` · `POST /api/tenant/visit-requests` · `POST /api/tenant/bookings` · `GET /api/tenant/bookings/my-bookings` · `PATCH /api/tenant/bookings/:id/cancel` |
| เจ้าของหอ (ต้อง login เป็น seller) | `GET /api/owner/dashboard/stats` · `GET/POST /api/owner/dorms` · `PUT /api/owner/dorms/:id` · `PATCH /api/owner/dorms/:id/visibility` · `POST /api/owner/dorms/:dormId/rooms` · `PATCH /api/owner/rooms/:roomId/status` · `GET /api/owner/visit-requests` |
| แชท (ต้อง login) | `POST/GET /api/conversations` · `GET /api/conversations/:id/messages` · Socket.IO |

## ยังไม่มี
- **API แอดมิน** (อนุมัติ/ปฏิเสธหอ, ระงับผู้ขาย) — หอที่เจ้าของเพิ่มจะค้างสถานะ `pending` ผู้เช่าจะยังไม่เห็นและแชทไม่ได้ จนกว่าจะเปลี่ยน `approval_status` เป็น `approved` (ตอนนี้ต้องทำใน phpMyAdmin)
