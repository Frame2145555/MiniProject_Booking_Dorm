// ทดสอบระบบแจ้งเตือน (กระดิ่ง): แอดมินอนุมัติค่ามัดจำ -> เจ้าของหอได้แจ้งเตือนในตาราง user_notifications
// ต้องเปิด server.js และรัน node scripts/seed_dorms.js ไว้ก่อน
// วิธีรัน: node test/integration/notifications_smoke.js
//         node test/integration/notifications_smoke.js https://xxxx.ngrok-free.app
const mysql = require('mysql2/promise');

const BASE = (process.argv[2] || 'http://localhost:3000').replace(/\/+$/, '');
const headers = {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'};
let passed = 0;
let failed = 0;

const check = (name, ok, extra) => {
    console.log((ok ? '✅ ' : '❌ ') + name + (ok || extra === undefined ? '' : '  -> ' + JSON.stringify(extra)));
    if(ok) passed++; else failed++;
};

const login = async (email) => {
    const res = await fetch(BASE + '/api/login', {method: 'POST', headers, body: JSON.stringify({email, password: '1234'})});
    if(res.status != 200) throw new Error('login ' + email + ' ไม่ผ่าน (รัน node scripts/seed_dorms.js หรือยัง?)');
    return res.json();
};

const call = async (method, path, token, body) => {
    const res = await fetch(BASE + path, {
        method, headers: token ? {...headers, 'Authorization': 'Bearer ' + token} : headers,
        body: body === undefined ? undefined : JSON.stringify(body)
    });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { json = {raw: text}; }
    return {status: res.status, body: json};
};

const main = async () => {
    const tenant = await login('tenant@test.com');
    const owner = await login('seller@test.com');
    const owner2 = await login('seller2@test.com');
    const admin = await login('admin@test.com');
    const DORM = 1; // หอของ seller@test.com

    const db = await mysql.createConnection({...require('../../db-config.json'), charset: 'utf8mb4'});
    const roomNumber = 'N' + (Date.now() % 100000);
    const [ins] = await db.query(
        "INSERT INTO rooms (dorm_id, room_number, room_type, price_per_month, floor, status) VALUES (?, ?, 'ห้องทดสอบ', 4000, 9, 'available')",
        [DORM, roomNumber]);
    const roomId = ins.insertId;

    check('ไม่ login ดูแจ้งเตือนไม่ได้ (401)', (await call('GET', '/api/notifications')).status == 401);

    const before = (await call('GET', '/api/notifications', owner.token)).body;
    check('เจ้าของหอเรียกรายการแจ้งเตือนได้', before.success === true && Array.isArray(before.data) && typeof before.unread == 'number', before);

    // จอง -> จ่ายเงิน (ยังไม่มีแจ้งเตือนจนกว่าแอดมินจะตรวจ)
    const rv = (await call('POST', '/api/booking/reservations', tenant.token, {roomId, plan: 'month'})).body.data || {};
    await call('POST', `/api/booking/reservations/${rv.id}/pay`, tenant.token);
    const mid = (await call('GET', '/api/notifications', owner.token)).body;
    check('จ่ายเงินแล้วแต่แอดมินยังไม่ตรวจ -> เจ้าของหอยังไม่ได้แจ้งเตือนค่ามัดจำ', !mid.data.some((n) => n.type == 'deposit_approved' && n.body.includes(roomNumber)));

    // แอดมินอนุมัติ -> เจ้าของหอได้แจ้งเตือน
    const approved = await call('PATCH', `/api/booking/admin/payments/${rv.id}`, admin.token, {approve: true});
    check('แอดมินอนุมัติค่ามัดจำได้', approved.status == 200, approved.body);

    const after = (await call('GET', '/api/notifications', owner.token)).body;
    const n = after.data.find((x) => x.type == 'deposit_approved' && x.body.includes(roomNumber));
    check('เจ้าของหอได้แจ้งเตือน "ค่ามัดจำ" (type deposit_approved)', !!n, after.data.slice(0, 3));
    check('ข้อความมีเลขห้อง + ยอด 4,000 บาท', n && n.body.includes(roomNumber) && n.body.includes('4,000'), n);
    check('แจ้งเตือนใหม่ยังไม่อ่าน และจำนวนยังไม่อ่านเพิ่มขึ้น', n && n.isRead === false && after.unread == before.unread + 1, {n, before: before.unread, after: after.unread});

    check('ผู้เช่าไม่เห็นแจ้งเตือนของเจ้าของหอ', !(await call('GET', '/api/notifications', tenant.token)).body.data.some((x) => x.type == 'deposit_approved' && x.body.includes(roomNumber)));
    check('เจ้าของหอคนอื่นไม่เห็น', !(await call('GET', '/api/notifications', owner2.token)).body.data.some((x) => x.type == 'deposit_approved' && x.body.includes(roomNumber)));
    check('เจ้าของหอคนอื่นกดอ่านของเราไม่ได้ (404)', (await call('PATCH', `/api/notifications/${n.id}/read`, owner2.token)).status == 404);

    // อ่าน
    check('กดอ่านรายการเดียวได้', (await call('PATCH', `/api/notifications/${n.id}/read`, owner.token)).status == 200);
    const read1 = (await call('GET', '/api/notifications', owner.token)).body;
    check('อ่านแล้ว -> isRead เป็น true และจำนวนยังไม่อ่านลดลง 1',
        read1.data.find((x) => x.id == n.id).isRead === true && read1.unread == after.unread - 1, read1.unread);
    check('กดอ่านซ้ำได้ ไม่ error', (await call('PATCH', `/api/notifications/${n.id}/read`, owner.token)).status == 200);
    check('รหัสผิดรูปแบบ (400)', (await call('PATCH', '/api/notifications/abc/read', owner.token)).status == 400);
    await call('POST', '/api/notifications/read-all', owner.token);
    check('อ่านทั้งหมด -> ยังไม่อ่าน 0', (await call('GET', '/api/notifications', owner.token)).body.unread == 0);

    // เก็บกวาด: ลบห้องทดสอบ + แจ้งเตือนที่สร้างขึ้นตอนทดสอบ
    await db.query("DELETE FROM user_notifications WHERE type = 'deposit_approved' AND message LIKE ?", ['%' + roomNumber + '%']);
    await db.query('DELETE b FROM bookings b WHERE b.room_id = ?', [roomId]);
    await db.query('DELETE FROM rooms WHERE id = ?', [roomId]);
    await db.end();

    console.log(`\nผ่าน ${passed} / ${passed + failed}`);
    process.exitCode = failed ? 1 : 0;
};

main().catch((err) => {
    console.error('❌ ทดสอบไม่สำเร็จ:', err.message);
    process.exitCode = 1;
});
