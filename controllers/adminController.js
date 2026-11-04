const db = require('../config/db');

// 1. BUILDINGS
exports.getAllBuildings = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM buildings');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createBuilding = async (req, res) => {
  const { code, name, total_floors, description } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO buildings (code, name, total_floors, description) VALUES (?, ?, ?, ?)',
      [code, name, total_floors, description]
    );
    res.status(201).json({ message: 'สร้างตึกสำเร็จ', building_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateBuilding = async (req, res) => {
  const { id } = req.params;
  const { code, name, total_floors, description } = req.body;
  try {
    await db.query(
      'UPDATE buildings SET code=?, name=?, total_floors=?, description=? WHERE building_id=?',
      [code, name, total_floors, description, id]
    );
    res.json({ message: 'แก้ไขข้อมูลตึกสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteBuilding = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM buildings WHERE building_id=?', [id]);
    res.json({ message: 'ลบตึกสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 2. ROOM TYPES
exports.getAllRoomTypes = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM room_types');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createRoomType = async (req, res) => {
  const { name, capacity, description } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO room_types (name, capacity, description) VALUES (?, ?, ?)',
      [name, capacity, description]
    );
    res.status(201).json({ message: 'สร้างประเภทห้องสำเร็จ', room_type_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateRoomType = async (req, res) => {
  const { id } = req.params;
  const { name, capacity, description } = req.body;
  try {
    await db.query(
      'UPDATE room_types SET name=?, capacity=?, description=? WHERE room_type_id=?',
      [name, capacity, description, id]
    );
    res.json({ message: 'แก้ไขประเภทห้องสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteRoomType = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM room_types WHERE room_type_id=?', [id]);
    res.json({ message: 'ลบประเภทห้องสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 3. AMENITIES
exports.getAllAmenities = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM amenities');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createAmenity = async (req, res) => {
  const { name, icon } = req.body;
  try {
    const [result] = await db.query('INSERT INTO amenities (name, icon) VALUES (?, ?)', [name, icon]);
    res.status(201).json({ message: 'เพิ่มสิ่งอำนวยความสะดวกสำเร็จ', amenity_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateAmenity = async (req, res) => {
  const { id } = req.params;
  const { name, icon } = req.body;
  try {
    await db.query('UPDATE amenities SET name=?, icon=? WHERE amenity_id=?', [name, icon, id]);
    res.json({ message: 'แก้ไขสิ่งอำนวยความสะดวกสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteAmenity = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM amenities WHERE amenity_id=?', [id]);
    res.json({ message: 'ลบสิ่งอำนวยความสะดวกสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 4. ROOMS & ROOM AMENITIES
exports.getAllRooms = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT r.*, b.name AS building_name, rt.name AS room_type_name 
      FROM rooms r
      JOIN buildings b ON r.building_id = b.building_id
      JOIN room_types rt ON r.room_type_id = rt.room_type_id
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createRoom = async (req, res) => {
  const { building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active } = req.body;
  try {
    const [result] = await db.query(
      `INSERT INTO rooms (building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active ?? true]
    );
    res.status(201).json({ message: 'เพิ่มห้องสำเร็จ', room_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateRoom = async (req, res) => {
  const { id } = req.params;
  const { building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active } = req.body;
  try {
    await db.query(
      `UPDATE rooms SET building_id=?, room_type_id=?, room_number=?, floor=?, price_per_month=?, size_sqft=?, facing=?, grid_x=?, grid_y=?, is_active=? 
       WHERE room_id=?`,
      [building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active, id]
    );
    res.json({ message: 'แก้ไขข้อมูลห้องสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteRoom = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM rooms WHERE room_id=?', [id]);
    res.json({ message: 'ลบห้องสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.setRoomAmenities = async (req, res) => {
  const { id } = req.params;
  const { amenity_ids } = req.body;
  try {
    await db.query('DELETE FROM room_amenities WHERE room_id=?', [id]);
    if (amenity_ids && amenity_ids.length > 0) {
      const values = amenity_ids.map(aId => [id, aId]);
      await db.query('INSERT INTO room_amenities (room_id, amenity_id) VALUES ?', [values]);
    }
    res.json({ message: 'อัปเดตสิ่งอำนวยความสะดวกประจำห้องเรียบร้อย' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 5. ROOM IMAGES
exports.addRoomImage = async (req, res) => {
  const { room_id, image_url, sort_order } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO room_images (room_id, image_url, sort_order) VALUES (?, ?, ?)',
      [room_id, image_url, sort_order || 0]
    );
    res.status(201).json({ message: 'เพิ่มรูปภาพห้องสำเร็จ', image_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteRoomImage = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM room_images WHERE image_id=?', [id]);
    res.json({ message: 'ลบรูปภาพห้องสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 6. SEMESTERS
exports.getAllSemesters = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM semesters');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createSemester = async (req, res) => {
  const { name, start_date, end_date, is_open } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO semesters (name, start_date, end_date, is_open) VALUES (?, ?, ?, ?)',
      [name, start_date, end_date, is_open ?? true]
    );
    res.status(201).json({ message: 'สร้างภาคเรียนสำเร็จ', semester_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateSemester = async (req, res) => {
  const { id } = req.params;
  const { name, start_date, end_date, is_open } = req.body;
  try {
    await db.query(
      'UPDATE semesters SET name=?, start_date=?, end_date=?, is_open=? WHERE semester_id=?',
      [name, start_date, end_date, is_open, id]
    );
    res.json({ message: 'แก้ไขภาคเรียนสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteSemester = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM semesters WHERE semester_id=?', [id]);
    res.json({ message: 'ลบภาคเรียนสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 7. ADD-ONS
exports.getAllAddons = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM addons');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createAddon = async (req, res) => {
  const { name, description, price_per_month, is_active } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO addons (name, description, price_per_month, is_active) VALUES (?, ?, ?, ?)',
      [name, description, price_per_month, is_active ?? true]
    );
    res.status(201).json({ message: 'สร้างบริการเสริมสำเร็จ', addon_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateAddon = async (req, res) => {
  const { id } = req.params;
  const { name, description, price_per_month, is_active } = req.body;
  try {
    await db.query(
      'UPDATE addons SET name=?, description=?, price_per_month=?, is_active=? WHERE addon_id=?',
      [name, description, price_per_month, is_active, id]
    );
    res.json({ message: 'แก้ไขบริการเสริมสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteAddon = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM addons WHERE addon_id=?', [id]);
    res.json({ message: 'ลบบริการเสริมสำเร็จ' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// 8. USERS (SUSPEND / ACTIVATE)
exports.getAllUsers = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT user_id, email, full_name, phone, user_type, role, student_id, faculty, is_active FROM users');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.toggleUserStatus = async (req, res) => {
  const { id } = req.params;
  const { is_active } = req.body;
  try {
    await db.query('UPDATE users SET is_active=? WHERE user_id=?', [is_active, id]);
    res.json({ message: `เปลี่ยนสถานะผู้ใช้งานเป็น ${is_active ? 'ใช้งานได้' : 'ระงับการใช้งาน'} เรียบร้อย` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
