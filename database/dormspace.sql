-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 04, 2026 at 11:19 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `dormspace`
--

-- --------------------------------------------------------

--
-- Table structure for table `addons`
--

CREATE TABLE `addons` (
  `addon_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `price_per_month` decimal(10,2) NOT NULL CHECK (`price_per_month` >= 0),
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `amenities`
--

CREATE TABLE `amenities` (
  `amenity_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `icon` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `booking_id` int(11) NOT NULL,
  `reference_code` varchar(20) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `semester_id` int(11) NOT NULL,
  `lease_months` tinyint(4) NOT NULL CHECK (`lease_months` in (9,12)),
  `move_in_date` date NOT NULL,
  `move_out_date` date NOT NULL,
  `monthly_rent` decimal(10,2) NOT NULL,
  `total_amount` decimal(12,2) NOT NULL,
  `deposit_amount` decimal(10,2) NOT NULL DEFAULT 200.00,
  `status` enum('pending','reserved','checked_in','completed','cancelled') NOT NULL DEFAULT 'pending',
  `expires_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `active_flag` tinyint(4) GENERATED ALWAYS AS (if(`status` in ('pending','reserved','checked_in'),1,NULL)) STORED
) ;

-- --------------------------------------------------------

--
-- Table structure for table `booking_addons`
--

CREATE TABLE `booking_addons` (
  `booking_id` int(11) NOT NULL,
  `addon_id` int(11) NOT NULL,
  `price_per_month` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `buildings`
--

CREATE TABLE `buildings` (
  `building_id` int(11) NOT NULL,
  `code` varchar(5) NOT NULL,
  `name` varchar(100) NOT NULL,
  `total_floors` smallint(6) NOT NULL CHECK (`total_floors` > 0),
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `comments`
--

CREATE TABLE `comments` (
  `comment_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `building_id` int(11) NOT NULL,
  `room_id` int(11) DEFAULT NULL,
  `parent_comment_id` int(11) DEFAULT NULL,
  `content` text NOT NULL,
  `rating` tinyint(4) DEFAULT NULL CHECK (`rating` between 1 and 5),
  `is_hidden` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `payment_id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL CHECK (`amount` > 0),
  `payment_type` enum('deposit','rent') NOT NULL DEFAULT 'deposit',
  `method` enum('mock','credit_card','promptpay','bank_transfer') NOT NULL DEFAULT 'mock',
  `status` enum('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
  `transaction_ref` varchar(100) DEFAULT NULL,
  `receipt_no` varchar(20) DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `roommate_preferences`
--

CREATE TABLE `roommate_preferences` (
  `user_id` int(11) NOT NULL,
  `sleep_schedule` enum('early_bird','night_owl','flexible') NOT NULL,
  `cleanliness` enum('very_neat','average','relaxed') NOT NULL,
  `study_habit` enum('quiet','music_ok','group_study') NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `rooms`
--

CREATE TABLE `rooms` (
  `room_id` int(11) NOT NULL,
  `building_id` int(11) NOT NULL,
  `room_type_id` int(11) NOT NULL,
  `room_number` varchar(10) NOT NULL,
  `floor` smallint(6) NOT NULL CHECK (`floor` > 0),
  `price_per_month` decimal(10,2) NOT NULL CHECK (`price_per_month` >= 0),
  `size_sqft` decimal(6,1) DEFAULT NULL,
  `facing` enum('N','S','E','W') DEFAULT NULL,
  `grid_x` smallint(6) DEFAULT NULL,
  `grid_y` smallint(6) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `room_amenities`
--

CREATE TABLE `room_amenities` (
  `room_id` int(11) NOT NULL,
  `amenity_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `room_images`
--

CREATE TABLE `room_images` (
  `image_id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `image_url` varchar(500) NOT NULL,
  `sort_order` smallint(6) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `room_types`
--

CREATE TABLE `room_types` (
  `room_type_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `capacity` smallint(6) NOT NULL CHECK (`capacity` between 1 and 8),
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `semesters`
--

CREATE TABLE `semesters` (
  `semester_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `is_open` tinyint(1) NOT NULL DEFAULT 1
) ;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `user_type` enum('student','general') NOT NULL DEFAULT 'student',
  `role` enum('user','admin') NOT NULL DEFAULT 'user',
  `student_id` varchar(20) DEFAULT NULL,
  `faculty` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password_hash`, `full_name`, `phone`, `user_type`, `role`, `student_id`, `faculty`, `is_active`, `last_login_at`, `created_at`, `updated_at`) VALUES
(1, 'admin@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordadmin$', 'System Administrator', '0812345678', 'general', 'admin', NULL, NULL, 1, NULL, '2026-11-04 17:07:10', '2026-11-04 17:07:10'),
(2, 'student1@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordstudent$', 'Trinnakorn Phuangsorn', '0898765432', 'student', 'user', '6731501036', NULL, 1, NULL, '2026-11-04 17:07:10', '2026-11-04 17:07:10');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `addons`
--
ALTER TABLE `addons`
  ADD PRIMARY KEY (`addon_id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `amenities`
--
ALTER TABLE `amenities`
  ADD PRIMARY KEY (`amenity_id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`booking_id`),
  ADD UNIQUE KEY `reference_code` (`reference_code`),
  ADD UNIQUE KEY `uq_active_booking_per_user_semester` (`user_id`,`semester_id`,`active_flag`),
  ADD KEY `ix_bookings_room_dates` (`room_id`,`move_in_date`,`move_out_date`),
  ADD KEY `semester_id` (`semester_id`);

--
-- Indexes for table `booking_addons`
--
ALTER TABLE `booking_addons`
  ADD PRIMARY KEY (`booking_id`,`addon_id`),
  ADD KEY `addon_id` (`addon_id`);

--
-- Indexes for table `buildings`
--
ALTER TABLE `buildings`
  ADD PRIMARY KEY (`building_id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `comments`
--
ALTER TABLE `comments`
  ADD PRIMARY KEY (`comment_id`),
  ADD KEY `ix_comments_room` (`room_id`,`created_at`),
  ADD KEY `ix_comments_building` (`building_id`,`created_at`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `room_id` (`room_id`,`building_id`),
  ADD KEY `parent_comment_id` (`parent_comment_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`payment_id`),
  ADD UNIQUE KEY `receipt_no` (`receipt_no`),
  ADD KEY `ix_payments_booking` (`booking_id`);

--
-- Indexes for table `roommate_preferences`
--
ALTER TABLE `roommate_preferences`
  ADD PRIMARY KEY (`user_id`);

--
-- Indexes for table `rooms`
--
ALTER TABLE `rooms`
  ADD PRIMARY KEY (`room_id`),
  ADD UNIQUE KEY `uq_room_number` (`building_id`,`room_number`),
  ADD KEY `ix_rooms_search` (`building_id`,`floor`,`room_type_id`,`price_per_month`),
  ADD KEY `ix_room_building` (`room_id`,`building_id`),
  ADD KEY `room_type_id` (`room_type_id`);

--
-- Indexes for table `room_amenities`
--
ALTER TABLE `room_amenities`
  ADD PRIMARY KEY (`room_id`,`amenity_id`),
  ADD KEY `amenity_id` (`amenity_id`);

--
-- Indexes for table `room_images`
--
ALTER TABLE `room_images`
  ADD PRIMARY KEY (`image_id`),
  ADD KEY `room_id` (`room_id`);

--
-- Indexes for table `room_types`
--
ALTER TABLE `room_types`
  ADD PRIMARY KEY (`room_type_id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `semesters`
--
ALTER TABLE `semesters`
  ADD PRIMARY KEY (`semester_id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `student_id` (`student_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `addons`
--
ALTER TABLE `addons`
  MODIFY `addon_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `amenities`
--
ALTER TABLE `amenities`
  MODIFY `amenity_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `booking_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `buildings`
--
ALTER TABLE `buildings`
  MODIFY `building_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `comments`
--
ALTER TABLE `comments`
  MODIFY `comment_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `rooms`
--
ALTER TABLE `rooms`
  MODIFY `room_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `room_images`
--
ALTER TABLE `room_images`
  MODIFY `image_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `room_types`
--
ALTER TABLE `room_types`
  MODIFY `room_type_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `semesters`
--
ALTER TABLE `semesters`
  MODIFY `semester_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`room_id`),
  ADD CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`semester_id`) REFERENCES `semesters` (`semester_id`);

--
-- Constraints for table `booking_addons`
--
ALTER TABLE `booking_addons`
  ADD CONSTRAINT `booking_addons_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `booking_addons_ibfk_2` FOREIGN KEY (`addon_id`) REFERENCES `addons` (`addon_id`);

--
-- Constraints for table `comments`
--
ALTER TABLE `comments`
  ADD CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `comments_ibfk_2` FOREIGN KEY (`building_id`) REFERENCES `buildings` (`building_id`),
  ADD CONSTRAINT `comments_ibfk_3` FOREIGN KEY (`room_id`,`building_id`) REFERENCES `rooms` (`room_id`, `building_id`),
  ADD CONSTRAINT `comments_ibfk_4` FOREIGN KEY (`parent_comment_id`) REFERENCES `comments` (`comment_id`) ON DELETE CASCADE;

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`);

--
-- Constraints for table `roommate_preferences`
--
ALTER TABLE `roommate_preferences`
  ADD CONSTRAINT `roommate_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `rooms`
--
ALTER TABLE `rooms`
  ADD CONSTRAINT `rooms_ibfk_1` FOREIGN KEY (`building_id`) REFERENCES `buildings` (`building_id`),
  ADD CONSTRAINT `rooms_ibfk_2` FOREIGN KEY (`room_type_id`) REFERENCES `room_types` (`room_type_id`);

--
-- Constraints for table `room_amenities`
--
ALTER TABLE `room_amenities`
  ADD CONSTRAINT `room_amenities_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`room_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `room_amenities_ibfk_2` FOREIGN KEY (`amenity_id`) REFERENCES `amenities` (`amenity_id`) ON DELETE CASCADE;

--
-- Constraints for table `room_images`
--
ALTER TABLE `room_images`
  ADD CONSTRAINT `room_images_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`room_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;


-- =====================================================================
-- Seed Data Matching Exact dormspace.sql Schema
-- =====================================================================
USE `dormspace`;

-- Users
INSERT INTO `users` (`user_id`, `email`, `password_hash`, `full_name`, `phone`, `user_type`, `role`, `student_id`, `faculty`, `is_active`, `last_login_at`, `created_at`, `updated_at`) VALUES
(1, 'admin@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordadmin$', 'System Administrator', '0812345678', 'general', 'admin', NULL, NULL, 1, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(2, 'student1@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordstudent$', 'Trinnakorn Phuangsorn', '0898765432', 'student', 'user', '6731501036', 'School of Information Technology', 1, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- Buildings (Columns: building_id, code, name, total_floors, description)
INSERT INTO `buildings` (`building_id`, `code`, `name`, `total_floors`, `description`) VALUES
(1, 'BDA', 'Building A - Sunflower', 5, 'Main student residence near library'),
(2, 'BDB', 'Building B - Orchid', 4, 'Female-only dormitory with high security'),
(3, 'BDC', 'Building C - Rose', 6, 'Male dormitory with full sports access')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Room Types (Columns: room_type_id, name, capacity, description)
INSERT INTO `room_types` (`room_type_id`, `name`, `capacity`, `description`) VALUES
(1, 'Standard Single', 1, 'Single bed with private balcony'),
(2, 'Deluxe Double', 2, 'Twin beds with air conditioner'),
(3, 'VIP Suite', 4, 'Luxury suite with sofa and kitchen')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Rooms (Columns: room_id, building_id, room_type_id, room_number, floor, price_per_month, size_sqft, facing, grid_x, grid_y, is_active)
INSERT INTO `rooms` (`room_id`, `building_id`, `room_type_id`, `room_number`, `floor`, `price_per_month`, `size_sqft`, `facing`, `grid_x`, `grid_y`, `is_active`) VALUES
(1, 1, 1, '101', 1, 4500.00, 240.0, 'N', 1, 1, 1),
(2, 1, 2, '201', 2, 6500.00, 320.0, 'E', 2, 1, 1),
(3, 2, 1, '102', 1, 4800.00, 240.0, 'S', 1, 2, 1),
(4, 3, 3, '301', 3, 8500.00, 450.0, 'W', 3, 1, 1)
ON DUPLICATE KEY UPDATE `price_per_month` = VALUES(`price_per_month`);

-- Amenities (Columns: amenity_id, name, icon)
INSERT INTO `amenities` (`amenity_id`, `name`, `icon`) VALUES
(1, 'Air Conditioner', 'ac_unit'),
(2, 'High-speed Wi-Fi', 'wifi'),
(3, 'Water Heater', 'hot_tub'),
(4, 'Refrigerator', 'kitchen'),
(5, 'Balcony', 'balcony')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Room Amenities (Columns: room_id, amenity_id)
INSERT INTO `room_amenities` (`room_id`, `amenity_id`) VALUES
(1, 1), (1, 2),
(2, 1), (2, 2), (2, 3), (2, 4),
(4, 1), (4, 2), (4, 3), (4, 4), (4, 5)
ON DUPLICATE KEY UPDATE `amenity_id` = VALUES(`amenity_id`);

-- Room Images (Columns: image_id, room_id, image_url, sort_order)
INSERT INTO `room_images` (`image_id`, `room_id`, `image_url`, `sort_order`) VALUES
(1, 1, 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5', 1),
(2, 2, 'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf', 1)
ON DUPLICATE KEY UPDATE `image_url` = VALUES(`image_url`);

-- Semesters (Columns: semester_id, name, start_date, end_date, is_open)
INSERT INTO `semesters` (`semester_id`, `name`, `start_date`, `end_date`, `is_open`) VALUES
(1, '1/2026', '2026-08-01', '2026-12-20', 1),
(2, '2/2026', '2027-01-10', '2027-05-15', 0)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Addons (Columns: addon_id, name, description, price_per_month, is_active)
INSERT INTO `addons` (`addon_id`, `name`, `description`, `price_per_month`, `is_active`) VALUES
(1, 'Personal Parking Space', 'Reserved car parking near building entrance', 500.00, 1),
(2, 'Refrigerator Rental (6.5 cu.ft)', 'Energy-saving 2-door refrigerator', 300.00, 1),
(3, 'High-Speed Dedicated Fiber 500Mbps', 'Dedicated private Wi-Fi access', 250.00, 1)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
