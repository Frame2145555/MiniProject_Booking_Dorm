CREATE TABLE IF NOT EXISTS dorm_reviews (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dorm_id    BIGINT UNSIGNED NOT NULL,
  reviewer_id BIGINT UNSIGNED NOT NULL,
  rating     TINYINT UNSIGNED NOT NULL,
  comment    VARCHAR(1000) NOT NULL,
  status     ENUM('visible', 'hidden') NOT NULL DEFAULT 'visible',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY dorm_reviews_reviewer_dorm_uq (reviewer_id, dorm_id),
  KEY dorm_reviews_dorm_status_idx (dorm_id, status, created_at),
  CONSTRAINT dorm_reviews_dorm_fk FOREIGN KEY (dorm_id) REFERENCES dorms (id) ON DELETE CASCADE,
  CONSTRAINT dorm_reviews_reviewer_fk FOREIGN KEY (reviewer_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT dorm_reviews_rating_chk CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
