const db = require('../config/db');

// --- BUILDINGS ---
exports.getAllBuildings = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM buildings ORDER BY building_id DESC');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createBuilding = async (req, res) => {
  const { name, total_floors, gender_type, description } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO buildings (name, total_floors, gender_type, description) VALUES (?, ?, ?, ?)',
      [name, total_floors, gender_type || 'mixed', description]
    );
    res.status(201).json({ success: true, message: 'Building created successfully', building_id: result.insertId });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

exports.updateBuilding = async (req, res) => {
  const { id } = req.params;
  const { name, total_floors, gender_type, description } = req.body;
  try {
    await db.query(
      'UPDATE buildings SET name=?, total_floors=?, gender_type=?, description=? WHERE building_id=?',
      [name, total_floors, gender_type, description, id]
    );
    res.json({ success: true, message: 'Building updated successfully' });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

exports.deleteBuilding = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM buildings WHERE building_id=?', [id]);
    res.json({ success: true, message: 'Building deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- ROOM TYPES ---
exports.getAllRoomTypes = async (req, res) => {
  try {
    const [types] = await db.query('SELECT * FROM room_types');
    res.json({ success: true, data: types });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createRoomType = async (req, res) => {
  const { name, base_price, room_size, max_capacity, description } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO room_types (name, base_price, room_size, max_capacity, description) VALUES (?, ?, ?, ?, ?)',
      [name, base_price, room_size, max_capacity || 1, description]
    );
    res.status(201).json({ success: true, type_id: result.insertId });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// --- ROOMS ---
exports.getAllRooms = async (req, res) => {
  try {
    const query = `
      SELECT r.*, b.name as building_name, rt.name as room_type_name
      FROM rooms r
      JOIN buildings b ON r.building_id = b.building_id
      JOIN room_types rt ON r.type_id = rt.type_id
      ORDER BY r.building_id, r.room_number
    `;
    const [rooms] = await db.query(query);
    res.json({ success: true, data: rooms });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createRoom = async (req, res) => {
  const { building_id, type_id, room_number, floor, price, status, amenities, image_urls } = req.body;
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    const [roomRes] = await connection.query(
      'INSERT INTO rooms (building_id, type_id, room_number, floor, price, status) VALUES (?, ?, ?, ?, ?, ?)',
      [building_id, type_id, room_number, floor, price, status || 'available']
    );
    const roomId = roomRes.insertId;

    if (amenities && amenities.length > 0) {
      const amenityData = amenities.map(aId => [roomId, aId]);
      await connection.query('INSERT INTO room_amenities (room_id, amenity_id) VALUES ?', [amenityData]);
    }

    if (image_urls && image_urls.length > 0) {
      const imageData = image_urls.map((url, idx) => [roomId, url, idx === 0]);
      await connection.query('INSERT INTO room_images (room_id, image_url, is_primary) VALUES ?', [imageData]);
    }

    await connection.commit();
    res.status(201).json({ success: true, message: 'Room created successfully', room_id: roomId });
  } catch (err) {
    await connection.rollback();
    res.status(400).json({ success: false, error: err.message });
  } finally {
    connection.release();
  }
};

exports.updateRoom = async (req, res) => {
  const { id } = req.params;
  const { price, status } = req.body;
  try {
    await db.query('UPDATE rooms SET price=?, status=? WHERE room_id=?', [price, status, id]);
    res.json({ success: true, message: 'Room updated successfully' });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

exports.deleteRoom = async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM rooms WHERE room_id=?', [id]);
    res.json({ success: true, message: 'Room deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- AMENITIES ---
exports.getAllAmenities = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM amenities');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createAmenity = async (req, res) => {
  const { name, icon_name } = req.body;
  try {
    const [res] = await db.query('INSERT INTO amenities (name, icon_name) VALUES (?, ?)', [name, icon_name]);
    res.status(201).json({ success: true, amenity_id: res.insertId });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// --- SEMESTERS ---
exports.getAllSemesters = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM semesters ORDER BY academic_year DESC, term ASC');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createSemester = async (req, res) => {
  const { academic_year, term, start_date, end_date, is_active } = req.body;
  try {
    const [res] = await db.query(
      'INSERT INTO semesters (academic_year, term, start_date, end_date, is_active) VALUES (?, ?, ?, ?, ?)',
      [academic_year, term, start_date, end_date, is_active || false]
    );
    res.status(201).json({ success: true, semester_id: res.insertId });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// --- ADDONS ---
exports.getAllAddons = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM addons');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.createAddon = async (req, res) => {
  const { name, monthly_price, description, is_available } = req.body;
  try {
    const [res] = await db.query(
      'INSERT INTO addons (name, monthly_price, description, is_available) VALUES (?, ?, ?, ?)',
      [name, monthly_price, description, is_available !== undefined ? is_available : true]
    );
    res.status(201).json({ success: true, addon_id: res.insertId });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};
