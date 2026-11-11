// Unit test ฝั่ง backend (ไม่ต้องเปิด server / MySQL)
// วิธีรัน: npm test
const test = require('node:test');
const assert = require('node:assert');
const jwt = require('jsonwebtoken');
const { JWT_KEY, MAX_MESSAGE_LENGTH, getTokenFromHeader, verifyToken, cleanMessageText } = require('../chat_rules');

// res ปลอม จำไว้ว่าถูกเรียก status อะไร
const fakeRes = () => {
    const res = {statusCode: null, body: null};
    res.status = (code) => { res.statusCode = code; return res; };
    res.send = (body) => { res.body = body; return res; };
    return res;
};

//------------------- getTokenFromHeader --------------
test('getTokenFromHeader: ตัด Bearer ออก', () => {
    assert.strictEqual(getTokenFromHeader('Bearer abc123'), 'abc123');
});

test('getTokenFromHeader: ไม่มี header / รูปแบบผิด ได้ null', () => {
    assert.strictEqual(getTokenFromHeader(undefined), null);
    assert.strictEqual(getTokenFromHeader(''), null);
    assert.strictEqual(getTokenFromHeader('Bearer '), null);
    assert.strictEqual(getTokenFromHeader('abc123'), null);
    assert.strictEqual(getTokenFromHeader('Basic abc123'), null);
});

//------------------- verifyToken --------------
test('verifyToken: ไม่มี token ได้ 401 และไม่เรียก next', () => {
    const res = fakeRes();
    let called = false;
    verifyToken({headers: {}}, res, () => { called = true; });
    assert.strictEqual(res.statusCode, 401);
    assert.strictEqual(called, false);
});

test('verifyToken: token ปลอม ได้ 403', () => {
    const res = fakeRes();
    let called = false;
    verifyToken({headers: {authorization: 'Bearer not-a-real-token'}}, res, () => { called = true; });
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(called, false);
});

test('verifyToken: token หมดอายุ ได้ 403', () => {
    const expired = jwt.sign({id: 1, exp: Math.floor(Date.now() / 1000) - 60}, JWT_KEY);
    const res = fakeRes();
    verifyToken({headers: {authorization: 'Bearer ' + expired}}, res, () => {});
    assert.strictEqual(res.statusCode, 403);
});

test('verifyToken: token ที่ sign ด้วย key อื่น ได้ 403', () => {
    const forged = jwt.sign({id: 1, role: 'admin'}, 'wrong-key');
    const res = fakeRes();
    verifyToken({headers: {authorization: 'Bearer ' + forged}}, res, () => {});
    assert.strictEqual(res.statusCode, 403);
});

test('verifyToken: token ถูกต้อง เรียก next และใส่ payload ให้ req', () => {
    const token = jwt.sign({id: 7, email: 'a@test.com', role: 'tenant'}, JWT_KEY);
    const req = {headers: {authorization: 'Bearer ' + token}};
    const res = fakeRes();
    let called = false;
    verifyToken(req, res, () => { called = true; });
    assert.strictEqual(called, true);
    assert.strictEqual(res.statusCode, null);
    assert.strictEqual(req.payload.id, 7);
    assert.strictEqual(req.payload.role, 'tenant');
});

//------------------- cleanMessageText --------------
test('cleanMessageText: ตัดช่องว่างหน้า-หลัง', () => {
    assert.strictEqual(cleanMessageText({text: '  สวัสดีครับ  '}), 'สวัสดีครับ');
});

test('cleanMessageText: ข้อความว่าง / มีแต่ช่องว่าง ได้ null', () => {
    assert.strictEqual(cleanMessageText({text: ''}), null);
    assert.strictEqual(cleanMessageText({text: '   \n  '}), null);
});

test('cleanMessageText: ไม่มี data / text ไม่ใช่ string ได้ null', () => {
    assert.strictEqual(cleanMessageText(null), null);
    assert.strictEqual(cleanMessageText(undefined), null);
    assert.strictEqual(cleanMessageText({}), null);
    assert.strictEqual(cleanMessageText({text: 12345}), null);
    assert.strictEqual(cleanMessageText({text: {evil: true}}), null);
});

test('cleanMessageText: ยาวพอดี 2000 ตัวได้ / 2001 ตัวไม่ได้', () => {
    assert.strictEqual(cleanMessageText({text: 'ก'.repeat(MAX_MESSAGE_LENGTH)}).length, MAX_MESSAGE_LENGTH);
    assert.strictEqual(cleanMessageText({text: 'ก'.repeat(MAX_MESSAGE_LENGTH + 1)}), null);
});
