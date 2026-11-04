-- =====================================================================
-- DormSpace: Sprint 2 Database Schema & DDL
-- Topic: Admin Dormitory Data Management
-- Database: MySQL 8.0+ / MariaDB 10.5+
-- =====================================================================

CREATE DATABASE IF NOT EXISTS dormspace
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE dormspace;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS room_images, room_amenities, room_types, rooms, amenities, addons, semesters, buildings, users;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. USERS TABLE
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    full_name      VARCHAR(150) NOT NULL,
    phone          VARCHAR(20),
    user_type      ENUM('student', 'general') NOT NULL DEFAULT 'student',
    role           ENUM('user', 'admin') NOT NULL DEFAULT 'user',
    student_id     VARCHAR(20) UNIQUE,
    faculty        VARCHAR(100),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. BUILDINGS TABLE
CREATE TABLE buildings (
    building_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    total_floors  INT NOT NULL DEFAULT 1,
    gender_type   ENUM('male', 'female', 'mixed') NOT NULL DEFAULT 'mixed',
    description   TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. ROOM TYPES TABLE
CREATE TABLE room_types (
    type_id       INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    base_price    DECIMAL(10,2) NOT NULL,
    room_size     VARCHAR(50),
    max_capacity  INT NOT NULL DEFAULT 1,
    description   TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4. ROOMS TABLE
CREATE TABLE rooms (
    room_id       INT AUTO_INCREMENT PRIMARY KEY,
    building_id   INT NOT NULL,
    type_id       INT NOT NULL,
    room_number   VARCHAR(20) NOT NULL,
    floor         INT NOT NULL,
    price         DECIMAL(10, 2) NOT NULL,
    status        ENUM('available', 'reserved', 'occupied', 'maintenance') NOT NULL DEFAULT 'available',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rooms_building FOREIGN KEY (building_id) REFERENCES buildings(building_id) ON DELETE CASCADE,
    CONSTRAINT fk_rooms_type FOREIGN KEY (type_id) REFERENCES room_types(type_id) ON DELETE RESTRICT,
    UNIQUE KEY uk_building_room (building_id, room_number)
) ENGINE=InnoDB;

-- 5. AMENITIES TABLE
CREATE TABLE amenities (
    amenity_id    INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    icon_name     VARCHAR(50),
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 6. ROOM AMENITIES JUNCTION TABLE
CREATE TABLE room_amenities (
    room_id       INT NOT NULL,
    amenity_id    INT NOT NULL,
    PRIMARY KEY (room_id, amenity_id),
    CONSTRAINT fk_ra_room FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_ra_amenity FOREIGN KEY (amenity_id) REFERENCES amenities(amenity_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. ROOM IMAGES TABLE
CREATE TABLE room_images (
    image_id      INT AUTO_INCREMENT PRIMARY KEY,
    room_id       INT NOT NULL,
    image_url     VARCHAR(500) NOT NULL,
    is_primary    BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_images_room FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. SEMESTERS TABLE
CREATE TABLE semesters (
    semester_id   INT AUTO_INCREMENT PRIMARY KEY,
    academic_year INT NOT NULL,
    term          ENUM('1', '2', 'summer') NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    is_active     BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_year_term (academic_year, term)
) ENGINE=InnoDB;

-- 9. ADDONS TABLE
CREATE TABLE addons (
    addon_id      INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    monthly_price DECIMAL(10, 2) NOT NULL,
    description   TEXT,
    is_available  BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
