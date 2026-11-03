-- =====================================================================
--  DormSpace — seed.sql (ข้อมูลตัวอย่างสำหรับทดสอบ Dashboard นักศึกษา)
--  ลำดับการรัน: schema.sql → seed.sql
--  ไฟล์นี้ "ไม่" ลบข้อมูลเดิม ถ้าอยากเริ่มใหม่ให้รัน schema.sql ก่อนแล้วค่อยรันไฟล์นี้
-- =====================================================================

SET NAMES utf8mb4;
USE dormspace;

-- ---------------------------------------------------------------------
-- 1) ตึก / ประเภทห้อง / ห้อง
-- ---------------------------------------------------------------------
INSERT INTO buildings (building_id, code, name, total_floors, description) VALUES
(1, 'A', 'North Hall',       3, 'Close to the main campus quad'),
(2, 'B', 'South Residence',  3, 'Quiet building, good for studying'),
(3, 'C', 'West Quad',        3, 'Newer building near the canteen');

INSERT INTO room_types (room_type_id, name, capacity, description) VALUES
(1, 'Single Studio', 1, 'Private room for one student'),
(2, 'Double Suite',  2, 'Shared room for two students'),
(3, 'Quad Shared',   4, 'Shared room for four students');

INSERT INTO rooms (room_id, building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y) VALUES
(1, 1, 1, '101', 1, 650.00, 240.0, 'S', 1, 1),
(2, 1, 2, '102', 1, 480.00, 320.0, 'S', 2, 1),
(3, 1, 2, '103', 1, 480.00, 320.0, 'N', 3, 1),
(4, 2, 1, '101', 1, 620.00, 230.0, 'E', 1, 1),
(5, 2, 2, '201', 2, 500.00, 330.0, 'W', 1, 1),
(6, 3, 3, '101', 1, 350.00, 420.0, 'N', 1, 1);

-- ---------------------------------------------------------------------
-- 2) สิ่งอำนวยความสะดวก
-- ---------------------------------------------------------------------
INSERT INTO amenities (amenity_id, name, icon) VALUES
(1, 'Air-con',       'snowflake'),
(2, 'En-suite Bath', 'bath'),
(3, 'Wifi',          'wifi'),
(4, 'Balcony',       'balcony'),
(5, 'Study Desk',    'desk'),
(6, 'Quiet Zone',    'volume-off');

INSERT INTO room_amenities (room_id, amenity_id) VALUES
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 3), (2, 5),
(3, 1), (3, 3),
(4, 1), (4, 2), (4, 6),
(5, 1), (5, 3),
(6, 3);

-- ---------------------------------------------------------------------
-- 3) เทอม และ Add-ons
-- ---------------------------------------------------------------------
INSERT INTO semesters (semester_id, name, start_date, end_date, is_open) VALUES
(1, 'Fall 2027',   '2027-08-20', '2028-05-31', TRUE),
(2, 'Spring 2028', '2028-01-10', '2028-05-31', TRUE);

INSERT INTO addons (addon_id, name, description, price_per_month, is_active) VALUES
(1, 'Micro-Fridge Rental', 'Small fridge for your room', 25.00, TRUE),
(2, 'Parking',             'Campus parking permit',      40.00, TRUE),
(3, 'Room Cleaning',       'Weekly cleaning service',    30.00, TRUE);

-- ---------------------------------------------------------------------
-- 4) ผู้ใช้
--    password_hash เป็นค่าหลอก (ใช้ล็อกอินกับบัญชีเหล่านี้ไม่ได้)
--    ตอนทดสอบ API ของ Dashboard เราจะใช้ JWT ที่สร้างเองแทน
--    ส่วนล็อกอินจริงให้ใช้ API สมัครสมาชิกของระบบ 1 (hash ด้วย argon2id)
-- ---------------------------------------------------------------------
INSERT INTO users (user_id, email, password_hash, full_name, phone, user_type, role, student_id, faculty) VALUES
(1, 'alex.morgan@example.com',  'SEED_NOT_A_REAL_HASH', 'Alex Morgan',  '0811111111', 'student', 'user',  'STU-882910', 'Computer Science'),
(2, 'jordan.lee@example.com',   'SEED_NOT_A_REAL_HASH', 'Jordan Lee',   '0822222222', 'student', 'user',  'STU-882911', 'Engineering'),
(3, 'sam.rivera@example.com',   'SEED_NOT_A_REAL_HASH', 'Sam Rivera',   '0833333333', 'student', 'user',  'STU-882912', 'Science'),
(4, 'admin@example.com',        'SEED_NOT_A_REAL_HASH', 'Dorm Admin',   '0844444444', 'general', 'admin', NULL,         NULL);

INSERT INTO roommate_preferences (user_id, sleep_schedule, cleanliness, study_habit) VALUES
(1, 'early_bird', 'very_neat', 'quiet'),
(2, 'early_bird', 'average',   'quiet'),
(3, 'night_owl',  'relaxed',   'group_study');

-- ---------------------------------------------------------------------
-- 5) การจอง (ออกแบบให้ทดสอบได้หลายกรณี)
--    #1 Alex  -> ห้อง A102, reserved  (มีรูมเมท Jordan)
--    #2 Jordan-> ห้อง A102, reserved  (รูมเมทของ Alex)
--    #3 Sam   -> ห้อง A103, pending   (ยังไม่มีรูมเมท, มัดจำยังไม่จ่าย)
--    #4 Alex  -> ห้อง B101, cancelled (ใช้ทดสอบสถานะยกเลิก + คืนเงิน)
--    total_amount = (ค่าห้อง + add-ons) x lease_months
-- ---------------------------------------------------------------------
INSERT INTO bookings
  (booking_id, reference_code, user_id, room_id, semester_id, lease_months,
   move_in_date, move_out_date, monthly_rent, total_amount, deposit_amount, status, expires_at) VALUES
(1, 'DS-000001', 1, 2, 1, 9, '2027-08-20', '2028-05-20', 480.00, 4545.00, 200.00, 'reserved',  NULL),
(2, 'DS-000002', 2, 2, 1, 9, '2027-08-20', '2028-05-20', 480.00, 4320.00, 200.00, 'reserved',  NULL),
(3, 'DS-000003', 3, 3, 1, 9, '2027-08-20', '2028-05-20', 480.00, 4680.00, 200.00, 'pending',   DATE_ADD(NOW(), INTERVAL 2 DAY)),
(4, 'DS-000004', 1, 4, 2, 9, '2028-01-10', '2028-10-10', 620.00, 5580.00, 200.00, 'cancelled', NULL);

INSERT INTO booking_addons (booking_id, addon_id, price_per_month) VALUES
(1, 1, 25.00),   -- Alex: Micro-Fridge
(3, 2, 40.00);   -- Sam: Parking

-- ---------------------------------------------------------------------
-- 6) การชำระเงิน
-- ---------------------------------------------------------------------
INSERT INTO payments
  (payment_id, booking_id, amount, payment_type, method, status, transaction_ref, receipt_no, paid_at) VALUES
(1, 1, 200.00, 'deposit', 'mock', 'paid',     'MOCK-0001', 'RC-000001', '2026-10-20 10:30:00'),
(2, 2, 200.00, 'deposit', 'mock', 'paid',     'MOCK-0002', 'RC-000002', '2026-10-21 14:05:00'),
(3, 3, 200.00, 'deposit', 'mock', 'pending',  NULL,        NULL,        NULL),
(4, 4, 200.00, 'deposit', 'mock', 'refunded', 'MOCK-0003', 'RC-000003', '2026-09-15 09:00:00');
