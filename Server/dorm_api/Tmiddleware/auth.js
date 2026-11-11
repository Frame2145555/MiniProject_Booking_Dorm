const jwt = require('jsonwebtoken');
const db = require('../Tconfig/db');

const requireAuth = async (req, res, next) => {
  const authorization = req.headers.authorization || '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ success: false, message: 'กรุณาเข้าสู่ระบบ' });
  }

  if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET is not configured');
    return res.status(500).json({ success: false, message: 'ระบบยืนยันตัวตนยังไม่พร้อมใช้งาน' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const [users] = await db.query(
      'SELECT id, email, full_name, role, account_status FROM users WHERE id = ?',
      [payload.id]
    );
    const user = users[0];

    if (!user || user.account_status !== 'active') {
      return res.status(401).json({ success: false, message: 'บัญชีนี้ไม่สามารถใช้งานได้' });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });
    }
    console.error('Error in requireAuth:', error);
    res.status(500).json({ success: false, message: 'ตรวจสอบบัญชีไม่สำเร็จ' });
  }
};

// ตรวจสอบสิทธิ์ว่าเป็นเจ้าของหอพัก (Seller Role Authorization)
const requireOwnerRole = (req, res, next) => {
  if (!req.user || req.user.role !== 'seller') {
    return res.status(403).json({
      success: false, 
      message: 'Unauthorized access. Owner role required.' 
    });
  }
  next();
};

module.exports = { requireAuth, requireOwnerRole };