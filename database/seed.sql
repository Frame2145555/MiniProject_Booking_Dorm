-- =====================================================================
-- DormSpace: Seed Data (Strictly matching dormspace.sql schema)
-- =====================================================================

USE `dormspace`;

SET FOREIGN_KEY_CHECKS = 0;

-- 1. USERS
INSERT INTO `users` (`user_id`, `email`, `password_hash`, `full_name`, `phone`, `user_type`, `role`, `student_id`, `faculty`, `is_active`, `last_login_at`, `created_at`, `updated_at`) VALUES
(1, 'admin@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordadmin$', 'System Administrator', '0812345678', 'general', 'admin', NULL, NULL, 1, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(2, 'student1@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordstudent$', 'Trinnakorn Phuangsorn', '0898765432', 'student', 'user', '6731501036', 'School of Information Technology', 1, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(3, 'student2@dormspace.ac.th', '$argon2id$v=19$m=65536,t=3,p=4$hashedpasswordstudent2$', 'Teerakorn Wongfan', '0811112222', 'student', 'user', '6731501047', 'School of Information Technology', 1, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- 2. BUILDINGS
INSERT INTO `buildings` (`building_id`, `code`, `name`, `total_floors`, `description`) VALUES
(1, 'BDA', 'Building A - Sunflower', 5, 'Main student residence near library'),
(2, 'BDB', 'Building B - Orchid', 4, 'Female-only dormitory with high security'),
(3, 'BDC', 'Building C - Rose', 6, 'Male dormitory with full sports access')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 3. ROOM TYPES
INSERT INTO `room_types` (`room_type_id`, `name`, `capacity`, `description`) VALUES
(1, 'Standard Single', 1, 'Single bed with private balcony'),
(2, 'Deluxe Double', 2, 'Twin beds with air conditioner'),
(3, 'VIP Suite', 4, 'Luxury suite with sofa and kitchen')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 4. ROOMS
INSERT INTO `rooms` (`room_id`, `building_id`, `room_type_id`, `room_number`, `floor`, `price_per_month`, `size_sqft`, `facing`, `grid_x`, `grid_y`, `is_active`) VALUES
(1, 1, 1, '101', 1, 4500.00, 240.0, 'N', 1, 1, 1),
(2, 1, 2, '201', 2, 6500.00, 320.0, 'E', 2, 1, 1),
(3, 2, 1, '102', 1, 4800.00, 240.0, 'S', 1, 2, 1),
(4, 3, 3, '301', 3, 8500.00, 450.0, 'W', 3, 1, 1)
ON DUPLICATE KEY UPDATE `price_per_month` = VALUES(`price_per_month`);

-- 5. AMENITIES
INSERT INTO `amenities` (`amenity_id`, `name`, `icon`) VALUES
(1, 'Air Conditioner', 'ac_unit'),
(2, 'High-speed Wi-Fi', 'wifi'),
(3, 'Water Heater', 'hot_tub'),
(4, 'Refrigerator', 'kitchen'),
(5, 'Balcony', 'balcony')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 6. ROOM AMENITIES
INSERT INTO `room_amenities` (`room_id`, `amenity_id`) VALUES
(1, 1), (1, 2),
(2, 1), (2, 2), (2, 3), (2, 4),
(3, 1), (3, 2), (3, 3),
(4, 1), (4, 2), (4, 3), (4, 4), (4, 5)
ON DUPLICATE KEY UPDATE `amenity_id` = VALUES(`amenity_id`);

-- 7. ROOM IMAGES
INSERT INTO `room_images` (`image_id`, `room_id`, `image_url`, `sort_order`) VALUES
(1, 1, 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5', 1),
(2, 2, 'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf', 1),
(3, 3, 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af', 1),
(4, 4, 'https://images.unsplash.com/photo-1616594039964-ae9021a400a0', 1)
ON DUPLICATE KEY UPDATE `image_url` = VALUES(`image_url`);

-- 8. SEMESTERS
INSERT INTO `semesters` (`semester_id`, `name`, `start_date`, `end_date`, `is_open`) VALUES
(1, '1/2026', '2026-08-01', '2026-12-20', 1),
(2, '2/2026', '2027-01-10', '2027-05-15', 0)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 9. ADDONS
INSERT INTO `addons` (`addon_id`, `name`, `description`, `price_per_month`, `is_active`) VALUES
(1, 'Personal Parking Space', 'Reserved car parking near building entrance', 500.00, 1),
(2, 'Refrigerator Rental (6.5 cu.ft)', 'Energy-saving 2-door refrigerator', 300.00, 1),
(3, 'High-Speed Dedicated Fiber 500Mbps', 'Dedicated private Wi-Fi access', 250.00, 1)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 10. ROOMMATE PREFERENCES
INSERT INTO `roommate_preferences` (`user_id`, `sleep_schedule`, `cleanliness`, `study_habit`, `updated_at`) VALUES
(2, 'night_owl', 'very_neat', 'quiet', CURRENT_TIMESTAMP()),
(3, 'early_bird', 'average', 'group_study', CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `sleep_schedule` = VALUES(`sleep_schedule`);

-- 11. BOOKINGS
INSERT INTO `bookings` (`booking_id`, `reference_code`, `user_id`, `room_id`, `semester_id`, `lease_months`, `move_in_date`, `move_out_date`, `monthly_rent`, `total_amount`, `deposit_amount`, `status`, `expires_at`, `created_at`, `updated_at`) VALUES
(1, 'BK2026110401', 2, 1, 1, 9, '2026-08-01', '2027-05-01', 4500.00, 40500.00, 200.00, 'checked_in', NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 12. BOOKING ADDONS
INSERT INTO `booking_addons` (`booking_id`, `addon_id`, `price_per_month`) VALUES
(1, 1, 500.00),
(1, 2, 300.00)
ON DUPLICATE KEY UPDATE `price_per_month` = VALUES(`price_per_month`);

-- 13. PAYMENTS
INSERT INTO `payments` (`payment_id`, `booking_id`, `amount`, `payment_type`, `method`, `status`, `transaction_ref`, `receipt_no`, `paid_at`, `created_at`) VALUES
(1, 1, 200.00, 'deposit', 'promptpay', 'paid', 'TXN9988776655', 'REC20260001', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 14. COMMENTS
INSERT INTO `comments` (`comment_id`, `user_id`, `building_id`, `room_id`, `parent_comment_id`, `content`, `rating`, `is_hidden`, `created_at`, `updated_at`) VALUES
(1, 2, 1, 1, NULL, 'ห้องสะอาด กว้างขวาง บรรยากาศเงียบสงบเหมาะแก่การเรียนครับ', 5, 0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
ON DUPLICATE KEY UPDATE `content` = VALUES(`content`);

SET FOREIGN_KEY_CHECKS = 1;
COMMIT;