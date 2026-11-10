const db = require('../Tconfig/db');

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
      dorm.rating = 4.7; // คะแนนจำลอง
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
        d.listing_status,
        d.approval_status,
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
    dorm.rating = 4.7;

    res.json({ success: true, data: dorm });
  } catch (err) {
    console.error('Error in getDormById:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
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