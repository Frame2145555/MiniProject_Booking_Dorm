-- =====================================================================
--  DormSpace — queries_dashboard.sql
--  ระบบ 6: Student Dashboard (My Bookings)
--
--  ไฟล์นี้รวม SQL ของ Dashboard ไว้ที่เดียว (ตัวเดียวกับที่ใช้ใน
--  backend/models/dashboardModel.js แต่เปลี่ยน ? เป็นตัวแปร @uid / @bid
--  เพื่อให้รันทดสอบใน mysql ได้โดยตรง)
--
--  วิธีรัน:   source C:/dormspace/MiniProject_Booking_Dorm/database/queries_dashboard.sql
--  ต้องรัน schema.sql → seed.sql ก่อน
--
--  ตัวแปร:  @uid = user_id ของคนที่ล็อกอิน (ในแอปจริงมาจาก JWT)
--           @bid = booking_id ที่ต้องการดูรูมเมท
--  ข้อมูลตัวอย่าง: 1 = Alex, 2 = Jordan, 3 = Sam, 4 = Admin
-- =====================================================================

SET NAMES utf8mb4;
USE dormspace;

SET @uid = 1;   -- เปลี่ยนเป็น 2, 3, 4 เพื่อลองผู้ใช้คนอื่น
SET @bid = 1;   -- เปลี่ยนเป็น 2, 4 เพื่อลองการจองอื่น


-- ---------------------------------------------------------------------
-- Q6: การจองของฉัน
--   JOIN 4 ตาราง (rooms, room_types, buildings, semesters)
--   + subquery รวมชื่อ add-ons เป็นข้อความเดียว (GROUP_CONCAT)
--   + subquery รวมมัดจำที่ "จ่ายแล้ว" (COALESCE กันค่า NULL เมื่อยังไม่เคยจ่าย)
--   เงื่อนไข b.user_id = @uid คือสิ่งที่ทำให้ผู้ใช้เห็นเฉพาะข้อมูลของตัวเอง
--
--   ผลที่คาดหวัง (seed.sql):
--     @uid=1 -> 2 แถว: DS-000004 (cancelled) และ DS-000001 (reserved, ห้อง 102 ตึก A,
--               addons = Micro-Fridge Rental, deposit_paid = 200.00)
--     @uid=2 -> 1 แถว: DS-000002 (reserved, addons เป็น NULL)
--     @uid=3 -> 1 แถว: DS-000003 (pending, addons = Parking, deposit_paid = 0.00)
--     @uid=4 -> 0 แถว
-- ---------------------------------------------------------------------
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
  rt.name AS room_type,
  bd.code AS building_code,
  bd.name AS building_name,
  s.name  AS semester_name,
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
WHERE b.user_id = @uid
ORDER BY b.created_at DESC, b.booking_id DESC;


-- ---------------------------------------------------------------------
-- Q6b-1: แบบสอบถามรูมเมทของฉัน (ใช้เทียบกับรูมเมทใน Q6b-2)
--   ผลที่คาดหวัง: @uid=1 -> early_bird / very_neat / quiet
--                 @uid=4 -> 0 แถว (ยังไม่เคยตอบ)
-- ---------------------------------------------------------------------
SELECT sleep_schedule, cleanliness, study_habit
FROM roommate_preferences
WHERE user_id = @uid;


-- ---------------------------------------------------------------------
-- Q6b-2: รูมเมทของการจอง @bid
--   ใช้ self-join: bookings ตัวแรก (me) = การจองของฉัน
--                  bookings ตัวที่สอง (b)  = การจองอื่นในห้องและเทอมเดียวกัน
--   - me.user_id = @uid  ทำให้ดูได้เฉพาะการจองของตัวเอง
--   - b.user_id <> me.user_id  ไม่นับตัวเอง
--   - b.status IN (...)  นับเฉพาะการจองที่ยังใช้งานอยู่
--   - pending ที่หมดเวลา (expires_at ผ่านไปแล้ว) ไม่นับ เพราะระบบไม่กันห้องแล้ว
--   - LEFT JOIN roommate_preferences  รูมเมทที่ยังไม่ตอบแบบสอบถามจะยังโผล่ในรายการ
--   ส่วนคำนวณ % match ทำใน Node.js (backend/utils/matchScore.js)
--   เพราะเป็นตรรกะที่เขียน unit test ได้ง่าย
--
--   ผลที่คาดหวัง: @uid=1,@bid=1 -> Jordan Lee (Engineering, early_bird/average/quiet)
--                 @uid=2,@bid=2 -> Alex Morgan
--                 @uid=1,@bid=4 -> 0 แถว (ห้อง B101 ไม่มีคนอื่น)
--                 @uid=1,@bid=2 -> 0 แถว (booking #2 ไม่ใช่ของ Alex)
-- ---------------------------------------------------------------------
SELECT u.full_name, u.faculty,
       rp.sleep_schedule, rp.cleanliness, rp.study_habit
FROM bookings me
JOIN bookings b
  ON  b.room_id     = me.room_id
  AND b.semester_id = me.semester_id
  AND b.user_id    <> me.user_id
JOIN users u ON u.user_id = b.user_id
LEFT JOIN roommate_preferences rp ON rp.user_id = u.user_id
WHERE me.booking_id = @bid
  AND me.user_id    = @uid
  AND b.status IN ('pending', 'reserved', 'checked_in')
  AND (b.status <> 'pending' OR b.expires_at IS NULL OR b.expires_at > NOW())
ORDER BY b.booking_id;


-- ---------------------------------------------------------------------
-- Q6c: ประวัติการชำระเงินของฉัน (ผ่านการจองของฉัน) เรียงล่าสุดก่อน
--   COALESCE(paid_at, created_at): รายการที่ยังไม่จ่ายใช้วันที่สร้างแทน
--
--   ผลที่คาดหวัง: @uid=1 -> 2 แถว: RC-000001 (paid) แล้ว RC-000003 (refunded)
--                 @uid=3 -> 1 แถว: pending, receipt_no เป็น NULL
--                 @uid=4 -> 0 แถว
-- ---------------------------------------------------------------------
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
JOIN bookings  b  ON b.booking_id   = p.booking_id
JOIN rooms     r  ON r.room_id      = b.room_id
JOIN buildings bd ON bd.building_id = r.building_id
WHERE b.user_id = @uid
ORDER BY COALESCE(p.paid_at, p.created_at) DESC, p.payment_id DESC;


-- ---------------------------------------------------------------------
-- Q6c-summary: สรุปยอดตามสถานะ (GROUP BY)
--   ในแอป backend คำนวณยอดรวมในโค้ด JavaScript แต่ใช้ SQL ก็ได้ผลเท่ากัน
--   ผลที่คาดหวัง: @uid=1 -> paid 200.00 (1 รายการ) และ refunded 200.00 (1 รายการ)
-- ---------------------------------------------------------------------
SELECT p.status,
       COUNT(*)      AS payment_count,
       SUM(p.amount) AS total_amount
FROM payments p
JOIN bookings b ON b.booking_id = p.booking_id
WHERE b.user_id = @uid
GROUP BY p.status
ORDER BY p.status;


-- =====================================================================
--  ตรวจแผนการทำงานของ Query ด้วย EXPLAIN
--  FORMAT=TREE แสดงเป็นต้นไม้อ่านง่าย ให้ดูคำที่ขึ้นว่า
--    "Index lookup" / "Single-row index lookup"  = ใช้ดัชนี (ดี)
--    "Table scan"                                  = อ่านทั้งตาราง
--  หมายเหตุ: ตารางตัวอย่างมีข้อมูลไม่กี่แถว MySQL อาจเลือก Table scan ทั้งที่มีดัชนี
--  เพราะอ่านทั้งตารางเร็วกว่า ไม่ได้แปลว่าออกแบบผิด ดัชนีจะมีผลเมื่อข้อมูลมากขึ้น
--
--  ดัชนีที่เกี่ยวข้อง (อยู่ใน schema.sql แล้ว):
--    bookings : uq_active_booking_per_user_semester (user_id, ...)  -> WHERE b.user_id
--               ix_bookings_room_dates (room_id, ...)               -> หารูมเมทในห้องเดียวกัน
--    payments : ix_payments_booking (booking_id)                    -> หาการชำระเงินของการจอง
--    booking_addons : PRIMARY KEY (booking_id, addon_id)            -> หา add-ons ของการจอง
--    roommate_preferences : PRIMARY KEY (user_id)                   -> หาแบบสอบถามของผู้ใช้
-- =====================================================================

EXPLAIN FORMAT=TREE
SELECT b.booking_id, r.room_number, bd.name
FROM bookings b
JOIN rooms     r  ON r.room_id      = b.room_id
JOIN buildings bd ON bd.building_id = r.building_id
WHERE b.user_id = @uid;

EXPLAIN FORMAT=TREE
SELECT p.payment_id
FROM payments p
JOIN bookings b ON b.booking_id = p.booking_id
WHERE b.user_id = @uid;

EXPLAIN FORMAT=TREE
SELECT u.full_name
FROM bookings me
JOIN bookings b
  ON  b.room_id     = me.room_id
  AND b.semester_id = me.semester_id
  AND b.user_id    <> me.user_id
JOIN users u ON u.user_id = b.user_id
WHERE me.booking_id = @bid
  AND me.user_id    = @uid;
