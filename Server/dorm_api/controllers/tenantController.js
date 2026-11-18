const db = require('../config/db');

// 1. ค้นหาและดึงรายการหอพัก (ค้นหาตามคำขวัญ/ชื่อ/ทำเล/ช่วงราคา/สิ่งอำนวยความสะดวก)
exports.getDorms = async (req, res) => {
  try {
    const { search, minPrice, maxPrice, amenities, favoritesOnly } = req.query;
    const tenantId = req.user?.id || null;

    let query = `
      SELECT 
        d.id,
        d.name AS title,
        d.address AS location,
        d.phone,
        d.price_min_month AS priceMin,
        d.price_max_month AS priceMax,
        d.cover_image_url AS imageUrl,
        d.latitude,
        d.longitude,
        (SELECT ROUND(AVG(rating), 1) FROM dorm_reviews
          WHERE dorm_id = d.id AND status = 'visible') AS rating,
        (SELECT COUNT(*) FROM dorm_reviews
          WHERE dorm_id = d.id AND status = 'visible') AS reviewCount,
        EXISTS (
          SELECT 1 FROM kyc_requests k
          WHERE k.seller_id = d.owner_id AND k.status = 'approved'
        ) AS verified_owner,
        COALESCE(fav.is_fav, 0) AS isFavorite
      FROM dorms d
      LEFT JOIN (
        SELECT dorm_id, 1 AS is_fav 
        FROM favorites 
        WHERE tenant_id = ?
      ) fav ON d.id = fav.dorm_id
      WHERE d.listing_status = 'active' 
        AND d.approval_status = 'approved'
    `;
    const params = [tenantId];

    // Filter: คำค้นหา (ชื่อหอพัก หรือ ทำเล)
    if (search) {
      query += ` AND (LOWER(d.name) LIKE ? OR LOWER(d.address) LIKE ?)`;
      params.push(`%${search.toLowerCase()}%`, `%${search.toLowerCase()}%`);
    }

    // Filter: ช่วงราคา
    if (minPrice) {
      query += ` AND d.price_max_month >= ?`;
      params.push(Number(minPrice));
    }
    if (maxPrice) {
      query += ` AND d.price_min_month <= ?`;
      params.push(Number(maxPrice));
    }

    // Filter: เฉพาะรายการโปรด
    if (favoritesOnly === 'true' && tenantId) {
      query += ` AND fav.is_fav = 1`;
    }

    query += ` ORDER BY d.id DESC`;

    const [dorms] = await db.query(query, params);

    // ดึงสิ่งอำนวยความสะดวก (Tags) ของแต่ละหอพัก
    for (let dorm of dorms) {
      const [amenityRows] = await db.query(
        `SELECT a.name FROM amenities a
         JOIN dorm_amenities da ON a.id = da.amenity_id
         WHERE da.dorm_id = ?`,
        [dorm.id]
      );
      dorm.tags = amenityRows.map(a => a.name);
    }

    // Filter: สิ่งอำนวยความสะดวก (ถ้ามีการระบุใน Query Params)
    let results = dorms;
    if (amenities) {
      const amenityList = Array.isArray(amenities) ? amenities : amenities.split(',');
      results = dorms.filter(dorm =>
        amenityList.every(reqAm => dorm.tags.includes(reqAm))
      );
    }

    res.json({ success: true, count: results.length, data: results });
  } catch (err) {
    console.error('Error in getDorms:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 2. ดึงรายละเอียดหอพักเชิงลึก (DormDetailView) + บันทึกยอดเข้าชม (View Event)
exports.getDormById = async (req, res) => {
  try {
    const { id } = req.params;
    const tenantId = req.user?.id || null;

    // 2.1 บันทึกสถิติการเข้าชม (Record View Event)
    await db.query(
      `INSERT INTO dorm_view_events (dorm_id, viewer_id) VALUES (?, ?)`,
      [id, tenantId]
    );

    // 2.2 ดึงข้อมูลหอพัก
    const [dorms] = await db.query(
      `SELECT 
        d.id,
        d.name AS title,
        d.address AS location,
        d.description,
        d.phone,
        d.price_min_month AS priceMin,
        d.price_max_month AS priceMax,
        d.cover_image_url AS imageUrl,
        d.latitude,
        d.longitude,
        (SELECT ROUND(AVG(rating), 1) FROM dorm_reviews
          WHERE dorm_id = d.id AND status = 'visible') AS rating,
        (SELECT COUNT(*) FROM dorm_reviews
          WHERE dorm_id = d.id AND status = 'visible') AS reviewCount,
        d.listing_status,
        d.approval_status,
        EXISTS (
          SELECT 1 FROM kyc_requests k
          WHERE k.seller_id = d.owner_id AND k.status = 'approved'
        ) AS verified_owner,
        COALESCE(fav.is_fav, 0) AS isFavorite
       FROM dorms d
       LEFT JOIN (
         SELECT dorm_id, 1 AS is_fav FROM favorites WHERE tenant_id = ?
       ) fav ON d.id = fav.dorm_id
       WHERE d.id = ? AND d.listing_status = 'active' AND d.approval_status = 'approved'`,
      [tenantId, id]
    );

    if (dorms.length === 0) {
      return res.status(404).json({ success: false, message: 'ไม่พบหอพัก หรือประกาศถูกปิดใช้งาน' });
    }

    const dorm = dorms[0];

    // 2.3 ดึงสิ่งอำนวยความสะดวก
    const [amenityRows] = await db.query(
      `SELECT a.name FROM amenities a
       JOIN dorm_amenities da ON a.id = da.amenity_id
       WHERE da.dorm_id = ?`,
      [dorm.id]
    );
    dorm.tags = amenityRows.map(a => a.name);

    // 2.4 ดึงห้องพักที่ว่างและข้อมูลห้องทั้งหมด
    const [rooms] = await db.query(
      `SELECT id, room_number AS roomNumber, room_type AS roomType, price_per_month AS price, status
       FROM rooms WHERE dorm_id = ? ORDER BY room_number ASC`,
      [dorm.id]
    );
    dorm.rooms = rooms;

    // 2.5 อัตราค่าสาธารณูปโภค (Utilities)
    dorm.utilities = {
      electricity: '7 บาท / หน่วย',
      water: '18 บาท / หน่วย (ขั้นต่ำ 100 บาท)'
    };

    res.json({ success: true, data: dorm });
  } catch (err) {
    console.error('Error in getDormById:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 2.5 ผู้เช่ารายงานประกาศหอที่มีปัญหา
exports.createDormReport = async (req, res) => {
  const dormId = Number(req.params.dormId);
  const tenantId = req.user?.id;
  const { category, description } = req.body || {};
  const categories = ['misleading', 'safety', 'pricing', 'inappropriate', 'unavailable', 'other'];
  const details = typeof description === 'string' ? description.trim() : '';

  if (req.user?.role !== 'tenant') {
    return res.status(403).json({ success: false, message: 'เฉพาะบัญชีผู้เช่าส่งรายงานได้' });
  }
  if (!Number.isSafeInteger(dormId) || dormId <= 0) {
    return res.status(400).json({ success: false, message: 'เลขหอพักไม่ถูกต้อง' });
  }
  if (!categories.includes(category)) {
    return res.status(400).json({ success: false, message: 'กรุณาเลือกประเภทการรายงาน' });
  }
  if (details.length < 10 || details.length > 1000) {
    return res.status(400).json({ success: false, message: 'รายละเอียดต้องมีความยาว 10 ถึง 1,000 ตัวอักษร' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [dorms] = await connection.query(
      `SELECT id FROM dorms
        WHERE id = ? AND approval_status = 'approved' AND listing_status = 'active'
        FOR UPDATE`,
      [dormId]
    );
    if (!dorms.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'ไม่พบประกาศหอพักนี้' });
    }

    const [existing] = await connection.query(
      `SELECT id FROM user_dorm_reports
        WHERE dorm_id = ? AND reporter_id = ? AND status = 'pending'
        LIMIT 1`,
      [dormId, tenantId]
    );
    if (existing.length) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'คุณส่งรายงานหอนี้และกำลังรอตรวจสอบอยู่แล้ว' });
    }

    const [result] = await connection.query(
      `INSERT INTO user_dorm_reports (dorm_id, reporter_id, category, description)
       VALUES (?, ?, ?, ?)`,
      [dormId, tenantId, category, details]
    );
    await connection.commit();
    res.status(201).json({
      success: true,
      data: { id: result.insertId, dormId, status: 'pending' },
    });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

exports.getDormReviews = async (req, res) => {
  const dormId = Number(req.params.dormId);
  if (!Number.isSafeInteger(dormId) || dormId <= 0) {
    return res.status(400).json({ success: false, message: 'เลขหอพักไม่ถูกต้อง' });
  }
  try {
    const [[dorm]] = await db.query('SELECT id, name FROM dorms WHERE id = ?', [dormId]);
    if (!dorm) {
      return res.status(404).json({ success: false, message: 'ไม่พบหอพักนี้' });
    }

    const [reviews] = await db.query(
      `SELECT r.id, r.dorm_id AS dormId, d.name AS dormName,
              u.full_name AS author, r.rating, r.comment, r.status,
              r.created_at AS createdAt
         FROM dorm_reviews r
         JOIN users u ON u.id = r.reviewer_id
         JOIN dorms d ON d.id = r.dorm_id
        WHERE r.dorm_id = ? AND r.status = 'visible'
        ORDER BY r.created_at DESC, r.id DESC`,
      [dormId]
    );
    const tenantId = req.user?.role === 'tenant' ? req.user.id : null;
    let canReview = false;
    let hasReviewed = false;
    if (tenantId) {
      const [[existing]] = await db.query(
        'SELECT id FROM dorm_reviews WHERE dorm_id = ? AND reviewer_id = ?',
        [dormId, tenantId]
      );
      hasReviewed = Boolean(existing);
      if (!hasReviewed) {
        const [[stay]] = await db.query(
          `SELECT p.id
             FROM booking_payments p
             JOIN bookings b ON b.id = p.booking_id
             JOIN rooms r ON r.id = p.room_id
            WHERE p.dorm_id = ? AND p.tenant_id = ?
              AND p.status = 'completed' AND b.status = 'confirmed'
              AND r.status = 'occupied'
              AND b.starts_at <= CURDATE() AND b.ends_at >= CURDATE()
            LIMIT 1`,
          [dormId, tenantId]
        );
        canReview = Boolean(stay);
      }
    }
    res.json({
      success: true,
      count: reviews.length,
      data: { reviews, canReview, hasReviewed },
    });
  } catch (error) {
    console.error('Error in getDormReviews:', error);
    res.status(500).json({ success: false, message: 'ดึงรีวิวไม่สำเร็จ' });
  }
};

exports.createDormReview = async (req, res) => {
  const dormId = Number(req.params.dormId);
  const tenantId = req.user?.id;
  const rating = req.body?.rating;
  const comment = typeof req.body?.comment === 'string' ? req.body.comment.trim() : '';

  if (req.user?.role !== 'tenant') {
    return res.status(403).json({ success: false, message: 'เฉพาะผู้เช่าที่กำลังพักอยู่ในหอรีวิวได้' });
  }
  if (!Number.isSafeInteger(dormId) || dormId <= 0) {
    return res.status(400).json({ success: false, message: 'เลขหอพักไม่ถูกต้อง' });
  }
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ success: false, message: 'คะแนนต้องอยู่ระหว่าง 1 ถึง 5 ดาว' });
  }
  if (comment.length < 10 || comment.length > 1000) {
    return res.status(400).json({ success: false, message: 'รีวิวต้องมีความยาว 10 ถึง 1,000 ตัวอักษร' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [[stay]] = await connection.query(
      `SELECT p.id
         FROM booking_payments p
         JOIN bookings b ON b.id = p.booking_id
         JOIN rooms r ON r.id = p.room_id
        WHERE p.dorm_id = ? AND p.tenant_id = ?
          AND p.status = 'completed' AND b.status = 'confirmed'
          AND r.status = 'occupied'
          AND b.starts_at <= CURDATE() AND b.ends_at >= CURDATE()
        LIMIT 1
        FOR UPDATE`,
      [dormId, tenantId]
    );
    if (!stay) {
      await connection.rollback();
      return res.status(403).json({ success: false, message: 'รีวิวได้เฉพาะผู้เช่าที่กำลังพักอยู่ในหอนี้' });
    }

    const [[existing]] = await connection.query(
      'SELECT id FROM dorm_reviews WHERE dorm_id = ? AND reviewer_id = ?',
      [dormId, tenantId]
    );
    if (existing) {
      await connection.rollback();
      return res.status(409).json({ success: false, message: 'คุณรีวิวหอนี้ไปแล้ว' });
    }

    const [result] = await connection.query(
      `INSERT INTO dorm_reviews (dorm_id, reviewer_id, rating, comment)
       VALUES (?, ?, ?, ?)`,
      [dormId, tenantId, rating, comment]
    );
    await connection.commit();
    res.status(201).json({
      success: true,
      data: { id: result.insertId, dormId, rating, comment, status: 'visible' },
    });
  } catch (error) {
    await connection.rollback();
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ success: false, message: 'คุณรีวิวหอนี้ไปแล้ว' });
    }
    throw error;
  } finally {
    connection.release();
  }
};

exports.getNotifications = async (req, res) => {
  if (req.user?.role !== 'tenant') {
    return res.status(403).json({ success: false, message: 'เฉพาะบัญชีผู้เช่าดูการแจ้งเตือนได้' });
  }
  try {
    const [notifications] = await db.query(
      `SELECT id, type, title, message, related_report_id AS relatedId,
              is_read AS isRead, created_at AS createdAt
         FROM user_notifications
        WHERE user_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT 100`,
      [req.user.id]
    );
    res.json({ success: true, count: notifications.length, data: notifications });
  } catch (error) {
    console.error('Error in getNotifications:', error);
    res.status(500).json({ success: false, message: 'ดึงการแจ้งเตือนไม่สำเร็จ' });
  }
};

exports.markNotificationsRead = async (req, res) => {
  if (req.user?.role !== 'tenant') {
    return res.status(403).json({ success: false, message: 'เฉพาะบัญชีผู้เช่าแก้ไขการแจ้งเตือนได้' });
  }
  try {
    const [result] = await db.query(
      `UPDATE user_notifications
          SET is_read = 1, read_at = COALESCE(read_at, NOW())
        WHERE user_id = ? AND is_read = 0`,
      [req.user.id]
    );
    res.json({ success: true, markedRead: result.affectedRows });
  } catch (error) {
    console.error('Error in markNotificationsRead:', error);
    res.status(500).json({ success: false, message: 'อัปเดตการแจ้งเตือนไม่สำเร็จ' });
  }
};

// 3. กดบันทึก / ยกเลิก รายการโปรด (Toggle Favorite)
exports.toggleFavorite = async (req, res) => {
  try {
    const { dormId } = req.body;
    const tenantId = req.user.id;

    const [existing] = await db.query(
      `SELECT * FROM favorites WHERE tenant_id = ? AND dorm_id = ?`,
      [tenantId, dormId]
    );

    if (existing.length > 0) {
      // มีอยู่แล้ว -> ลบออก
      await db.query(
        `DELETE FROM favorites WHERE tenant_id = ? AND dorm_id = ?`,
        [tenantId, dormId]
      );
      return res.json({ success: true, isFavorite: false, message: 'นำออกจากรายการโปรดแล้ว' });
    } else {
      // ยังไม่มี -> เพิ่มใหม่
      await db.query(
        `INSERT INTO favorites (tenant_id, dorm_id) VALUES (?, ?)`,
        [tenantId, dormId]
      );
      return res.json({ success: true, isFavorite: true, message: 'บันทึกเป็นรายการโปรดแล้ว' });
    }
  } catch (err) {
    console.error('Error in toggleFavorite:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 4. นัดหมายเข้าดูห้องพัก (Schedule Visit Request)
exports.createVisitRequest = async (req, res) => {
  try {
    const { dormId, roomId, visitAt, tenantNote } = req.body;
    const tenantId = req.user.id;

    if (!dormId || !visitAt) {
      return res.status(400).json({ success: false, message: 'กรุณาระบุหอพักและวันเวลาที่ต้องการนัดหมาย' });
    }

    const [result] = await db.query(
      `INSERT INTO visit_requests (dorm_id, room_id, tenant_id, requested_at, status, tenant_note)
       VALUES (?, ?, ?, ?, 'pending', ?)`,
      [dormId, roomId || null, tenantId, visitAt, tenantNote || '']
    );

    res.status(201).json({
      success: true,
      message: 'ส่งคำขอนัดเข้าดูห้องพักเรียบร้อยแล้ว รอเจ้าของหอพักตอบรับ',
      data: { visitRequestId: result.insertId, status: 'pending' }
    });
  } catch (err) {
    console.error('Error in createVisitRequest:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 5. ส่งคำขอจองห้องพัก (Create Room Booking Request)
exports.createBooking = async (req, res) => {
  try {
    const { roomId, startsAt, endsAt } = req.body;
    const tenantId = req.user.id;

    if (!roomId) {
      return res.status(400).json({ success: false, message: 'กรุณาระบุห้องพักที่ต้องการจอง' });
    }

    // ตรวจสอบว่าห้องยังว่างหรือไม่
    const [rooms] = await db.query(
      `SELECT id, price_per_month, status FROM rooms WHERE id = ?`,
      [roomId]
    );

    if (rooms.length === 0) {
      return res.status(404).json({ success: false, message: 'ไม่พบห้องพักนี้' });
    }

    if (rooms[0].status !== 'available') {
      return res.status(400).json({ success: false, message: 'ห้องพักนี้ไม่ว่างหรืออยู่ระหว่างปรับปรุง' });
    }

    // สร้างรายการจอง
    const [result] = await db.query(
      `INSERT INTO bookings (room_id, tenant_id, status, monthly_price, starts_at, ends_at)
       VALUES (?, ?, 'pending', ?, ?, ?)`,
      [roomId, tenantId, rooms[0].price_per_month, startsAt || null, endsAt || null]
    );

    res.status(201).json({
      success: true,
      message: 'ส่งคำขอจองห้องพักเรียบร้อยแล้ว',
      data: {
        bookingId: result.insertId,
        roomId,
        monthlyPrice: rooms[0].price_per_month,
        status: 'pending'
      }
    });
  } catch (err) {
    console.error('Error in createBooking:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 6. ดึงประวัติการจองและคำขอนัดดูห้องของผู้ใช้ปัจจุบัน
exports.getMyBookingsAndVisits = async (req, res) => {
  try {
    const tenantId = req.user.id;

    // 6.1 รายการจองห้องพัก
    const [bookings] = await db.query(
      `SELECT 
        b.id AS bookingId,
        d.name AS dormName,
        r.room_number AS roomNumber,
        r.room_type AS roomType,
        b.monthly_price AS monthlyPrice,
        b.status,
        b.created_at AS createdAt
       FROM bookings b
       JOIN rooms r ON b.room_id = r.id
       JOIN dorms d ON r.dorm_id = d.id
       WHERE b.tenant_id = ?
       ORDER BY b.created_at DESC`,
      [tenantId]
    );

    // 6.2 รายการนัดดูห้องพัก
    const [visits] = await db.query(
      `SELECT 
        vr.id AS visitId,
        d.name AS dormName,
        d.phone AS ownerPhone,
        r.room_number AS roomNumber,
        vr.requested_at AS requestedAt,
        vr.status,
        vr.owner_note AS ownerNote
       FROM visit_requests vr
       JOIN dorms d ON vr.dorm_id = d.id
       LEFT JOIN rooms r ON vr.room_id = r.id
       WHERE vr.tenant_id = ?
       ORDER BY vr.created_at DESC`,
      [tenantId]
    );

    res.json({
      success: true,
      data: {
        bookings,
        visitRequests: visits
      }
    });
  } catch (err) {
    console.error('Error in getMyBookingsAndVisits:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 7. ยกเลิกการจอง / คำขอนัดหมาย
exports.cancelBooking = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const tenantId = req.user.id;

    const [result] = await db.query(
      `UPDATE bookings 
       SET status = 'cancelled' 
       WHERE id = ? AND tenant_id = ? AND status = 'pending'`,
      [bookingId, tenantId]
    );

    if (result.affectedRows === 0) {
      return res.status(400).json({ success: false, message: 'ไม่พบรายการจอง หรือรายการนี้ไม่สามารถยกเลิกได้' });
    }

    res.json({ success: true, message: 'ยกเลิกคำขอจองห้องพักเรียบร้อยแล้ว' });
  } catch (err) {
    console.error('Error in cancelBooking:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};
