# Project Hubrage

โปรเจกต์ระบบจองหอพัก ประกอบด้วยแอป Flutter และ API ที่พัฒนาด้วย Node.js

## โครงสร้างโปรเจกต์

| โฟลเดอร์ | เนื้อหา |
|---|---|
| [`hubrage/`](hubrage/) | แอป Flutter สำหรับ Android, iOS, เว็บ และเดสก์ท็อป |
| [`Server/dorm_api/`](Server/dorm_api/) | API หลัก ใช้ `server.js` เป็นจุดเริ่มต้น |
| [`jinkwaisunkumpang/`](jinkwaisunkumpang/) | API แยกอีกชุดที่มี routes สำหรับ owner/tenant และรันผ่าน `Tserver.js` |

## เริ่มใช้งาน

### API หลัก

```sh
cd Server/dorm_api
npm install
npm start
```

รายละเอียดการตั้งค่าฐานข้อมูล การ seed ข้อมูล และ API ดูที่ [คู่มือ API](Server/dorm_api/README.md)

### แอป Flutter

```sh
cd hubrage
flutter pub get
flutter run
```

โค้ดแอปอยู่ใน `hubrage/lib/` แยกตาม `views/`, `widgets/`, `models/`, `services/` และ `theme/`
