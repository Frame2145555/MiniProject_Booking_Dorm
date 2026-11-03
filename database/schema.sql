-- =====================================================================
--  DormSpace — Dormitory Reservation System
--  Database Schema (MySQL 8.0.16+ / MariaDB 10.5+)
--  ขอบเขต: โปรเจกต์ 3 สัปดาห์ — 14 ตาราง (ไม่มี view: logic คำนวณอยู่ใน Model ดู queries.sql)
--
--  ลำดับการรัน: schema.sql → seed.sql
--  รันซ้ำได้ (DROP ก่อน CREATE)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS dormspace
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;    -- utf8mb4 = รองรับภาษาไทย + emoji ใน comment (unicode_ci ใช้ได้ทั้ง MySQL/MariaDB)
USE dormspace;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW  IF EXISTS v_roommate_matches, v_room_availability;   -- ลบของจากเวอร์ชันก่อน (ถ้ามี)
DROP TABLE IF EXISTS user_sessions, auth_tokens, comments, payments, booking_addons, bookings, addons,
                     roommate_preferences, semesters, room_images,
                     room_amenities, amenities, rooms, room_types,
                     buildings, users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1) USERS — นักศึกษา / คนทั่วไป / แอดมิน อยู่ตารางเดียวกัน
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,              -- เก็บ bcrypt hash เท่านั้น
    full_name      VARCHAR(150) NOT NULL,
    phone          VARCHAR(20),
    user_type      ENUM('student', 'general') NOT NULL DEFAULT 'student',
    role           ENUM('user', 'admin')      NOT NULL DEFAULT 'user',
    student_id     VARCHAR(20)  UNIQUE,                -- บังคับเฉพาะ user_type = student
    faculty        VARCHAR(100),
    -- ----- ใช้กับระบบ register / login -----
    -- login ได้ทั้งด้วย email หรือ student_id ; session ให้ framework จัดการ ($_SESSION / express-session)
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE, -- FALSE = แอดมินระงับบัญชี → login ไม่ได้
    last_login_at  DATETIME,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_student_has_id
        CHECK (user_type <> 'student' OR student_id IS NOT NULL)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2) DORMITORY & ROOM MANAGEMENT
-- ---------------------------------------------------------------------
CREATE TABLE buildings (
    building_id    INT AUTO_INCREMENT PRIMARY KEY,
    code           VARCHAR(5)   NOT NULL UNIQUE,       -- 'A', 'B', 'C'  (ใช้ทำ Building Tabs)
    name           VARCHAR(100) NOT NULL,              -- 'North Hall'
    total_floors   SMALLINT     NOT NULL CHECK (total_floors > 0),
    description    TEXT
) ENGINE = InnoDB;

CREATE TABLE room_types (                              -- Room Layout Filter
    room_type_id   INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(50)  NOT NULL UNIQUE,       -- 'Single Studio', 'Double Suite', 'Quad Shared'
    capacity       SMALLINT     NOT NULL CHECK (capacity BETWEEN 1 AND 8),
    description    TEXT
) ENGINE = InnoDB;

CREATE TABLE rooms (
    room_id          INT AUTO_INCREMENT PRIMARY KEY,
    building_id      INT           NOT NULL,
    room_type_id     INT           NOT NULL,
    room_number      VARCHAR(10)   NOT NULL,           -- '101', '201'
    floor            SMALLINT      NOT NULL CHECK (floor > 0),
    price_per_month  DECIMAL(10,2) NOT NULL CHECK (price_per_month >= 0),
    size_sqft        DECIMAL(6,1),
    facing           ENUM('N','S','E','W'),            -- ทิศของห้อง (optional)
    grid_x           SMALLINT,                         -- ตำแหน่งบนผัง 2D (คอลัมน์)
    grid_y           SMALLINT,                         -- ตำแหน่งบนผัง 2D (แถว)
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE, -- FALSE = ปิดซ่อม / ไม่เปิดจอง
    UNIQUE KEY uq_room_number (building_id, room_number),
    KEY ix_rooms_search   (building_id, floor, room_type_id, price_per_month),
    UNIQUE KEY uq_room_building (room_id, building_id),      -- ให้ comments อ้างอิง (room_id, building_id) ได้
    FOREIGN KEY (building_id)  REFERENCES buildings(building_id),
    FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id)
) ENGINE = InnoDB;

CREATE TABLE amenities (                               -- Air-con, En-suite Bath, Wifi ...
    amenity_id     INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(50)  NOT NULL UNIQUE,
    icon           VARCHAR(50)                         -- ชื่อไอคอนฝั่ง frontend
) ENGINE = InnoDB;

CREATE TABLE room_amenities (                          -- M:N rooms ↔ amenities
    room_id        INT NOT NULL,
    amenity_id     INT NOT NULL,
    PRIMARY KEY (room_id, amenity_id),
    FOREIGN KEY (room_id)    REFERENCES rooms(room_id)         ON DELETE CASCADE,
    FOREIGN KEY (amenity_id) REFERENCES amenities(amenity_id)  ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE room_images (                             -- รูปห้องจริงใน Room Detail Modal
    image_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_id        INT          NOT NULL,
    image_url      VARCHAR(500) NOT NULL,
    sort_order     SMALLINT     NOT NULL DEFAULT 0,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3) SEMESTERS — Semester Selector
-- ---------------------------------------------------------------------
CREATE TABLE semesters (
    semester_id    INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(50)  NOT NULL UNIQUE,       -- 'Fall 2027', 'Spring 2028'
    start_date     DATE         NOT NULL,              -- = วัน move-in
    end_date       DATE         NOT NULL,
    is_open        BOOLEAN      NOT NULL DEFAULT TRUE, -- เปิดให้จองหรือไม่
    CHECK (end_date > start_date)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 4) ROOMMATE PREFERENCES — 1 แถวต่อ user (upsert ตอน Step 4 ของ wizard)
-- ---------------------------------------------------------------------
CREATE TABLE roommate_preferences (
    user_id        INT PRIMARY KEY,
    sleep_schedule ENUM('early_bird', 'night_owl', 'flexible')  NOT NULL,
    cleanliness    ENUM('very_neat', 'average', 'relaxed')      NOT NULL,
    study_habit    ENUM('quiet', 'music_ok', 'group_study')     NOT NULL,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 5) RESERVATION & ADD-ONS
-- ---------------------------------------------------------------------
CREATE TABLE addons (                                  -- Parking, Micro-Fridge, Cleaning
    addon_id         INT AUTO_INCREMENT PRIMARY KEY,
    name             VARCHAR(100)  NOT NULL UNIQUE,
    description      TEXT,
    price_per_month  DECIMAL(10,2) NOT NULL CHECK (price_per_month >= 0),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE
) ENGINE = InnoDB;

-- 1 booking = 1 เตียง (ห้องคู่/ห้องรวมจะมีหลาย booking ในห้องเดียวกันได้ ไม่เกิน capacity)
CREATE TABLE bookings (
    booking_id      INT AUTO_INCREMENT PRIMARY KEY,
    reference_code  VARCHAR(20)   UNIQUE,              -- 'DS-000001' — ตั้งค่าหลัง INSERT (ดู queries.sql Q4)
    user_id         INT           NOT NULL,
    room_id         INT           NOT NULL,
    semester_id     INT           NOT NULL,            -- เทอมที่เข้าอยู่
    lease_months    TINYINT       NOT NULL CHECK (lease_months IN (9, 12)), -- Academic Year / Full Year
    move_in_date    DATE          NOT NULL,
    move_out_date   DATE          NOT NULL,            -- = move_in + lease_months
    monthly_rent    DECIMAL(10,2) NOT NULL,            -- snapshot ราคาห้อง ณ วันจอง
    total_amount    DECIMAL(12,2) NOT NULL,            -- (ค่าห้อง + add-ons) × lease_months
    deposit_amount  DECIMAL(10,2) NOT NULL DEFAULT 200.00,
    status          ENUM('pending',                    -- กดจองแล้ว รอชำระมัดจำ
                         'reserved',                   -- ชำระมัดจำแล้ว
                         'checked_in',                 -- เข้าพักแล้ว
                         'completed',                  -- หมดสัญญา
                         'cancelled') NOT NULL DEFAULT 'pending',
    expires_at      DATETIME,                          -- pending เกินเวลานี้ = ไม่กันห้องแล้ว
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- MySQL ไม่มี partial unique index → ใช้ generated column แทน:
    -- = 1 เมื่อ booking ยัง active, = NULL เมื่อไม่ active (NULL ซ้ำกันได้ใน UNIQUE)
    active_flag     TINYINT AS (IF(status IN ('pending', 'reserved', 'checked_in'), 1, NULL)) STORED,
    CHECK (move_out_date > move_in_date),
    UNIQUE KEY uq_active_booking_per_user_semester (user_id, semester_id, active_flag),
    KEY ix_bookings_room_dates (room_id, move_in_date, move_out_date),
    FOREIGN KEY (user_id)     REFERENCES users(user_id),
    FOREIGN KEY (room_id)     REFERENCES rooms(room_id),
    FOREIGN KEY (semester_id) REFERENCES semesters(semester_id)
) ENGINE = InnoDB;

CREATE TABLE booking_addons (
    booking_id       INT NOT NULL,
    addon_id         INT NOT NULL,
    price_per_month  DECIMAL(10,2) NOT NULL,           -- snapshot ราคา ณ วันจอง
    PRIMARY KEY (booking_id, addon_id),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE,
    FOREIGN KEY (addon_id)   REFERENCES addons(addon_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 6) PAYMENTS — Payment History & Deposit Status
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT           NOT NULL,
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_type    ENUM('deposit', 'rent') NOT NULL DEFAULT 'deposit',
    method          ENUM('mock', 'credit_card', 'promptpay', 'bank_transfer')
                    NOT NULL DEFAULT 'mock',           -- 3 สัปดาห์: ใช้ mock gateway
    status          ENUM('pending', 'paid', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
    transaction_ref VARCHAR(100),                      -- id จาก gateway (ถ้ามี)
    receipt_no      VARCHAR(20)   UNIQUE,              -- 'RC-000001' — ตั้งค่าหลัง INSERT
    paid_at         DATETIME,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY ix_payments_booking (booking_id),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 7) COMMENTS — รีวิว/ความคิดเห็นต่อห้องหรือตึก + ตอบกลับได้ (thread 1 ชั้น)
--    room_id = NULL      → comment ถึงตึกทั้งตึก
--    parent_comment_id   → เป็นการตอบกลับ comment อื่น (เช่น แอดมินตอบ)
-- ---------------------------------------------------------------------
CREATE TABLE comments (
    comment_id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id            INT      NOT NULL,
    building_id        INT      NOT NULL,
    room_id            INT,
    parent_comment_id  INT,
    content            TEXT     NOT NULL,
    rating             TINYINT  CHECK (rating BETWEEN 1 AND 5),  -- ให้ดาวเฉพาะ comment หลัก (reply = NULL)
    is_hidden          BOOLEAN  NOT NULL DEFAULT FALSE,           -- แอดมินซ่อน comment ไม่เหมาะสม
    created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (CHAR_LENGTH(content) BETWEEN 1 AND 2000),
    KEY ix_comments_room     (room_id, created_at),
    KEY ix_comments_building (building_id, created_at),
    FOREIGN KEY (user_id)     REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (building_id) REFERENCES buildings(building_id),
    -- composite FK: บังคับให้ room_id อยู่ในตึก building_id จริง (ข้ามการเช็คเมื่อ room_id เป็น NULL)
    FOREIGN KEY (room_id, building_id) REFERENCES rooms(room_id, building_id),
    FOREIGN KEY (parent_comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE
) ENGINE = InnoDB;
