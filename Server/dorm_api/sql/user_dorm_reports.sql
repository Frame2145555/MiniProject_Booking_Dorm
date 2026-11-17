CREATE TABLE IF NOT EXISTS user_dorm_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dorm_id BIGINT UNSIGNED NOT NULL,
  reporter_id BIGINT UNSIGNED NOT NULL,
  category ENUM('misleading','safety','pricing','inappropriate','unavailable','other') NOT NULL,
  description VARCHAR(1000) NOT NULL,
  status ENUM('pending','resolved','dismissed') NOT NULL DEFAULT 'pending',
  admin_id BIGINT UNSIGNED NULL,
  admin_note VARCHAR(500) NULL,
  reviewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY user_dorm_reports_status_created_idx (status, created_at),
  KEY user_dorm_reports_dorm_idx (dorm_id, status),
  KEY user_dorm_reports_reporter_idx (reporter_id, dorm_id, status),
  CONSTRAINT user_dorm_reports_dorm_fk FOREIGN KEY (dorm_id) REFERENCES dorms (id) ON DELETE CASCADE,
  CONSTRAINT user_dorm_reports_reporter_fk FOREIGN KEY (reporter_id) REFERENCES users (id),
  CONSTRAINT user_dorm_reports_admin_fk FOREIGN KEY (admin_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
