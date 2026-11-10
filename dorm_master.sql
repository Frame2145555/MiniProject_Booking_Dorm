-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 10, 2026 at 03:05 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `dorm_master`
--

-- --------------------------------------------------------

--
-- Table structure for table `admin_audit_logs`
--

CREATE TABLE `admin_audit_logs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `admin_id` bigint(20) UNSIGNED NOT NULL,
  `action` varchar(100) NOT NULL,
  `target_type` varchar(50) NOT NULL,
  `target_id` bigint(20) UNSIGNED NOT NULL,
  `reason` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `amenities`
--

CREATE TABLE `amenities` (
  `id` smallint(5) UNSIGNED NOT NULL,
  `name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `amenities`
--

INSERT INTO `amenities` (`id`, `name`) VALUES
(2, 'Wi-Fi'),
(4, 'กล้องวงจรปิด'),
(3, 'ที่จอดรถ'),
(8, 'ฟิตเนส'),
(11, 'รปภ. 24ชม.'),
(5, 'ลิฟต์'),
(9, 'สระว่ายน้ำ'),
(10, 'เครื่องซักผ้า'),
(6, 'เครื่องทำน้ำอุ่น'),
(7, 'เลี้ยงสัตว์ได้'),
(1, 'แอร์');

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `room_id` bigint(20) UNSIGNED NOT NULL,
  `tenant_id` bigint(20) UNSIGNED NOT NULL,
  `status` enum('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending',
  `monthly_price` int(10) UNSIGNED NOT NULL,
  `starts_at` date DEFAULT NULL,
  `ends_at` date DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Table structure for table `conversations`
--

CREATE TABLE `conversations` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `tenant_id` bigint(20) UNSIGNED NOT NULL,
  `owner_id` bigint(20) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `conversations`
--

INSERT INTO `conversations` (`id`, `dorm_id`, `tenant_id`, `owner_id`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 2, '2026-11-09 22:03:59', '2026-11-09 23:09:16');

-- --------------------------------------------------------

--
-- Table structure for table `dorms`
--

CREATE TABLE `dorms` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `owner_id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(200) NOT NULL,
  `address` text NOT NULL,
  `description` text DEFAULT NULL,
  `price_min_month` int(10) UNSIGNED DEFAULT NULL,
  `price_max_month` int(10) UNSIGNED DEFAULT NULL,
  `cover_image_url` varchar(1000) DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `listing_status` enum('active','temporarily_closed','hidden') NOT NULL DEFAULT 'active',
  `approval_status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `submitted_at` datetime NOT NULL DEFAULT current_timestamp(),
  `reviewed_by` bigint(20) UNSIGNED DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `rejection_reason` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `dorms`
--

INSERT INTO `dorms` (`id`, `owner_id`, `name`, `address`, `description`, `price_min_month`, `price_max_month`, `cover_image_url`, `latitude`, `longitude`, `phone`, `listing_status`, `approval_status`, `submitted_at`, `reviewed_by`, `reviewed_at`, `rejection_reason`, `created_at`, `updated_at`) VALUES
(1, 2, 'หอทดสอบ', 'รามคำแหง 24', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'active', 'approved', '2026-11-09 21:24:09', NULL, NULL, NULL, '2026-11-09 21:24:09', '2026-11-09 21:24:09');

-- --------------------------------------------------------

--
-- Table structure for table `dorm_amenities`
--

CREATE TABLE `dorm_amenities` (
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `amenity_id` smallint(5) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dorm_documents`
--

CREATE TABLE `dorm_documents` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `document_type` enum('proof_of_right','business_registration','other') NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `private_storage_key` varchar(500) NOT NULL,
  `uploaded_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dorm_reports`
--

CREATE TABLE `dorm_reports` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `reporter_id` bigint(20) UNSIGNED NOT NULL,
  `reason` varchar(100) NOT NULL,
  `details` varchar(2000) DEFAULT NULL,
  `status` enum('pending','reviewing','resolved','dismissed') NOT NULL DEFAULT 'pending',
  `reviewed_by` bigint(20) UNSIGNED DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `admin_note` varchar(2000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dorm_view_events`
--

CREATE TABLE `dorm_view_events` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `viewer_id` bigint(20) UNSIGNED DEFAULT NULL,
  `viewed_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `favorites`
--

CREATE TABLE `favorites` (
  `tenant_id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kyc_documents`
--

CREATE TABLE `kyc_documents` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `kyc_request_id` bigint(20) UNSIGNED NOT NULL,
  `document_type` varchar(50) NOT NULL,
  `private_storage_key` varchar(500) NOT NULL,
  `uploaded_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kyc_requests`
--

CREATE TABLE `kyc_requests` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `seller_id` bigint(20) UNSIGNED NOT NULL,
  `dorm_name` varchar(200) NOT NULL,
  `id_card_number_encrypted` varbinary(512) DEFAULT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `submitted_at` datetime NOT NULL DEFAULT current_timestamp(),
  `reviewed_by` bigint(20) UNSIGNED DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `rejection_reason` varchar(1000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `conversation_id` bigint(20) UNSIGNED NOT NULL,
  `sender_id` bigint(20) UNSIGNED NOT NULL,
  `message_text` text NOT NULL,
  `sent_at` datetime NOT NULL DEFAULT current_timestamp(),
  `read_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `messages`
--

INSERT INTO `messages` (`id`, `conversation_id`, `sender_id`, `message_text`, `sent_at`, `read_at`) VALUES
(1, 1, 1, 'ทดสอบ 1794236639367', '2026-11-09 22:03:59', '2026-11-09 22:04:00'),
(2, 1, 1, 'ทดสอบ 1794237378389', '2026-11-09 22:16:18', '2026-11-09 22:16:19'),
(3, 1, 2, 'ดี', '2026-11-09 22:19:23', '2026-11-09 22:19:32'),
(4, 1, 1, 'ดีจเา', '2026-11-09 22:19:38', '2026-11-09 22:19:38'),
(5, 1, 2, 'สวัสดีครับ', '2026-11-09 22:20:03', '2026-11-09 22:20:04'),
(6, 1, 1, 'ครับ ปวดหัวครับ', '2026-11-09 22:20:18', '2026-11-09 22:20:18'),
(7, 1, 2, 'ระบบแม่งปวดหัวดีเนาะตัวฉันอีกคน', '2026-11-09 22:20:34', '2026-11-09 22:20:34'),
(8, 1, 1, 'จริง', '2026-11-09 22:20:39', '2026-11-09 22:20:39'),
(9, 1, 1, 'D จร้า', '2026-11-09 22:58:26', '2026-11-09 22:58:26'),
(10, 1, 2, 'D ครับ', '2026-11-09 22:58:30', '2026-11-09 22:58:31'),
(11, 1, 1, 'ส่ง test รอบท้าย', '2026-11-09 23:09:08', '2026-11-09 23:09:08'),
(12, 1, 2, 'อืม', '2026-11-09 23:09:16', '2026-11-09 23:09:16');

-- --------------------------------------------------------

--
-- Table structure for table `rooms`
--

CREATE TABLE `rooms` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `room_number` varchar(30) NOT NULL,
  `room_type` varchar(100) NOT NULL,
  `price_per_month` int(10) UNSIGNED NOT NULL,
  `floor` smallint(5) UNSIGNED NOT NULL DEFAULT 1,
  `status` enum('available','occupied','maintenance') NOT NULL DEFAULT 'available'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `email` varchar(254) NOT NULL,
  `password` varchar(255) NOT NULL DEFAULT '',
  `full_name` varchar(150) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `role` enum('tenant','seller','admin') NOT NULL DEFAULT 'tenant',
  `account_status` enum('active','suspended') NOT NULL DEFAULT 'active',
  `suspended_at` datetime DEFAULT NULL,
  `suspension_reason` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `full_name`, `phone`, `role`, `account_status`, `suspended_at`, `suspension_reason`, `created_at`) VALUES
(1, 'tenant@test.com', '$argon2id$v=19$m=19456,t=2,p=1$qkNgXYUCWc5PscSBN4dieg$ONYwjUnBwbBJJ0n9/SP3cndrAubeB+Rb0vxFBmOPfoo', 'ผู้เช่าทดสอบ', NULL, 'tenant', 'active', NULL, NULL, '2026-11-09 21:24:09'),
(2, 'seller@test.com', '$argon2id$v=19$m=19456,t=2,p=1$qkNgXYUCWc5PscSBN4dieg$ONYwjUnBwbBJJ0n9/SP3cndrAubeB+Rb0vxFBmOPfoo', 'เจ้าของหอทดสอบ', NULL, 'seller', 'active', NULL, NULL, '2026-11-09 21:24:09'),
(3, 'other@test.com', '$argon2id$v=19$m=19456,t=2,p=1$qkNgXYUCWc5PscSBN4dieg$ONYwjUnBwbBJJ0n9/SP3cndrAubeB+Rb0vxFBmOPfoo', 'คนนอก', NULL, 'tenant', 'active', NULL, NULL, '2026-11-09 21:24:09');

-- --------------------------------------------------------

--
-- Table structure for table `visit_requests`
--

CREATE TABLE `visit_requests` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `dorm_id` bigint(20) UNSIGNED NOT NULL,
  `room_id` bigint(20) UNSIGNED DEFAULT NULL,
  `tenant_id` bigint(20) UNSIGNED NOT NULL,
  `requested_at` datetime NOT NULL,
  `status` enum('pending','accepted','declined','cancelled','completed') NOT NULL DEFAULT 'pending',
  `tenant_note` varchar(1000) DEFAULT NULL,
  `owner_note` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_audit_logs`
--
ALTER TABLE `admin_audit_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `admin_audit_target_idx` (`target_type`,`target_id`,`created_at`),
  ADD KEY `admin_audit_admin_date_idx` (`admin_id`,`created_at`);

--
-- Indexes for table `amenities`
--
ALTER TABLE `amenities`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `amenities_name_uq` (`name`);

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `bookings_room_status_idx` (`room_id`,`status`),
  ADD KEY `bookings_tenant_created_idx` (`tenant_id`,`created_at`);

--
-- Indexes for table `conversations`
--
ALTER TABLE `conversations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `conversations_dorm_tenant_owner_uq` (`dorm_id`,`tenant_id`,`owner_id`),
  ADD KEY `conversations_owner_updated_idx` (`owner_id`,`updated_at`),
  ADD KEY `conversations_tenant_updated_idx` (`tenant_id`,`updated_at`);

--
-- Indexes for table `dorms`
--
ALTER TABLE `dorms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `dorms_owner_id_idx` (`owner_id`),
  ADD KEY `dorms_approval_status_idx` (`approval_status`),
  ADD KEY `dorms_reviewed_by_fk` (`reviewed_by`);

--
-- Indexes for table `dorm_amenities`
--
ALTER TABLE `dorm_amenities`
  ADD PRIMARY KEY (`dorm_id`,`amenity_id`),
  ADD KEY `dorm_amenities_amenity_idx` (`amenity_id`);

--
-- Indexes for table `dorm_documents`
--
ALTER TABLE `dorm_documents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `dorm_documents_dorm_type_idx` (`dorm_id`,`document_type`);

--
-- Indexes for table `dorm_reports`
--
ALTER TABLE `dorm_reports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `dorm_reports_status_date_idx` (`status`,`created_at`),
  ADD KEY `dorm_reports_dorm_idx` (`dorm_id`,`created_at`),
  ADD KEY `dorm_reports_reporter_fk` (`reporter_id`),
  ADD KEY `dorm_reports_reviewer_fk` (`reviewed_by`);

--
-- Indexes for table `dorm_view_events`
--
ALTER TABLE `dorm_view_events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `dorm_view_events_dorm_date_idx` (`dorm_id`,`viewed_at`),
  ADD KEY `dorm_view_events_viewer_idx` (`viewer_id`);

--
-- Indexes for table `favorites`
--
ALTER TABLE `favorites`
  ADD PRIMARY KEY (`tenant_id`,`dorm_id`),
  ADD KEY `favorites_dorm_idx` (`dorm_id`);

--
-- Indexes for table `kyc_documents`
--
ALTER TABLE `kyc_documents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `kyc_documents_request_idx` (`kyc_request_id`);

--
-- Indexes for table `kyc_requests`
--
ALTER TABLE `kyc_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `kyc_status_submitted_idx` (`status`,`submitted_at`),
  ADD KEY `kyc_seller_id_idx` (`seller_id`),
  ADD KEY `kyc_reviewer_fk` (`reviewed_by`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `messages_conversation_sent_idx` (`conversation_id`,`sent_at`),
  ADD KEY `messages_sender_fk` (`sender_id`);

--
-- Indexes for table `rooms`
--
ALTER TABLE `rooms`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `rooms_dorm_number_uq` (`dorm_id`,`room_number`),
  ADD KEY `rooms_dorm_status_idx` (`dorm_id`,`status`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_uq` (`email`);

--
-- Indexes for table `visit_requests`
--
ALTER TABLE `visit_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `visit_requests_dorm_status_date_idx` (`dorm_id`,`status`,`requested_at`),
  ADD KEY `visit_requests_tenant_date_idx` (`tenant_id`,`created_at`),
  ADD KEY `visit_requests_room_fk` (`room_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `admin_audit_logs`
--
ALTER TABLE `admin_audit_logs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `amenities`
--
ALTER TABLE `amenities`
  MODIFY `id` smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `conversations`
--
ALTER TABLE `conversations`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `dorms`
--
ALTER TABLE `dorms`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dorm_documents`
--
ALTER TABLE `dorm_documents`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dorm_reports`
--
ALTER TABLE `dorm_reports`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dorm_view_events`
--
ALTER TABLE `dorm_view_events`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `kyc_documents`
--
ALTER TABLE `kyc_documents`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `kyc_requests`
--
ALTER TABLE `kyc_requests`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `rooms`
--
ALTER TABLE `rooms`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `visit_requests`
--
ALTER TABLE `visit_requests`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admin_audit_logs`
--
ALTER TABLE `admin_audit_logs`
  ADD CONSTRAINT `admin_audit_admin_fk` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_room_fk` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `bookings_tenant_fk` FOREIGN KEY (`tenant_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `conversations`
--
ALTER TABLE `conversations`
  ADD CONSTRAINT `conversations_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `conversations_owner_fk` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `conversations_tenant_fk` FOREIGN KEY (`tenant_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `dorms`
--
ALTER TABLE `dorms`
  ADD CONSTRAINT `dorms_owner_fk` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `dorms_reviewed_by_fk` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `dorm_amenities`
--
ALTER TABLE `dorm_amenities`
  ADD CONSTRAINT `dorm_amenities_amenity_fk` FOREIGN KEY (`amenity_id`) REFERENCES `amenities` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `dorm_amenities_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `dorm_documents`
--
ALTER TABLE `dorm_documents`
  ADD CONSTRAINT `dorm_documents_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `dorm_reports`
--
ALTER TABLE `dorm_reports`
  ADD CONSTRAINT `dorm_reports_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `dorm_reports_reporter_fk` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `dorm_reports_reviewer_fk` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `dorm_view_events`
--
ALTER TABLE `dorm_view_events`
  ADD CONSTRAINT `dorm_view_events_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `dorm_view_events_viewer_fk` FOREIGN KEY (`viewer_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `favorites_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `favorites_tenant_fk` FOREIGN KEY (`tenant_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `kyc_documents`
--
ALTER TABLE `kyc_documents`
  ADD CONSTRAINT `kyc_documents_request_fk` FOREIGN KEY (`kyc_request_id`) REFERENCES `kyc_requests` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `kyc_requests`
--
ALTER TABLE `kyc_requests`
  ADD CONSTRAINT `kyc_reviewer_fk` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `kyc_seller_fk` FOREIGN KEY (`seller_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `messages`
--
ALTER TABLE `messages`
  ADD CONSTRAINT `messages_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `messages_sender_fk` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `rooms`
--
ALTER TABLE `rooms`
  ADD CONSTRAINT `rooms_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `visit_requests`
--
ALTER TABLE `visit_requests`
  ADD CONSTRAINT `visit_requests_dorm_fk` FOREIGN KEY (`dorm_id`) REFERENCES `dorms` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `visit_requests_room_fk` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `visit_requests_tenant_fk` FOREIGN KEY (`tenant_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
