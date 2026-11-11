const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const db = require('../Tconfig/db');

async function login(req, res, ownerOnly) {
  const body = req.body || {};
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: 'กรุณากรอกอีเมลและรหัสผ่าน'
    });
  }
  if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET is not configured');
    return res.status(500).json({
      success: false,
      message: 'ระบบยืนยันตัวตนยังไม่พร้อมใช้งาน'
    });
  }

  try {
    const [users] = await db.query(
      `SELECT id, email, password, full_name, role, account_status
       FROM users WHERE email = ? LIMIT 1`,
      [email]
    );
    const user = users[0];
    if (!user || (ownerOnly && user.role !== 'seller')) {
      return res.status(401).json({
        success: false,
        message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
      });
    }

    let passwordMatches = false;
    try {
      passwordMatches = await argon2.verify(user.password, password);
    } catch (error) {
      console.error('Invalid password hash for account:', error);
    }
    if (!passwordMatches) {
      return res.status(401).json({
        success: false,
        message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
      });
    }
    if (user.account_status !== 'active') {
      return res.status(403).json({
        success: false,
        message: 'บัญชีนี้ถูกระงับการใช้งาน'
      });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '1d' }
    );
    res.json({
      success: true,
      token,
      id: user.id,
      email: user.email,
      role: user.role,
      full_name: user.full_name
    });
  } catch (error) {
    console.error('Error in login:', error);
    res.status(500).json({ success: false, message: 'เข้าสู่ระบบไม่สำเร็จ' });
  }
}

exports.login = (req, res) => login(req, res, false);
exports.loginOwner = (req, res) => login(req, res, true);
