// Unit test การส่งแชท: ส่งข้อความแล้วอีกฝั่งได้รับจริงไหม
// เปิด socket server จริงใน memory แต่ใช้ DB ปลอม (ไม่ต้องเปิด server.js / MySQL)
// วิธีรัน: node --test --test-reporter=spec test/chat_socket.test.js
const { test, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const { io: connectClient } = require('socket.io-client');
const { JWT_KEY } = require('../chat_rules');
const { setupChatSocket } = require('../chat_socket');

const TENANT = 1;
const SELLER = 2;
const OUTSIDER = 3;

//------------------- DB ปลอม: เก็บข้อมูลใน array แทน MySQL --------------
const fakeDb = {
    conversations: [],
    messages: [],
    reset() {
        this.conversations = [{id: 10, dorm_id: 1, tenant_id: TENANT, owner_id: SELLER}];
        this.messages = [];
    },
    // ทำตัวเหมือน con.query(sql, params, callback) ของ mysql2
    query(sql, params, callback) {
        callback = callback || (() => {});
        if(sql.startsWith('SELECT * FROM conversations')){
            const [id, uid] = params;
            const conv = this.conversations.find((c) => c.id == id && (c.tenant_id == uid || c.owner_id == uid));
            return callback(null, conv ? [conv] : []);
        }
        if(sql.startsWith('INSERT INTO messages')){
            const [conversation_id, sender_id, message_text, sent_at] = params;
            const row = {id: this.messages.length + 1, conversation_id, sender_id, message_text, sent_at, read_at: null};
            this.messages.push(row);
            return callback(null, {insertId: row.id});
        }
        if(sql.startsWith('UPDATE conversations')){
            return callback(null, {affectedRows: 1});
        }
        if(sql.startsWith('UPDATE messages SET read_at')){
            const [readAt, conversationId, readerId] = params;
            let count = 0;
            this.messages.forEach((m) => {
                if(m.conversation_id == conversationId && m.sender_id != readerId && !m.read_at){
                    m.read_at = readAt;
                    count++;
                }
            });
            return callback(null, {affectedRows: count});
        }
        callback(new Error('SQL ที่ไม่ได้เตรียมไว้: ' + sql));
    }
};

//------------------- เปิด/ปิด socket server ใน memory --------------
let httpServer;
let url;
const clients = [];

before(async () => {
    httpServer = http.createServer();
    setupChatSocket(new Server(httpServer), fakeDb);
    await new Promise((resolve) => httpServer.listen(0, resolve));   // port 0 = ให้ระบบเลือก port ว่างเอง
    url = 'http://localhost:' + httpServer.address().port;
});

after(() => {
    httpServer.closeAllConnections();
    httpServer.close();
});

beforeEach(() => fakeDb.reset());

afterEach(() => {
    clients.forEach((c) => c.close());
    clients.length = 0;
});

//------------------- ตัวช่วย --------------
const tokenOf = (id) => jwt.sign({id: id, role: id == SELLER ? 'seller' : 'tenant'}, JWT_KEY);

// login เป็น user id นี้ แล้วต่อ socket
const connectAs = (id) => new Promise((resolve, reject) => {
    const socket = connectClient(url, {transports: ['websocket'], auth: {token: tokenOf(id)}, forceNew: true});
    clients.push(socket);
    socket.on('connect', () => resolve(socket));
    socket.on('connect_error', reject);
});

// ส่ง event แล้วรอ ack จาก server
const emitAck = (socket, event, data) => new Promise((resolve) => socket.emit(event, data, resolve));

// รอ event ถ้าไม่มาภายในเวลาที่กำหนดได้ null
const waitFor = (socket, event, ms = 1000) => new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), ms);
    socket.once(event, (data) => {
        clearTimeout(timer);
        resolve(data);
    });
});

// ผู้เช่ากับเจ้าของหอเข้าห้อง 10 พร้อมกัน
const openRoom = async () => {
    const tenant = await connectAs(TENANT);
    const seller = await connectAs(SELLER);
    await emitAck(tenant, 'join_conversation', 10);
    await emitAck(seller, 'join_conversation', 10);
    return { tenant, seller };
};

//------------------- Test --------------
test('ผู้เช่าส่งข้อความ -> เจ้าของหอได้รับทันที', async () => {
    const { tenant, seller } = await openRoom();

    const received = waitFor(seller, 'new_message');
    const ack = await emitAck(tenant, 'send_message', {conversation_id: 10, text: 'ห้องยังว่างไหมครับ'});
    const msg = await received;

    assert.strictEqual(ack.ok, true, 'server ต้องตอบ ok');
    assert.ok(msg, 'เจ้าของหอต้องได้รับข้อความ');
    assert.strictEqual(msg.text, 'ห้องยังว่างไหมครับ');
    assert.strictEqual(msg.sender_id, TENANT);
    assert.strictEqual(msg.conversation_id, 10);
});

test('เจ้าของหอตอบกลับ -> ผู้เช่าได้รับ', async () => {
    const { tenant, seller } = await openRoom();

    const received = waitFor(tenant, 'new_message');
    await emitAck(seller, 'send_message', {conversation_id: 10, text: 'ว่างครับ มาดูได้เลย'});
    const msg = await received;

    assert.ok(msg, 'ผู้เช่าต้องได้รับข้อความ');
    assert.strictEqual(msg.text, 'ว่างครับ มาดูได้เลย');
    assert.strictEqual(msg.sender_id, SELLER);
});

test('ข้อความที่ส่งถูกบันทึกลง DB ถูกต้อง', async () => {
    const { tenant } = await openRoom();

    await emitAck(tenant, 'send_message', {conversation_id: 10, text: '  สวัสดีครับ  '});

    assert.strictEqual(fakeDb.messages.length, 1);
    assert.strictEqual(fakeDb.messages[0].conversation_id, 10);
    assert.strictEqual(fakeDb.messages[0].sender_id, TENANT);
    assert.strictEqual(fakeDb.messages[0].message_text, 'สวัสดีครับ');   // ตัดช่องว่างแล้ว
});

test('รายการแชทของเจ้าของหอได้แจ้งเตือน (conversation_updated) แม้ยังไม่เปิดห้อง', async () => {
    const tenant = await connectAs(TENANT);
    const seller = await connectAs(SELLER);   // ไม่ได้ join ห้อง 10
    await emitAck(tenant, 'join_conversation', 10);

    const updated = waitFor(seller, 'conversation_updated');
    await emitAck(tenant, 'send_message', {conversation_id: 10, text: 'ทักครับ'});

    assert.deepStrictEqual(await updated, {conversation_id: 10});
});

test('คนนอกไม่ได้รับข้อความของห้องคนอื่น', async () => {
    const { tenant } = await openRoom();
    const outsider = await connectAs(OUTSIDER);
    const joined = await emitAck(outsider, 'join_conversation', 10);

    const leaked = waitFor(outsider, 'new_message', 500);
    await emitAck(tenant, 'send_message', {conversation_id: 10, text: 'ความลับ'});

    assert.strictEqual(joined.ok, false, 'คนนอก join ห้องไม่ได้');
    assert.strictEqual(await leaked, null, 'คนนอกต้องไม่ได้รับข้อความ');
});

test('คนนอกส่งข้อความเข้าห้องคนอื่นไม่ได้ และไม่ถูกบันทึก', async () => {
    const { seller } = await openRoom();
    const outsider = await connectAs(OUTSIDER);

    const received = waitFor(seller, 'new_message', 500);
    const ack = await emitAck(outsider, 'send_message', {conversation_id: 10, text: 'แอบส่ง'});

    assert.strictEqual(ack.ok, false);
    assert.strictEqual(await received, null);
    assert.strictEqual(fakeDb.messages.length, 0);
});

test('ข้อความว่างส่งไม่ได้', async () => {
    const { tenant } = await openRoom();

    const ack = await emitAck(tenant, 'send_message', {conversation_id: 10, text: '    '});

    assert.strictEqual(ack.ok, false);
    assert.strictEqual(fakeDb.messages.length, 0);
});

test('ปลอม sender_id ไม่ได้ (server ใช้ id จาก token เสมอ)', async () => {
    const { tenant, seller } = await openRoom();

    const received = waitFor(seller, 'new_message');
    await emitAck(tenant, 'send_message', {conversation_id: 10, text: 'ปลอมตัว', sender_id: SELLER});
    const msg = await received;

    assert.strictEqual(msg.sender_id, TENANT);
    assert.strictEqual(fakeDb.messages[0].sender_id, TENANT);
});

test('เจ้าของหออ่านแล้ว -> ผู้เช่าเห็น "อ่านแล้ว"', async () => {
    const { tenant, seller } = await openRoom();
    await emitAck(tenant, 'send_message', {conversation_id: 10, text: 'อ่านหรือยัง'});

    const readNotice = waitFor(tenant, 'messages_read');
    seller.emit('mark_read', 10);
    const notice = await readNotice;

    assert.deepStrictEqual(notice, {conversation_id: 10, reader_id: SELLER});
    assert.ok(fakeDb.messages[0].read_at, 'ใน DB ต้องมีเวลาที่อ่าน');
});

test('token ปลอมต่อ socket ไม่ได้', async () => {
    const socket = connectClient(url, {transports: ['websocket'], auth: {token: 'fake'}, forceNew: true});
    clients.push(socket);
    const err = await new Promise((resolve) => socket.on('connect_error', resolve));
    assert.strictEqual(err.message, 'unauthorized');
});
