const db = require('../Tconfig/db');

// 1. ดึงข้อมูลสถิติภาพรวม Dashboard
exports.getDashboardStats = async (req, res) => {
  try {
    const ownerId = req.user.id;

    const [userRows] = await db.query(
      'SELECT account_status FROM users WHERE id = ?',
      [ownerId]
    );

    const [statsRows] = await db.query(
      `SELECT 
        COUNT(DISTINCT d.id) AS total_dorms,
        SUM(CASE WHEN d.approval_status = 'pending' THEN 1 ELSE 0 END) AS pending_dorms_count,
        SUM(CASE WHEN d.approval_status = 'approved' THEN 1 ELSE 0 END) AS active_dorms_count,
        COUNT(v.id) AS total_views
       FROM dorms d
       LEFT JOIN dorm_view_events v ON d.id = v.dorm_id
       WHERE d.owner_id = ?`,
      [ownerId]
    );

    const [roomStats] = await db.query(
      `SELECT 
        COUNT(r.id) AS total_rooms,
        SUM(CASE WHEN r.status = 'available' THEN 1 ELSE 0 END) AS available_rooms,
        SUM(CASE WHEN r.status = 'occupied' THEN 1 ELSE 0 END) AS occupied_rooms,
        SUM(CASE WHEN r.status = 'maintenance' THEN 1 ELSE 0 END) AS maintenance_rooms
       FROM rooms r
       JOIN dorms d ON r.dorm_id = d.id
       WHERE d.owner_id = ?`,
      [ownerId]
    );

    res.json({
      success: true,
      data: {
        account_status: userRows[0]?.account_status || 'active',
        total_views: statsRows[0].total_views || 0,
        pending_dorms_count: statsRows[0].pending_dorms_count || 0,
        active_dorms_count: statsRows[0].active_dorms_count || 0,
        total_dorms: statsRows[0].total_dorms || 0,
        total_rooms: roomStats[0].total_rooms || 0,
        available_rooms: roomStats[0].available_rooms || 0,
        occupied_rooms: roomStats[0].occupied_rooms || 0,
        maintenance_rooms: roomStats[0].maintenance_rooms || 0,
        subscription: {
          is_subscribed: true,
          expires_at: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000).toISOString()
        }
      }
    });
  } catch (err) {
    console.error('Error in getDashboardStats:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 2. ดึงรายการหอพักทั้งหมดของเจ้าของหอ
exports.getOwnerDorms = async (req, res) => {
  try {
    const ownerId = req.user.id;

    const [dorms] = await db.query(
      `SELECT 
        d.id,
        d.owner_id AS sellerId,
        d.name AS title,
        d.address AS location,
        d.phone,
        d.description,
        d.price_min_month AS priceMin,
        d.price_max_month AS priceMax,
        d.cover_image_url AS imageUrl,
        d.latitude,
        d.longitude,
        d.listing_status,
        d.approval_status,
        COUNT(DISTINCT v.id) AS viewCount
       FROM dorms d
       LEFT JOIN dorm_view_events v ON d.id = v.dorm_id
       WHERE d.owner_id = ?
       GROUP BY d.id
       ORDER BY d.created_at DESC`,
      [ownerId]
    );

    for (let dorm of dorms) {
      const [amenities] = await db.query(
        `SELECT a.name FROM amenities a
         JOIN dorm_amenities da ON a.id = da.amenity_id
         WHERE da.dorm_id = ?`,
        [dorm.id]
      );
      dorm.amenities = amenities.map(a => a.name);

      const [rooms] = await db.query(
        `SELECT 
          id,
          room_number AS roomNumber,
          room_type AS roomType,
          price_per_month AS price,
          status
         FROM rooms WHERE dorm_id = ? ORDER BY room_number ASC`,
        [dorm.id]
      );
      dorm.roomsList = rooms;
    }

    res.json({ success: true, count: dorms.length, data: dorms });
  } catch (err) {
    console.error('Error in getOwnerDorms:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 3. เพิ่มประกาศหอพักใหม่พร้อมเอกสารแนบ
exports.createDorm = async (req, res) => {
  const connection = await db.getConnection();
  try {
    const {
      title,
      location,
      description,
      phone,
      priceMin,
      priceMax,
      latitude,
      longitude,
      imageUrl,
      amenities = [],
      documents = []
    } = req.body;

    if (!title || !location || !phone || !priceMin || !priceMax) {
      return res.status(400).json({ success: false, message: 'กรุณากรอกข้อมูลสำคัญให้ครบถ้วน' });
    }

    await connection.beginTransaction();

    const [dormResult] = await connection.query(
      `INSERT INTO dorms 
        (owner_id, name, address, description, phone, price_min_month, price_max_month, latitude, longitude, cover_image_url, listing_status, approval_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 'pending')`,
      [req.user.id, title, location, description, phone, priceMin, priceMax, latitude || null, longitude || null, imageUrl || '']
    );

    const dormId = dormResult.insertId;

    if (amenities.length > 0) {
      const [amenityRows] = await connection.query(
        `SELECT id, name FROM amenities WHERE name IN (?)`,
        [amenities]
      );
      for (let am of amenityRows) {
        await connection.query(
          `INSERT INTO dorm_amenities (dorm_id, amenity_id) VALUES (?, ?)`,
          [dormId, am.id]
        );
      }
    }

    for (let doc of documents) {
      await connection.query(
        `INSERT INTO dorm_documents (dorm_id, document_type, display_name, private_storage_key)
         VALUES (?, ?, ?, ?)`,
        [dormId, doc.type || 'proof_of_right', doc.name || 'document', doc.key || 'path/to/storage']
      );
    }

    await connection.commit();

    res.status(201).json({
      success: true,
      message: 'ส่งข้อมูลและเอกสารให้แอดมินตรวจแล้ว',
      data: { dormId, approvalStatus: 'pending' }
    });
  } catch (err) {
    await connection.rollback();
    console.error('Error in createDorm:', err);
    res.status(500).json({ success: false, message: 'Failed to create dormitory' });
  } finally {
    connection.release();
  }
};

// 4. แก้ไขข้อมูลประกาศหอพัก
exports.updateDorm = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, location, phone, description, priceMin, priceMax, imageUrl } = req.body;

    const [result] = await db.query(
      `UPDATE dorms 
       SET name = ?, address = ?, phone = ?, description = ?, price_min_month = ?, price_max_month = ?, cover_image_url = ?
       WHERE id = ? AND owner_id = ?`,
      [title, location, phone, description, priceMin, priceMax, imageUrl, id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Dormitory not found or unauthorized' });
    }

    res.json({ success: true, message: 'อัปเดตข้อมูลหอพักเรียบร้อยแล้ว' });
  } catch (err) {
    console.error('Error in updateDorm:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 5. เปิด-ปิดการแสดงผลประกาศหอพักชั่วคราว
exports.toggleDormVisibility = async (req, res) => {
  try {
    const { id } = req.params;
    const { isClosed } = req.body;
    const newStatus = isClosed ? 'temporarily_closed' : 'active';

    const [result] = await db.query(
      `UPDATE dorms SET listing_status = ? WHERE id = ? AND owner_id = ?`,
      [newStatus, id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Dormitory not found or unauthorized' });
    }

    res.json({ success: true, message: `เปลี่ยนสถานะเป็น ${newStatus} เรียบร้อยแล้ว` });
  } catch (err) {
    console.error('Error in toggleDormVisibility:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 6. เพิ่มห้องพักใหม่ในหอพัก
exports.addRoom = async (req, res) => {
  try {
    const { dormId } = req.params;
    const { roomNumber, roomType, price, status = 'available', floor = 1 } = req.body;

    const [dormCheck] = await db.query('SELECT id FROM dorms WHERE id = ? AND owner_id = ?', [dormId, req.user.id]);
    if (dormCheck.length === 0) {
      return res.status(404).json({ success: false, message: 'Dormitory not found or unauthorized' });
    }

    const statusMap = { 'ว่าง': 'available', 'มีผู้เช่า': 'occupied', 'ปรับปรุง': 'maintenance' };
    const dbStatus = statusMap[status] || status;

    const [result] = await db.query(
      `INSERT INTO rooms (dorm_id, room_number, room_type, price_per_month, floor, status)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [dormId, roomNumber, roomType, price, floor, dbStatus]
    );

    res.status(201).json({
      success: true,
      message: `เพิ่มห้อง ${roomNumber} เรียบร้อยแล้ว`,
      data: { id: result.insertId, roomNumber, roomType, price, status }
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, message: 'เลขห้องนี้มีอยู่แล้วในหอพักนี้' });
    }
    console.error('Error in addRoom:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 7. อัปเดตสถานะห้องพัก
exports.updateRoomStatus = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { status } = req.body;

    const statusMap = { 'ว่าง': 'available', 'มีผู้เช่า': 'occupied', 'ปรับปรุง': 'maintenance' };
    const dbStatus = statusMap[status] || status;

    const [result] = await db.query(
      `UPDATE rooms r
       JOIN dorms d ON r.dorm_id = d.id
       SET r.status = ?
       WHERE r.id = ? AND d.owner_id = ?`,
      [dbStatus, roomId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Room not found or unauthorized' });
    }

    res.json({ success: true, message: `อัปเดตสถานะห้องเรียบร้อยแล้ว` });
  } catch (err) {
    console.error('Error in updateRoomStatus:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// 8. ดึงรายการคำขอนัดดูห้องพัก
exports.getVisitRequests = async (req, res) => {
  try {
    const [requests] = await db.query(
      `SELECT 
        vr.id,
        d.name AS dormName,
        r.room_number AS roomNumber,
        u.full_name AS tenantName,
        u.phone AS tenantPhone,
        vr.requested_at AS requestedAt,
        vr.status,
        vr.tenant_note AS tenantNote,
        vr.owner_note AS ownerNote
       FROM visit_requests vr
       JOIN dorms d ON vr.dorm_id = d.id
       JOIN users u ON vr.tenant_id = u.id
       LEFT JOIN rooms r ON vr.room_id = r.id
       WHERE d.owner_id = ?
       ORDER BY vr.created_at DESC`,
      [req.user.id]
    );

    res.json({ success: true, count: requests.length, data: requests });
  } catch (err) {
    console.error('Error in getVisitRequests:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};