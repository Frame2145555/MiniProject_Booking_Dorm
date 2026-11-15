// ทดสอบระบบแชทอัตโนมัติ (ต้องเปิด server.js ไว้ก่อน)
// วิธีรัน: node test_chat.js                         -> ทดสอบที่ http://localhost:3000
//         node test_chat.js https://xxxx.ngrok-free.app -> ทดสอบผ่าน ngrok
const { io } = require('socket.io-client');

// ตัด / ท้าย URL ออก (ใส่ https://xxx.ngrok-free.app/ มาก็ใช้ได้)
const BASE = (process.argv[2] || 'http://localhost:3000').replace(/\/+$/, '');
const headers = {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'};
let passed = 0;
let failed = 0;

const check = (name, ok) => {
    console.log((ok ? '✅ ' : '❌ ') + name);
    if(ok) passed++; else failed++;
};

const login = async (email) => {
    const res = await fetch(BASE + '/api/login', {
        method: 'POST', headers: headers,
        body: JSON.stringify({email: email, password: '1234'})
    });
    if(res.status != 200) throw new Error('login ' + email + ' ไม่ผ่าน: ' + await res.text());
    return res.json();
};

const api = (path, token, options = {}) => fetch(BASE + path, {
    ...options,
    headers: {...headers, 'Authorization': 'Bearer ' + token}
});

const connect = (token) => new Promise((resolve, reject) => {
    const socket = io(BASE, {transports: ['websocket'], auth: {token: token}, forceNew: true});
    socket.on('connect', () => resolve(socket));
    socket.on('connect_error', (err) => reject(err));
});

// รอ event ภายในเวลาที่กำหนด ถ้าไม่มาได้ null
const waitFor = (socket, event, ms = 3000) => new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), ms);
    socket.once(event, (data) => {
        clearTimeout(timer);
        resolve(data);
    });
});

const main = async () => {
    const tenant = await login('tenant@test.com');
    const seller = await login('seller@test.com');
    const other = await login('other@test.com');
    check('login ครบ 3 คน', tenant.token && seller.token && other.token);

    const wrong = await fetch(BASE + '/api/login', {
        method: 'POST', headers: headers,
        body: JSON.stringify({email: 'tenant@test.com', password: 'wrong'})
    });
    check('รหัสผิด login ไม่ได้ (401)', wrong.status == 401);

    // ผู้เช่าเปิดห้องแชทกับหอ id 1
    let res = await api('/api/conversations', tenant.token, {method: 'POST', body: JSON.stringify({dorm_id: 1})});
    const conv = await res.json();
    check('ผู้เช่าเปิดห้องแชทได้ (id = ' + conv.id + ')', res.status == 200 && conv.id > 0);

    res = await api('/api/conversations', tenant.token, {method: 'POST', body: JSON.stringify({dorm_id: 1})});
    check('เปิดซ้ำได้ห้องเดิม ไม่สร้างใหม่', (await res.json()).id == conv.id);

    res = await api('/api/conversations', seller.token, {method: 'POST', body: JSON.stringify({dorm_id: 1})});
    check('เจ้าของหอแชทกับหอตัวเองไม่ได้ (400)', res.status == 400);

    const tenantSocket = await connect(tenant.token);
    const sellerSocket = await connect(seller.token);
    const otherSocket = await connect(other.token);
    check('socket เชื่อมต่อได้ทั้ง 3 คน', true);

    let badToken = false;
    try { await connect('not-a-token'); } catch (e) { badToken = true; }
    check('token ปลอมต่อ socket ไม่ได้', badToken);

    const join = (socket, id) => new Promise((resolve) => socket.emit('join_conversation', id, resolve));
    check('ผู้เช่า join ห้องได้', (await join(tenantSocket, conv.id)).ok === true);
    check('เจ้าของหอ join ห้องได้', (await join(sellerSocket, conv.id)).ok === true);
    check('คนนอก join ห้องคนอื่นไม่ได้', (await join(otherSocket, conv.id)).ok === false);

    // ผู้เช่าส่งข้อความ -> เจ้าของหอต้องได้รับแบบ real time
    const sellerGets = waitFor(sellerSocket, 'new_message');
    const sellerListUpdated = waitFor(sellerSocket, 'conversation_updated');
    const otherGets = waitFor(otherSocket, 'new_message', 1000);
    const text = 'ทดสอบ ' + Date.now();
    const ack = await new Promise((resolve) =>
        tenantSocket.emit('send_message', {conversation_id: conv.id, text: text}, resolve));
    check('ส่งข้อความได้ (ack ok)', ack.ok === true);
    const msg = await sellerGets;
    check('เจ้าของหอได้รับข้อความทันที', msg && msg.text == text && msg.sender_id == tenant.id);
    check('รายการแชทของเจ้าของหอได้แจ้งอัปเดต', (await sellerListUpdated) != null);
    check('คนนอกไม่ได้รับข้อความ', (await otherGets) == null);

    const emptyAck = await new Promise((resolve) =>
        tenantSocket.emit('send_message', {conversation_id: conv.id, text: '   '}, resolve));
    check('ข้อความว่างส่งไม่ได้', emptyAck.ok === false);

    const otherAck = await new Promise((resolve) =>
        otherSocket.emit('send_message', {conversation_id: conv.id, text: 'แอบส่ง'}, resolve));
    check('คนนอกส่งเข้าห้องคนอื่นไม่ได้', otherAck.ok === false);

    // ประวัติข้อความ
    res = await api('/api/conversations/' + conv.id + '/messages', seller.token);
    const history = await res.json();
    check('เจ้าของหอโหลดประวัติได้และมีข้อความล่าสุด', history.length > 0 && history[history.length - 1].text == text);

    res = await api('/api/conversations/' + conv.id + '/messages', other.token);
    check('คนนอกอ่านประวัติห้องคนอื่นไม่ได้ (403)', res.status == 403);

    // ยังไม่อ่าน -> unread ต้อง > 0
    res = await api('/api/conversations', seller.token);
    let list = await res.json();
    let row = list.find((c) => c.id == conv.id);
    check('รายการแชทเจ้าของหอมี unread = ' + (row && row.unread), row && row.unread > 0);

    // เจ้าของหออ่าน -> ผู้เช่าต้องได้ messages_read
    const tenantGetsRead = waitFor(tenantSocket, 'messages_read');
    sellerSocket.emit('mark_read', conv.id);
    const read = await tenantGetsRead;
    check('ผู้เช่าได้รับแจ้งว่าอ่านแล้ว', read && read.reader_id == seller.id);

    res = await api('/api/conversations', seller.token);
    list = await res.json();
    row = list.find((c) => c.id == conv.id);
    check('อ่านแล้ว unread กลับเป็น 0', row && row.unread == 0);

    res = await api('/api/users', tenant.token);
    check('ดึงรายชื่อ users ตรงๆ ไม่ได้ (403)', res.status == 403);

    // ---------- logout แล้ว login ใหม่ -> ข้อความต้องยังอยู่ (บันทึกลง MySQL จริง) ----------
    tenantSocket.close();               // logout = ตัด socket ทิ้ง (เหมือน ChatService.disconnect)
    sellerSocket.close();
    const tenant2 = await login('tenant@test.com');   // login ใหม่ = ได้ token ใหม่
    const seller2 = await login('seller@test.com');
    check('logout แล้ว login ใหม่ได้ (บัญชีเดิม)', tenant2.token && tenant2.id == tenant.id);

    res = await api('/api/conversations/' + conv.id + '/messages', tenant2.token);
    const again = await res.json();
    const saved = Array.isArray(again) && again.find((m) => m.id == msg.id);
    check('login ใหม่แล้ว ผู้เช่ายังเห็นข้อความที่ส่งไป', saved && saved.text == text);
    check('ข้อความเก็บผู้ส่งถูกคน (sender_id = ผู้เช่า)', saved && saved.sender_id == tenant.id);
    check('สถานะ "อ่านแล้ว" ยังอยู่ (read_at ไม่ว่าง)', saved && saved.read_at != null);
    check('ข้อความเรียงจากเก่าไปใหม่', Array.isArray(again) &&
        again.every((m, i) => i == 0 || again[i - 1].id < m.id));

    res = await api('/api/conversations', tenant2.token);
    list = await res.json();
    row = list.find((c) => c.id == conv.id);
    check('รายการแชทหลัง login ใหม่ยังมีห้องนี้ + ข้อความล่าสุดถูกต้อง', row && row.last_message == text);

    res = await api('/api/conversations', seller2.token);
    list = await res.json();
    row = list.find((c) => c.id == conv.id);
    check('เจ้าของหอ login ใหม่ ข้อความที่อ่านแล้วไม่กลับมาเป็นยังไม่อ่าน', row && row.unread == 0);

    // socket ใหม่ยังคุยต่อในห้องเดิมได้
    const tenantSocket2 = await connect(tenant2.token);
    const sellerSocket2 = await connect(seller2.token);
    await join(tenantSocket2, conv.id);
    await join(sellerSocket2, conv.id);
    const sellerGets2 = waitFor(sellerSocket2, 'new_message');
    const text2 = 'หลัง login ใหม่ ' + Date.now();
    const ack2 = await new Promise((resolve) =>
        tenantSocket2.emit('send_message', {conversation_id: conv.id, text: text2}, resolve));
    const msg2 = await sellerGets2;
    check('login ใหม่แล้วแชทต่อในห้องเดิมได้', ack2.ok === true && msg2 && msg2.text == text2);

    tenantSocket2.close();
    sellerSocket2.close();
    otherSocket.close();
    console.log('\nผ่าน ' + passed + ' / ' + (passed + failed));
    // ใช้ exitCode แทน process.exit() กัน error ของ Node บน Windows (UV_HANDLE_CLOSING)
    process.exitCode = failed ? 1 : 0;
};

main().catch((err) => {
    console.error('❌ ทดสอบล้มเหลว:', err.message);
    process.exitCode = 1;
});