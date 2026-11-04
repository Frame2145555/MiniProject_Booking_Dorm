const jwt = require('jsonwebtoken');

// ตรวจว่าคำขอแนบ token มาถูกต้องหรือไม่
// token ต้องส่งมาในหัวข้อ Authorization: Bearer <token>
function verifyToken(req, res, next) {
  const header = req.headers.authorization || '';
  const [type, token] = header.split(' ');

  if (type !== 'Bearer' || !token) {
    return res.status(401).json({ success: false, message: 'Missing token' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    // เก็บว่าใครเรียก API ไว้ใน req.user ให้ Controller ใช้ต่อ
    req.user = { id: payload.id, role: payload.role };
    next(); // ผ่านด่านแล้ว ไปต่อ
  } catch (err) {
    return res
      .status(401)
      .json({ success: false, message: 'Invalid or expired token' });
  }
}

module.exports = { verifyToken };