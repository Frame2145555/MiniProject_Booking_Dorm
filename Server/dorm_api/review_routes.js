"use strict";
const express = require("express");
module.exports = (db, auth) => {
  const tenantRouter = express.Router();
  const adminRouter = express.Router();
  const publicRouter = express.Router();
  tenantRouter.use(auth.requireRole("tenant"));
  tenantRouter.post("/", async (req, res) => {
    const dormId = Number(req.body?.dormId);
    const rating = Number(req.body?.rating);
    const comment = typeof req.body?.comment === "string" ? req.body.comment.trim() : "";
    if (!Number.isInteger(dormId) || dormId <= 0) return res.status(400).json({ success: false, message: "รหัสหอพักไม่ถูกต้อง" });
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return res.status(400).json({ success: false, message: "คะแนนต้องอยู่ระหว่าง 1 ถึง 5" });
    if (!comment || comment.length > 1500) return res.status(400).json({ success: false, message: "กรุณาเขียนรีวิวไม่เกิน 1,500 ตัวอักษร" });
    const [dorms] = await db.query("SELECT id FROM dorms WHERE id = ?", [dormId]);
    if (!dorms.length) return res.status(404).json({ success: false, message: "ไม่พบหอพักนี้" });
    try {
      const [result] = await db.query("INSERT INTO dorm_reviews (dorm_id, reviewer_id, rating, comment, status) VALUES (?, ?, ?, ?, 'visible')", [dormId, req.user.id, rating, comment]);
      return res.status(201).json({ success: true, data: { id: result.insertId, status: "visible" } });
    } catch (e) {
      if (e.code === "ER_DUP_ENTRY") return res.status(409).json({ success: false, message: "คุณรีวิวหอนี้ไปแล้ว" });
      throw e;
    }
  });
  publicRouter.get("/dorm/:dormId", async (req, res) => {
    const dormId = Number(req.params.dormId);
    if (!Number.isInteger(dormId) || dormId <= 0) return res.status(400).json({ success: false, message: "รหัสหอพักไม่ถูกต้อง" });
    const [rows] = await db.query(`SELECT r.id, r.dorm_id AS dormId, r.rating, r.comment, u.full_name AS author, r.created_at AS createdAt FROM dorm_reviews r JOIN users u ON u.id = r.reviewer_id WHERE r.dorm_id = ? AND r.status = 'visible' ORDER BY r.created_at DESC, r.id DESC`, [dormId]);
    res.json({ success: true, data: rows });
  });
  adminRouter.use(auth.requireRole("admin"));
  adminRouter.get("/", async (req, res) => {
    const status = String(req.query.status || "all");
    if (!['all', 'visible', 'hidden'].includes(status)) return res.status(400).json({ success: false, message: "status ไม่ถูกต้อง" });
    const [rows] = await db.query(`SELECT r.id, r.dorm_id AS dormId, d.name AS dormName, r.reviewer_id AS reviewerId, u.full_name AS author, u.email AS reviewerEmail, r.rating, r.comment, r.status, r.created_at AS createdAt, r.admin_note AS adminNote FROM dorm_reviews r JOIN dorms d ON d.id = r.dorm_id JOIN users u ON u.id = r.reviewer_id ${status === 'all' ? '' : 'WHERE r.status = ?'} ORDER BY r.created_at DESC, r.id DESC`, status === 'all' ? [] : [status]);
    res.json({ success: true, count: rows.length, data: rows });
  });
  adminRouter.patch("/:id/status", async (req, res) => {
    const id = Number(req.params.id), status = req.body?.status;
    const note = typeof req.body?.adminNote === 'string' ? req.body.adminNote.trim().slice(0, 1000) : null;
    if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ success: false, message: "รหัสรีวิวไม่ถูกต้อง" });
    if (!['visible', 'hidden'].includes(status)) return res.status(400).json({ success: false, message: "สถานะรีวิวไม่ถูกต้อง" });
    const [result] = await db.query("UPDATE dorm_reviews SET status = ?, admin_note = ?, moderated_by = ?, moderated_at = NOW() WHERE id = ?", [status, note, req.user.id, id]);
    if (!result.affectedRows) return res.status(404).json({ success: false, message: "ไม่พบรีวิวนี้" });
    res.json({ success: true, data: { id, status, adminNote: note } });
  });
  adminRouter.delete("/:id", async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ success: false, message: "รหัสรีวิวไม่ถูกต้อง" });
    const [result] = await db.query("DELETE FROM dorm_reviews WHERE id = ?", [id]);
    if (!result.affectedRows) return res.status(404).json({ success: false, message: "ไม่พบรีวิวนี้" });
    res.json({ success: true });
  });
  const ensureSchema = () => db.query(`CREATE TABLE IF NOT EXISTS dorm_reviews (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, dorm_id BIGINT UNSIGNED NOT NULL,
    reviewer_id BIGINT UNSIGNED NOT NULL, rating TINYINT UNSIGNED NOT NULL,
    comment VARCHAR(1500) NOT NULL, status ENUM('visible','hidden') NOT NULL DEFAULT 'visible',
    admin_note VARCHAR(1000) NULL, moderated_by BIGINT UNSIGNED NULL, moderated_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id),
    UNIQUE KEY uq_dorm_review_user (dorm_id, reviewer_id), KEY idx_dorm_reviews_status_created (status, created_at),
    CONSTRAINT dorm_reviews_dorm_fk FOREIGN KEY (dorm_id) REFERENCES dorms(id) ON DELETE CASCADE,
    CONSTRAINT dorm_reviews_reviewer_fk FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  return { tenantRouter, adminRouter, publicRouter, ensureSchema };
};
