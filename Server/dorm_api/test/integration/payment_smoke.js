// ทดสอบระบบจองแบบจ่ายเงินผ่านแอดมิน + แจ้งเตือนในแชท (ต้องเปิด server.js และรัน node scripts/seed_dorms.js ไว้ก่อน)
// วิธีรัน: node test/integration/payment_smoke.js
//         node test/integration/payment_smoke.js https://xxxx.ngrok-free.app
// ขั้นตอน: ผังห้อง -> จอง (รอชำระ/ติดจอง) -> จ่ายเงิน -> แอดมินอนุมัติ -> เจ้าของหอได้แจ้งเตือนในแชท
//         -> เจ้าของหอยืนยัน -> ห้องมีผู้เช่า + ผู้เช่าได้แจ้งเตือนในแชท  (+ เคสที่ต้องโดนปฏิเสธ)
const { io } = require('socket.io-client');
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
    const res = await fetch(BASE + '/api/login', {
        method: 'POST', headers: headers,
        body: JSON.stringify({email: email, password: '1234'})
    });
    if(res.status != 200) throw new Error('login ' + email + ' ไม่ผ่าน (รัน node scripts/seed_dorms.js หรือยัง?)');
    return res.json();
};

const call = async (method, path, token, body) => {
    const res = await fetch(BASE + path, {
        method: method,
        headers: token ? {...headers, 'Authorization': 'Bearer ' + token} : headers,
        body: body === undefined ? undefined : JSON.stringify(body)
    });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { json = {raw: text}; }
    return {status: res.status, body: json};
};

const connect = (token) => new Promise((resolve, reject) => {
    const socket = io(BASE, {transports: ['websocket'], auth: {token: token}, forceNew: true});
    socket.on('connect', () => resolve(socket));
    socket.on('connect_error', reject);
});

// รอ event ที่ตรงเงื่อนไข ภายในเวลาที่กำหนด ไม่มาได้ null
const waitFor = (socket, event, match = () => true, ms = 3000) => new Promise((resolve) => {
    const timer = setTimeout(() => { socket.off(event, handler); resolve(null); }, ms);
    const handler = (data) => {
        if(!match(data)) return;
        clearTimeout(timer);
        socket.off(event, handler);
        resolve(data);
    };
    socket.on(event, handler);
});

const main = async () => {
    const tenant = await login('tenant@test.com');
    const other = await login('other@test.com');
    const owner = await login('seller@test.com');
    const owner2 = await login('seller2@test.com');
    const admin = await login('admin@test.com');
    const DORM = 1;

    // เตรียมห้องว่างสำหรับทดสอบ (ห้อง T-xxx ชั้น 9) ให้ทดสอบซ้ำได้ทุกครั้ง
    const db = await mysql.createConnection({...require('../../db-config.json'), charset: 'utf8mb4'});
    const roomNumber = 'T' + (Date.now() % 100000);
    const [ins] = await db.query(
        "INSERT INTO rooms (dorm_id, room_number, room_type, price_per_month, floor, status) VALUES (?, ?, 'ห้องทดสอบ', 5000, 9, 'available')",
        [DORM, roomNumber]);
    const roomId = ins.insertId;

    // ---------- ผัง 2D ----------
    let plan = await call('GET', `/api/booking/dorms/${DORM}/plan`);
    const allRooms = plan.body.data ? plan.body.data.floors.flatMap((f) => f.rooms) : [];
    check('ดูผังห้องได้โดยไม่ login (ชั้น + ห้อง)', plan.status == 200 && plan.body.data.floors.length > 0, plan.body);
    check('ผังห้องมีสถานะครบ: ว่าง / มีผู้เช่า / ปรับปรุง',
        ['available', 'occupied', 'maintenance'].every((s) => allRooms.some((r) => r.state == s)));
    check('มีระยะเวลาเช่าให้เลือก 4 แบบ', plan.body.data.plans.length == 4, plan.body.data.plans);
    const testRoom = allRooms.find((r) => r.id == roomId);
    check('ราคาแต่ละแบบคิดจากค่าเช่าของห้อง (เดือน 5000 / อาทิตย์ 1250 / เทอม 20000 / ปี 60000)',
        testRoom.prices.month == 5000 && testRoom.prices.week == 1250 && testRoom.prices.term == 20000 && testRoom.prices.year == 60000,
        testRoom.prices);
    const monthPrice = testRoom.prices.month;

    // ---------- สิทธิ์ ----------
    check('ไม่ login จองไม่ได้ (401)', (await call('POST', '/api/booking/reservations', null, {roomId, plan: 'month'})).status == 401);
    check('เจ้าของหอจองห้องไม่ได้ (403)', (await call('POST', '/api/booking/reservations', owner.token, {roomId, plan: 'month'})).status == 403);
    const occupied = allRooms.find((r) => r.state == 'occupied');
    check('จองห้องที่มีผู้เช่าไม่ได้ (409)', (await call('POST', '/api/booking/reservations', tenant.token, {roomId: occupied.id, plan: 'month'})).status == 409);
    check('ระยะเวลาเช่าผิดไม่ได้ (400)', (await call('POST', '/api/booking/reservations', tenant.token, {roomId, plan: 'day'})).status == 400);

    // ---------- 1. จอง -> รอชำระเงิน ----------
    const created = await call('POST', '/api/booking/reservations', tenant.token, {roomId, plan: 'month'});
    const rv = created.body.data || {};
    check('ผู้เช่าจองได้ -> สถานะ "รอชำระเงิน"', created.status == 201 && rv.status == 'awaiting_payment', created.body);
    check('ยอดที่ต้องจ่าย = ค่าเช่า 1 เดือนของห้อง (' + monthPrice + ')', rv.amount == monthPrice);
    check('วันสิ้นสุดสัญญาคำนวณให้ (startsAt / endsAt)', rv.startsAt && rv.endsAt && rv.endsAt > rv.startsAt, rv);

    plan = await call('GET', `/api/booking/dorms/${DORM}/plan`, tenant.token);
    let mine = plan.body.data.floors.flatMap((f) => f.rooms).find((r) => r.id == roomId);
    check('ผังห้อง: ห้องนี้กลายเป็น "ติดจอง" และบอกว่าเป็นของฉัน', mine.state == 'reserved' && mine.myReservationId == rv.id, mine);
    check('คนอื่นจองห้องที่ติดจองไม่ได้ (409)', (await call('POST', '/api/booking/reservations', other.token, {roomId, plan: 'week'})).status == 409);
    check('เจ้าของหอยังไม่เห็นรายการที่ยังไม่จ่าย',
        !(await call('GET', '/api/booking/owner/reservations?status=all', owner.token)).body.data.some((x) => x.id == rv.id));
    check('แอดมินอนุมัติรายการที่ยังไม่จ่ายไม่ได้ (400)',
        (await call('PATCH', `/api/booking/admin/payments/${rv.id}`, admin.token, {approve: true})).status == 400);

    // ---------- 2. จ่ายเงิน (mock) ----------
    check('คนอื่นจ่ายแทนไม่ได้', (await call('POST', `/api/booking/reservations/${rv.id}/pay`, other.token)).status == 404);
    const paid = await call('POST', `/api/booking/reservations/${rv.id}/pay`, tenant.token, {amount: 1});
    const pv = paid.body.data || {};
    check('จ่ายเงินแล้ว -> "รอแอดมินตรวจสอบ" + มีเลขอ้างอิง', paid.status == 200 && pv.status == 'paid' && /^DM\d{8}-/.test(pv.paymentRef), paid.body);
    check('ยอดที่จ่าย = ยอดที่ต้องจ่าย (ส่งยอดเองมาไม่มีผล)', pv.paidAmount == monthPrice && pv.amountMatches === true);
    check('จ่ายซ้ำไม่ได้ (400)', (await call('POST', `/api/booking/reservations/${rv.id}/pay`, tenant.token)).status == 400);
    check('จ่ายแล้วยกเลิกเองไม่ได้ (400)', (await call('POST', `/api/booking/reservations/${rv.id}/cancel`, tenant.token)).status == 400);

    // ---------- 3. แอดมินตรวจเงิน -> แจ้งเตือนเจ้าของหอในแชท ----------
    check('ผู้เช่าเรียก API แอดมินไม่ได้ (403)', (await call('GET', '/api/booking/admin/payments', tenant.token)).status == 403);
    const queue = await call('GET', '/api/booking/admin/payments?status=paid', admin.token);
    check('แอดมินเห็นรายการในคิวรอตรวจ', queue.body.data.some((x) => x.id == rv.id && x.tenantName));

    const ownerSocket = await connect(owner.token);
    const ownerNotified = waitFor(ownerSocket, 'conversation_updated');
    const approved = await call('PATCH', `/api/booking/admin/payments/${rv.id}`, admin.token, {approve: true});
    check('แอดมินอนุมัติ -> "รอเจ้าของหอยืนยัน"', approved.status == 200 && approved.body.data.status == 'approved', approved.body);
    check('เจ้าของหอได้แจ้งเตือนทันที (socket)', (await ownerNotified) != null);

    let convs = (await call('GET', '/api/conversations', owner.token)).body;
    let conv = convs.find((c) => c.dorm_id == DORM && c.other_name == tenant.full_name);
    check('แชทของเจ้าของหอมีข้อความแจ้งเตือน "จองห้อง" + ยังไม่อ่าน',
        conv && conv.last_message.includes('จองห้อง ' + roomNumber) && conv.unread > 0, conv);
    const msgs = (await call('GET', `/api/conversations/${conv.id}/messages`, owner.token)).body;
    check('ข้อความแจ้งเตือนเป็นประเภท system', msgs[msgs.length - 1].type == 'system');

    const ownerList = await call('GET', '/api/booking/owner/reservations', owner.token);
    check('เจ้าของหอเห็นรายการรอยืนยัน', ownerList.body.data.some((x) => x.id == rv.id));
    check('เจ้าของหอคนอื่นยืนยันไม่ได้ (404)',
        (await call('PATCH', `/api/booking/owner/reservations/${rv.id}`, owner2.token, {action: 'confirm'})).status == 404);
    const legacy = await call('PATCH', `/api/owner/bookings/${rv.bookingId}/status`, owner.token, {status: 'confirmed'});
    check('ข้ามขั้นตอนไปยืนยันผ่านระบบจองเดิมไม่ได้ (400)', legacy.status == 400, legacy.body);

    // ---------- 4. เจ้าของหอยืนยัน -> จองสำเร็จ ----------
    const tenantSocket = await connect(tenant.token);
    const tenantNotified = waitFor(tenantSocket, 'conversation_updated');
    const done = await call('PATCH', `/api/booking/owner/reservations/${rv.id}`, owner.token, {action: 'confirm'});
    check('เจ้าของหอยืนยัน -> "จองสำเร็จ"', done.status == 200 && done.body.data.status == 'completed', done.body);
    check('ผู้เช่าได้แจ้งเตือนทันที (socket)', (await tenantNotified) != null);
    convs = (await call('GET', '/api/conversations', tenant.token)).body;
    conv = convs.find((c) => c.id == conv.id);
    check('แชทของผู้เช่ามีข้อความ "ยืนยันการจอง" + ยังไม่อ่าน',
        conv && conv.last_message.includes('ยืนยันการจองห้อง ' + roomNumber) && conv.unread > 0, conv);
    plan = await call('GET', `/api/booking/dorms/${DORM}/plan`);
    mine = plan.body.data.floors.flatMap((f) => f.rooms).find((r) => r.id == roomId);
    check('ผังห้อง: ห้องเปลี่ยนเป็น "มีผู้เช่า"', mine.state == 'occupied', mine);
    const my = await call('GET', '/api/booking/reservations/mine', tenant.token);
    check('การจองของฉันขึ้น "จองสำเร็จ"', my.body.data.find((x) => x.id == rv.id).statusLabel == 'จองสำเร็จ');

    // ---------- เคสปฏิเสธ / ยกเลิก / หมดเวลา ----------
    await db.query("UPDATE rooms SET status = 'available' WHERE id = ?", [roomId]);
    const r2 = (await call('POST', '/api/booking/reservations', other.token, {roomId, plan: 'week'})).body.data;
    check('จองแบบรายอาทิตย์ ยอด = ค่าเช่าเดือน ÷ 4', r2 && r2.amount == 1250, r2);
    const cancel = await call('POST', `/api/booking/reservations/${r2.id}/cancel`, other.token);
    check('ยกเลิกก่อนจ่ายได้ -> ห้องว่างอีกครั้ง', cancel.body.data && cancel.body.data.status == 'cancelled');

    const r3 = (await call('POST', '/api/booking/reservations', other.token, {roomId, plan: 'week'})).body.data;
    await call('POST', `/api/booking/reservations/${r3.id}/pay`, other.token);
    const rej = await call('PATCH', `/api/booking/admin/payments/${r3.id}`, admin.token, {approve: false, note: 'ยอดไม่ตรง'});
    check('แอดมินไม่อนุมัติ -> สถานะ rejected', rej.body.data && rej.body.data.status == 'rejected', rej.body);

    const r4 = (await call('POST', '/api/booking/reservations', other.token, {roomId, plan: 'week'})).body.data;
    check('ห้องกลับมาจองได้หลังแอดมินไม่อนุมัติ', r4 && r4.status == 'awaiting_payment');
    await db.query('UPDATE booking_payments SET expires_at = NOW() - INTERVAL 1 MINUTE WHERE id = ?', [r4.id]);
    const expired = await call('GET', `/api/booking/reservations/${r4.id}`, other.token);
    check('ไม่จ่ายภายในเวลา -> หมดเวลา และจ่ายไม่ได้แล้ว',
        expired.body.data.status == 'expired' && (await call('POST', `/api/booking/reservations/${r4.id}/pay`, other.token)).status == 400);

    const r5 = (await call('POST', '/api/booking/reservations', other.token, {roomId, plan: 'term'})).body.data;
    await call('POST', `/api/booking/reservations/${r5.id}/pay`, other.token);
    await call('PATCH', `/api/booking/admin/payments/${r5.id}`, admin.token, {approve: true});
    const ownerRej = await call('PATCH', `/api/booking/owner/reservations/${r5.id}`, owner.token, {action: 'reject', note: 'ห้องซ่อม'});
    check('เจ้าของหอปฏิเสธ -> owner_rejected (รอคืนเงิน)', ownerRej.body.data && ownerRej.body.data.status == 'owner_rejected', ownerRej.body);

    // ---------- เจ้าของหอตั้งราคา ----------
    const plans = await call('GET', `/api/booking/owner/dorms/${DORM}/plans`, owner.token);
    check('เจ้าของหอดูราคาที่ตั้งไว้ได้', plans.status == 200 && plans.body.data.length == 4);
    check('เจ้าของหออื่นดู/แก้ราคาหอนี้ไม่ได้ (404)', (await call('GET', `/api/booking/owner/dorms/${DORM}/plans`, owner2.token)).status == 404);
    const allOff = await call('PUT', `/api/booking/owner/dorms/${DORM}/plans`, owner.token,
        {plans: ['week', 'month', 'term', 'year'].map((k) => ({plan: k, active: false}))});
    check('ปิดทุกแบบไม่ได้ (400)', allOff.status == 400);
    const save = await call('PUT', `/api/booking/owner/dorms/${DORM}/plans`, owner.token,
        {plans: [{plan: 'week', active: false}]});
    plan = await call('GET', `/api/booking/dorms/${DORM}/plan`);
    check('ปิดแบบรายอาทิตย์ -> ผู้เช่าไม่เห็นตัวเลือกนี้', save.status == 200 && !plan.body.data.plans.some((p) => p.plan == 'week'));
    await call('PUT', `/api/booking/owner/dorms/${DORM}/plans`, owner.token, {plans: [{plan: 'week', active: true}]});

    // หอที่เจ้าของยังไม่เคยตั้งระยะเวลา -> เปิดทุกแบบให้อัตโนมัติ (จองได้ทันที)
    await db.query('DELETE FROM dorm_rent_plans WHERE dorm_id = ?', [DORM]);
    plan = await call('GET', `/api/booking/dorms/${DORM}/plan`);
    check('หอที่ยังไม่ตั้งระยะเวลา = เปิดให้เช่าทุกแบบ', plan.body.data.plans.length == 4);

    // เก็บกวาด: ลบห้องทดสอบ (การจองที่ผูกอยู่ถูกลบตาม)
    await db.query('DELETE b FROM bookings b WHERE b.room_id = ?', [roomId]);
    await db.query('DELETE FROM rooms WHERE id = ?', [roomId]);
    await db.end();
    ownerSocket.close();
    tenantSocket.close();

    console.log(`\nผ่าน ${passed} / ${passed + failed}`);
    process.exitCode = failed ? 1 : 0;
};

main().catch((err) => {
    console.error('❌ ทดสอบไม่สำเร็จ:', err.message);
    process.exitCode = 1;
});
