-- KYC schema compatible with the dorm_master dump.
-- Keep encrypted/private-storage columns for existing deployments and add
-- the application columns used by the current mobile flow.
CREATE TABLE IF NOT EXISTS kyc_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  seller_id BIGINT UNSIGNED NOT NULL,
  dorm_name VARCHAR(200) NOT NULL DEFAULT '',
  id_card_number_encrypted VARBINARY(512) NULL,
  id_card_number VARCHAR(13) NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  rejection_reason VARCHAR(1000) NULL,
  INDEX kyc_seller_status (seller_id, status, id),
  CONSTRAINT kyc_seller_fk FOREIGN KEY (seller_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS kyc_documents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kyc_request_id BIGINT UNSIGNED NOT NULL,
  document_type VARCHAR(50) NOT NULL,
  private_storage_key VARCHAR(500) NOT NULL DEFAULT '',
  file_data LONGTEXT NULL,
  watermark_text VARCHAR(255) NOT NULL DEFAULT '',
  uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX kyc_document_request (kyc_request_id),
  CONSTRAINT kyc_document_request_fk FOREIGN KEY (kyc_request_id) REFERENCES kyc_requests(id) ON DELETE CASCADE
);
