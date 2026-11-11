// ทดสอบระบบหอ/จอง/แอดมินแบบครบวงจร (ต้องเปิด server.js และรัน node seed_dorms.js ไว้ก่อน)
// วิธีรัน: node test_booking.js                          -> ทดสอบที่ http://localhost:3000
//         node test_booking.js https://xxxx.ngrok-free.app
// ขั้นตอน: เจ้าของหอเพิ่มหอ -> ผู้เช่ายังไม่เห็น -> แอดมินอนุมัติ -> ผู้เช่าเห็น -> กดหัวใจ
//         -> นัดดูห้อง + จองห้อง -> เจ้าของหอตอบรับ -> ห้องไม่ว่าง -> แอดมินระงับ/ปลดระงับบัญชี
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
    if(res.status != 200) throw new Error('login ' + email + ' ไม่ผ่าน (รัน node seed_dorms.js หรือยัง?): ' + await res.text());
    return (await res.json()).token;
};

// เรียก API แล้วคืน {status, body}
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

const main = async () => {
    const owner = await login('seller@test.com');
    const tenant = await login('tenant@test.com');
    const admin = await login('admin@test.com');

    // ---------- สิทธิ์ ----------
    check('ผู้เช่าเรียก API แอดมินไม่ได้ (403)', (await call('GET', '/api/admin/sellers', tenant)).status == 403);
    check('ไม่ login เรียก API แอดมินไม่ได้ (401)', (await call('GET', '/api/admin/sellers')).status == 401);

    // ---------- เจ้าของหอเพิ่มหอ (รออนุมัติ) ----------
    const name = 'หอทดสอบระบบ ' + Date.now();
    const created = await call('POST', '/api/owner/dorms', owner, {
        title: name, location: 'ซอยทดสอบ', description: 'ทดสอบ', phone: '0811111111',
        priceMin: 3000, priceMax: 4000, amenities: ['แอร์', 'Wi-Fi']
    });
    const dormId = created.body.data && created.body.data.dormId;
    check('เจ้าของหอเพิ่มหอได้ (pending)', created.status == 201 && dormId, created.body);
    const room = await call('POST', `/api/owner/dorms/${dormId}/rooms`, owner,
        {roomNumber: 'A1', roomType: 'ห้องแอร์', price: 3500, status: 'ว่าง'});
    const roomId = room.body.data && room.body.data.id;
    check('เจ้าของหอเพิ่มห้องได้', room.status == 201 && roomId, room.body);

    let list = await call('GET', '/api/tenant/dorms', tenant);
    check('ผู้เช่ายังไม่เห็นหอที่รออนุมัติ', !list.body.data.some(d => d.id == dormId));

    // ---------- แอดมินอนุมัติ ----------
    const pending = await call('GET', '/api/admin/dorms?status=pending', admin);
    const req = pending.body.data && pending.body.data.find(d => d.id == dormId);
    check('แอดมินเห็นหอในคิวรออนุมัติ พร้อมสิ่งอำนวยความสะดวก',
        req && req.sellerName && req.amenities.includes('แอร์'), pending.body);
    const approved = await call('PATCH', `/api/admin/dorms/${dormId}/approval`, admin, {approve: true});
    check('แอดมินอนุมัติหอได้', approved.status == 200 && approved.body.data.status == 'approved', approved.body);

    list = await call('GET', '/api/tenant/dorms', tenant);
    check('อนุมัติแล้ว ผู้เช่าเห็นหอในรายการ', list.body.data.some(d => d.id == dormId));

    // ---------- ผู้เช่า: หัวใจ / รายละเอียด / นัด / จอง ----------
    const fav = await call('POST', '/api/tenant/dorms/favorite', tenant, {dormId: dormId});
    check('ผู้เช่ากดหัวใจได้', fav.status == 200 && fav.body.isFavorite === true, fav.body);
    list = await call('GET', '/api/tenant/dorms', tenant);
    check('รายการหอบอก isFavorite = 1 เมื่อแนบ token', list.body.data.find(d => d.id == dormId).isFavorite == 1);
    const favOnly = await call('GET', '/api/tenant/dorms?favoritesOnly=true', tenant);
    check('ดึงเฉพาะหอโปรดได้', favOnly.body.data.every(d => d.isFavorite == 1) && favOnly.body.data.some(d => d.id == dormId));

    const detail = await call('GET', `/api/tenant/dorms/${dormId}`, tenant);
    check('ดูรายละเอียดหอ + รายการห้องได้', detail.status == 200 && detail.body.data.rooms.some(r => r.id == roomId), detail.body);

    const visit = await call('POST', '/api/tenant/visit-requests', tenant,
        {dormId: dormId, roomId: roomId, visitAt: '2030-01-15 14:00:00', tenantNote: 'ทดสอบ'});
    const visitId = visit.body.data && visit.body.data.visitRequestId;
    check('ผู้เช่าส่งคำขอนัดดูห้องได้', visit.status == 201 && visitId, visit.body);

    const booking = await call('POST', '/api/tenant/bookings', tenant, {roomId: roomId});
    const bookingId = booking.body.data && booking.body.data.bookingId;
    check('ผู้เช่าจองห้องได้', booking.status == 201 && bookingId, booking.body);

    const mine = await call('GET', '/api/tenant/bookings/my-bookings', tenant);
    check('ผู้เช่าเห็นการจอง/นัดของตัวเอง',
        mine.body.data.bookings.some(b => b.bookingId == bookingId) && mine.body.data.visitRequests.some(v => v.visitId == visitId));

    // ---------- เจ้าของหอตอบรับ ----------
    const ob = await call('GET', '/api/owner/bookings', owner);
    check('เจ้าของหอเห็นคำขอจอง', ob.body.data && ob.body.data.some(b => b.id == bookingId), ob.body);
    const other = await login('seller2@test.com');
    check('เจ้าของหอคนอื่นยืนยันการจองนี้ไม่ได้ (404)',
        (await call('PATCH', `/api/owner/bookings/${bookingId}/status`, other, {status: 'confirmed'})).status == 404);
    const conf = await call('PATCH', `/api/owner/bookings/${bookingId}/status`, owner, {status: 'confirmed'});
    check('เจ้าของหอยืนยันการจองได้', conf.status == 200, conf.body);
    const after = await call('GET', `/api/tenant/dorms/${dormId}`, tenant);
    check('ยืนยันแล้ว ห้องเปลี่ยนเป็นไม่ว่าง', after.body.data.rooms.find(r => r.id == roomId).status == 'occupied');
    check('จองห้องที่ไม่ว่างไม่ได้ (400)', (await call('POST', '/api/tenant/bookings', tenant, {roomId: roomId})).status == 400);
    const va = await call('PATCH', `/api/owner/visit-requests/${visitId}/status`, owner, {status: 'accepted', ownerNote: 'รอที่ล็อบบี้'});
    check('เจ้าของหอตอบรับนัดดูห้องได้', va.status == 200, va.body);

    // ---------- แอดมินระงับบัญชี ----------
    const sellers = await call('GET', '/api/admin/sellers', admin);
    const me = sellers.body.data && sellers.body.data.find(s => s.email == 'seller2@test.com');
    check('แอดมินเห็นรายชื่อเจ้าของหอ', me && me.dorms >= 1, sellers.body);
    const sus = await call('PATCH', `/api/admin/users/${me.id}/status`, admin, {suspend: true, reason: 'ทดสอบ'});
    check('แอดมินระงับบัญชีได้', sus.status == 200, sus.body);
    check('บัญชีที่ถูกระงับ login ไม่ได้ (403)', (await call('POST', '/api/login', null, {email: 'seller2@test.com', password: '1234'})).status == 403);
    const un = await call('PATCH', `/api/admin/users/${me.id}/status`, admin, {suspend: false});
    check('แอดมินปลดระงับได้', un.status == 200, un.body);

    // ---------- เก็บกวาด: ซ่อนหอทดสอบ ----------
    await call('PATCH', `/api/owner/dorms/${dormId}/visibility`, owner, {isClosed: true});
    await call('POST', '/api/tenant/dorms/favorite', tenant, {dormId: dormId});

    console.log(`\nผ่าน ${passed} / ${passed + failed}`);
    process.exitCode = failed ? 1 : 0;
};

main().catch((err) => {
    console.error('❌ ทดสอบไม่สำเร็จ:', err.message);
    process.exitCode = 1;
});
