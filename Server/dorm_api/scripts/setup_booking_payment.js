// สร้างตารางของระบบจองแบบจ่ายเงิน (sql/booking_payment.sql) — รันซ้ำได้ ไม่พัง
// วิธีรัน: node scripts/setup_booking_payment.js      (ทำครั้งเดียวก่อนใช้ระบบจอง หรือ import ไฟล์ SQL ใน phpMyAdmin แทนก็ได้)
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

const main = async () => {
    const db = await mysql.createConnection({
        ...require('../db-config.json'),
        charset: 'utf8mb4',
        multipleStatements: true
    });
    const sql = fs.readFileSync(path.join(__dirname, '..', 'sql', 'booking_payment.sql'), 'utf8');
    await db.query(sql);
    const [tables] = await db.query("SHOW TABLES LIKE 'booking_payments'");
    const [plans] = await db.query("SHOW TABLES LIKE 'dorm_rent_plans'");
    const [col] = await db.query("SHOW COLUMNS FROM messages LIKE 'message_type'");
    console.log((tables.length ? '✅' : '❌') + ' ตาราง booking_payments');
    console.log((plans.length ? '✅' : '❌') + ' ตาราง dorm_rent_plans');
    console.log((col.length ? '✅' : '❌') + ' คอลัมน์ messages.message_type');
    await db.end();
    console.log('\nต่อไป: node scripts/seed_dorms.js (ใส่ราคาเช่าตัวอย่าง + ห้อง 3 ชั้น)');
};

main().catch((err) => {
    console.error('❌ สร้างตารางไม่สำเร็จ:', err.message);
    process.exitCode = 1;
});
