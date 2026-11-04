const pool = require('../config/db');

// ดึงการจองทั้งหมดของผู้ใช้ 1 คน พร้อมข้อมูลห้อง ตึก เทอม add-ons และมัดจำที่จ่ายแล้ว
async function getBookingsByUser(userId) {
  const sql = `
    SELECT
      b.booking_id,
      b.reference_code,
      b.status,
      b.lease_months,
      b.move_in_date,
      b.move_out_date,
      b.monthly_rent,
      b.total_amount,
      b.deposit_amount,
      DATEDIFF(b.move_in_date, CURDATE()) AS days_until_move_in,
      r.room_number,
      r.floor,
      rt.name  AS room_type,
      bd.code  AS building_code,
      bd.name  AS building_name,
      s.name   AS semester_name,
      (SELECT GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ')
         FROM booking_addons ba
         JOIN addons a ON a.addon_id = ba.addon_id
        WHERE ba.booking_id = b.booking_id) AS addons,
      (SELECT COALESCE(SUM(p.amount), 0)
         FROM payments p
        WHERE p.booking_id = b.booking_id
          AND p.payment_type = 'deposit'
          AND p.status = 'paid') AS deposit_paid
    FROM bookings b
    JOIN rooms      r  ON r.room_id       = b.room_id
    JOIN room_types rt ON rt.room_type_id = r.room_type_id
    JOIN buildings  bd ON bd.building_id  = r.building_id
    JOIN semesters  s  ON s.semester_id   = b.semester_id
    WHERE b.user_id = ?
    ORDER BY b.created_at DESC, b.booking_id DESC
  `;
  const [rows] = await pool.query(sql, [userId]);
  return rows;
}

// หาการจอง 1 รายการ โดยต้องเป็นของผู้ใช้คนนี้เท่านั้น (ไม่เจอ = คืน null)
async function getBookingForUser(bookingId, userId) {
  const [rows] = await pool.query(
    `SELECT booking_id, room_id, semester_id
       FROM bookings
      WHERE booking_id = ? AND user_id = ?`,
    [bookingId, userId]
  );
  return rows[0] || null;
}

// ดึงแบบสอบถามรูมเมทของผู้ใช้ (ยังไม่เคยตอบ = คืน null)
async function getPreferences(userId) {
  const [rows] = await pool.query(
    `SELECT sleep_schedule, cleanliness, study_habit
       FROM roommate_preferences
      WHERE user_id = ?`,
    [userId]
  );
  return rows[0] || null;
}

// หาคนอื่นที่จองห้องเดียวกัน เทอมเดียวกัน และการจองยังใช้งานอยู่
async function getRoommates(roomId, semesterId, userId) {
  const [rows] = await pool.query(
    `SELECT u.full_name, u.faculty,
            rp.sleep_schedule, rp.cleanliness, rp.study_habit
       FROM bookings b
       JOIN users u ON u.user_id = b.user_id
       LEFT JOIN roommate_preferences rp ON rp.user_id = u.user_id
      WHERE b.room_id = ?
        AND b.semester_id = ?
        AND b.user_id <> ?
        AND b.status IN ('pending', 'reserved', 'checked_in')
        AND (b.status <> 'pending' OR b.expires_at IS NULL OR b.expires_at > NOW())
      ORDER BY b.booking_id`,
    [roomId, semesterId, userId]
  );
  return rows;
}

module.exports = {
  getBookingsByUser,
  getBookingForUser,
  getPreferences,
  getRoommates,
  getPaymentsByUser,
};
// ดึงรายการชำระเงินทั้งหมดของผู้ใช้ 1 คน (ผ่านการจองของเขา) เรียงล่าสุดก่อน
async function getPaymentsByUser(userId) {
  const sql = `
    SELECT
      p.payment_id,
      p.receipt_no,
      p.amount,
      p.payment_type,
      p.method,
      p.status,
      p.paid_at,
      p.created_at,
      b.booking_id,
      b.reference_code,
      r.room_number,
      bd.code AS building_code,
      bd.name AS building_name
    FROM payments p
    JOIN bookings  b  ON b.booking_id  = p.booking_id
    JOIN rooms     r  ON r.room_id     = b.room_id
    JOIN buildings bd ON bd.building_id = r.building_id
    WHERE b.user_id = ?
    ORDER BY COALESCE(p.paid_at, p.created_at) DESC, p.payment_id DESC
  `;
  const [rows] = await pool.query(sql, [userId]);
  return rows;
}