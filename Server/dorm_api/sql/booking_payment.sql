-- =====================================================================
-- ระบบจองห้องแบบจ่ายเงินผ่านแอดมิน + แจ้งเตือนในแชท   (ส่วนเสริม ไม่แก้ตารางเดิมของเพื่อน)
-- วิธีใช้: phpMyAdmin -> เลือกฐานข้อมูล dorm_master -> Import ไฟล์นี้
--         หรือ  npm run setup:booking   (รันซ้ำได้ ไม่พัง)
--
-- ตารางใหม่ 2 ตาราง
--   dorm_rent_plans   เจ้าของหอตั้งว่าหอนี้เปิดให้เช่าแบบไหน (1 อาทิตย์ / 1 เดือน / 1 เทอม / 1 ปี)
--                     ยังไม่มีแถวของหอไหน = เปิดทุกแบบ / ยอดเงินคิดจากค่าเช่าต่อเดือนของห้อง (rooms.price_per_month)
--   booking_payments  เงินที่ผู้เช่าต้องจ่าย + สถานะการตรวจของแอดมินและเจ้าของหอ (ผูกกับ bookings 1 ต่อ 1)
-- แก้ตารางเดิม 1 จุด (ของระบบแชท)
--   messages.message_type   'text' = ข้อความที่คนพิมพ์ / 'system' = ข้อความแจ้งเตือนจากระบบ
-- =====================================================================

CREATE TABLE IF NOT EXISTS dorm_rent_plans (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dorm_id    BIGINT UNSIGNED NOT NULL,
  plan       ENUM('week','month','term','year') NOT NULL,   -- 1 อาทิตย์ / 1 เดือน / 1 เทอม (4 เดือน) / 1 ปี
  price      INT UNSIGNED NOT NULL DEFAULT 0,                -- (ไม่ได้ใช้แล้ว: ราคาคิดจากค่าเช่าของห้อง)
  is_active  TINYINT(1) NOT NULL DEFAULT 1,                  -- 0 = หอนี้ไม่เปิดให้เช่าแบบนี้
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY dorm_rent_plans_dorm_plan_uq (dorm_id, plan),
  CONSTRAINT dorm_rent_plans_dorm_fk FOREIGN KEY (dorm_id) REFERENCES dorms (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_payments (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id        BIGINT UNSIGNED NOT NULL,                -- bookings.id (การจองของระบบเดิม)
  tenant_id         BIGINT UNSIGNED NOT NULL,
  dorm_id           BIGINT UNSIGNED NOT NULL,
  room_id           BIGINT UNSIGNED NOT NULL,
  plan              ENUM('week','month','term','year') NOT NULL,
  amount            INT UNSIGNED NOT NULL,                   -- ยอดที่ต้องจ่าย (ล็อกตามราคาที่เจ้าของตั้ง ณ ตอนจอง)
  paid_amount       INT UNSIGNED NULL,                       -- ยอดที่จ่ายเข้ามาจริง
  status            ENUM('awaiting_payment','paid','approved','rejected',
                         'completed','owner_rejected','cancelled','expired')
                    NOT NULL DEFAULT 'awaiting_payment',
  payment_ref       VARCHAR(40) NULL,                        -- เลขอ้างอิงการโอน (mock)
  paid_at           DATETIME NULL,
  admin_id          BIGINT UNSIGNED NULL,
  admin_reviewed_at DATETIME NULL,
  admin_note        VARCHAR(500) NULL,
  owner_reviewed_at DATETIME NULL,
  owner_note        VARCHAR(500) NULL,
  expires_at        DATETIME NOT NULL,                       -- ไม่จ่ายภายในเวลานี้ = ปล่อยห้องคืน
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY booking_payments_booking_uq (booking_id),
  KEY booking_payments_room_status_idx (room_id, status),
  KEY booking_payments_status_idx (status, created_at),
  KEY booking_payments_tenant_idx (tenant_id, created_at),
  CONSTRAINT booking_payments_booking_fk FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE,
  CONSTRAINT booking_payments_tenant_fk  FOREIGN KEY (tenant_id)  REFERENCES users (id),
  CONSTRAINT booking_payments_dorm_fk    FOREIGN KEY (dorm_id)    REFERENCES dorms (id) ON DELETE CASCADE,
  CONSTRAINT booking_payments_room_fk    FOREIGN KEY (room_id)    REFERENCES rooms (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ตารางที่สร้างจากเวอร์ชันแรก (price ไม่มีค่าเริ่มต้น) -> ใส่ค่าเริ่มต้นให้
ALTER TABLE dorm_rent_plans MODIFY price INT UNSIGNED NOT NULL DEFAULT 0;

-- XAMPP ใช้ MariaDB -> รองรับ IF NOT EXISTS (รันซ้ำได้)
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS message_type ENUM('text','system') NOT NULL DEFAULT 'text' AFTER message_text;
