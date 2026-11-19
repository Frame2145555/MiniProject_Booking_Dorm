const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const ownerController = require('../controllers/ownerController');
const db = require('../config/db');
const { requireAuth, requireOwnerRole } = require('../middleware/auth');

router.post('/login', authController.loginOwner);
router.use(requireAuth, requireOwnerRole);

router.get('/kyc', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT k.id, k.id_card_number AS idCardNumber,
             k.status, k.submitted_at AS submittedAt, k.rejection_reason AS rejectionReason,
             (SELECT COUNT(*) FROM kyc_documents d WHERE d.kyc_request_id = k.id) AS documentCount
        FROM kyc_requests k WHERE k.seller_id = ? ORDER BY k.id DESC LIMIT 1`, [req.user.id]);
    res.json({ success: true, data: rows[0] || null });
  } catch (error) {
    console.error('[KYC ERROR] load failed', {
      ownerId: req.user.id, code: error.code, errno: error.errno,
      sqlState: error.sqlState, message: error.message,
    });
    res.status(500).json({ error: 'KYC server error', debugId: `kyc-get-${Date.now()}-${req.user.id}` });
  }
});

router.post('/kyc', async (req, res) => {
  const debugId = `kyc-${Date.now()}-${req.user.id}`;
  let stage = 'received';
  const idCardNumber = String(req.body?.idCardNumber || '').replace(/[- ]/g, '');
  const idCardImage = req.body?.idCardImage;
  const selfieImage = req.body?.selfieImage;
  const fullName = String(req.body?.fullName || '').trim();
  // รับเบอร์ที่มีขีด/เว้นวรรคได้ เช่น 081-234-5678 -> 0812345678
  const phone = String(req.body?.phone || '').replace(/[-\s()]/g, '');
  const email = String(req.body?.email || '').trim().toLowerCase();

  console.log('[KYC DEBUG] submit received', {
    debugId,
    ownerId: req.user.id,
    hasIdCardImage: typeof idCardImage === 'string',
    idCardImageLength: typeof idCardImage === 'string' ? idCardImage.length : 0,
    hasSelfieImage: typeof selfieImage === 'string',
    selfieImageLength: typeof selfieImage === 'string' ? selfieImage.length : 0,
  });

  // แจ้งทีละช่อง ผู้ใช้จะได้รู้ว่าต้องแก้ตรงไหน
  if (!fullName) {
    return res.status(400).json({ error: 'กรุณากรอกชื่อจริงและนามสกุล', debugId });
  }
  if (!/^0\d{8,9}$/.test(phone)) {
    return res.status(400).json({ error: 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 0 และมี 9-10 หลัก เช่น 0812345678', debugId });
  }
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    return res.status(400).json({ error: 'รูปแบบอีเมลไม่ถูกต้อง', debugId });
  }
  if (!/^\d{13}$/.test(idCardNumber)) {
    return res.status(400).json({ error: 'เลขประจำตัวประชาชนต้องมี 13 หลัก', debugId });
  }
  if (typeof idCardImage !== 'string' || !idCardImage.startsWith('data:image/')) {
    return res.status(400).json({ error: 'กรุณาอัปโหลดรูปบัตรประชาชน', debugId });
  }
  if (idCardImage.length > 8_000_000 || (typeof selfieImage === 'string' && selfieImage.length > 8_000_000)) {
    return res.status(413).json({ error: 'ไฟล์มีขนาดใหญ่เกินไป', debugId });
  }

  try {
    stage = 'find_pending_request';
    const [[current]] = await db.query(
      'SELECT id, status FROM kyc_requests WHERE seller_id = ? ORDER BY id DESC LIMIT 1',
      [req.user.id],
    );
    console.log('[KYC DEBUG] previous request checked', {
      debugId, previousId: current?.id ?? null, previousStatus: current?.status ?? null,
    });
    if (current?.status === 'pending') {
      return res.status(409).json({ error: 'มีคำขอ KYC ที่กำลังตรวจสอบอยู่แล้ว', debugId });
    }

    stage = 'insert_kyc_request';
    const [created] = await db.query(
      'INSERT INTO kyc_requests (seller_id, id_card_number) VALUES (?, ?)',
      [req.user.id, idCardNumber],
    );
    console.log('[KYC DEBUG] request inserted', { debugId, requestId: created.insertId });

    stage = 'update_owner_profile';
    await db.query(
      'UPDATE users SET full_name = ?, phone = ?, email = ? WHERE id = ?',
      [fullName.slice(0, 160), phone, email.slice(0, 190), req.user.id],
    );

    stage = 'insert_id_card';
    const watermark = 'ใช้สำหรับตรวจสอบสิทธิ์ DORM MASTER เท่านั้น';
    await db.query(
      "INSERT INTO kyc_documents (kyc_request_id, document_type, private_storage_key, file_data, watermark_text) VALUES (?, 'id_card', '', ?, ?)",
      [created.insertId, idCardImage, watermark],
    );
    if (typeof selfieImage === 'string' && selfieImage.startsWith('data:image/')) {
      stage = 'insert_selfie';
      await db.query(
        "INSERT INTO kyc_documents (kyc_request_id, document_type, private_storage_key, file_data, watermark_text) VALUES (?, 'selfie_with_id', '', ?, ?)",
        [created.insertId, selfieImage, watermark],
      );
    }
    console.log('[KYC DEBUG] submit completed', { debugId, requestId: created.insertId });
    res.status(201).json({ success: true, data: { id: created.insertId, status: 'pending', watermarkText: watermark } });
  } catch (error) {
    console.error('[KYC ERROR] submit failed', {
      debugId, stage, code: error.code, errno: error.errno, sqlState: error.sqlState, message: error.message,
    });
    res.status(500).json({ error: 'KYC server error', debugId });
  }
});

router.get('/dashboard/stats', ownerController.getDashboardStats);
router.get('/dorms', ownerController.getOwnerDorms);
router.post('/dorms', ownerController.createDorm);
router.put('/dorms/:id', ownerController.updateDorm);
router.patch('/dorms/:id/visibility', ownerController.toggleDormVisibility);
router.post('/dorms/:dormId/rooms', ownerController.addRoom);
router.patch('/rooms/:roomId/status', ownerController.updateRoomStatus);
router.get('/visit-requests', ownerController.getVisitRequests);

module.exports = router;
