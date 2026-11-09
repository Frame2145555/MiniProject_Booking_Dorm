// ตรวจสอบตัวตนผู้ใช้งาน (Authentication)
const requireAuth = (req, res, next) => {
  // จำลองข้อมูล User (ในใช้งานจริงใช้ JWT Verify Token)
  req.user = { id: 1, role: 'seller', email: 'somchai@email.com' };
  next();
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