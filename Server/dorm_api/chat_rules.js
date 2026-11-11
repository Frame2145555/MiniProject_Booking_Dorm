// ฟังก์ชันที่ไม่ต้องใช้ DB แยกออกมาจาก server.js เพื่อให้เขียน unit test ได้
const jwt = require('jsonwebtoken');

// ต้องเป็น key เดียวกับระบบ login (loginandregister.js) ไม่งั้น token ที่ login ได้มาจะใช้กับแชทไม่ได้
// ลำดับเหมือนกัน: env JWT_SECRET ก่อน แล้วค่อย jwt_secret ใน app.json
const JWT_KEY = process.env.JWT_SECRET || require('./app.json').jwt_secret;
if(!JWT_KEY || String(JWT_KEY).length < 16){
    throw new Error('ต้องตั้ง jwt_secret ใน app.json (ยาวอย่างน้อย 16 ตัว) หรือ env JWT_SECRET');
}
const MAX_MESSAGE_LENGTH = 2000;

// "Bearer xxx" -> "xxx" / ไม่มี header -> null
const getTokenFromHeader = (header) => {
    if(!header) return null;
    const parts = header.split(' ');
    if(parts.length != 2 || parts[0] != 'Bearer' || !parts[1]) return null;
    return parts[1];
};

//middleware
const verifyToken = (req, res, next) => {
    const token = getTokenFromHeader(req.headers['authorization']);
    if(!token) return res.status(401).send('no token');

    jwt.verify(token, JWT_KEY, (err, payload) => {
        if(err){
            // wrong jwt or expired jwt
            return res.status(403).send('unauthorized');
        }
        req.payload = payload;
        next();
    });
};

// ตรวจข้อความก่อนบันทึก: ได้ข้อความที่ trim แล้ว หรือ null ถ้าใช้ไม่ได้
const cleanMessageText = (data) => {
    if(!data || typeof data.text != 'string') return null;
    const text = data.text.trim();
    if(!text || text.length > MAX_MESSAGE_LENGTH) return null;
    return text;
};

module.exports = { JWT_KEY, MAX_MESSAGE_LENGTH, getTokenFromHeader, verifyToken, cleanMessageText };
