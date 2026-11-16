"use strict";

const express = require("express");

const REPORT_STATUSES = ["pending", "reviewed", "dismissed"];

module.exports = (db, auth) => {
  const tenantRouter = express.Router();
  const adminRouter = express.Router();

  // ผู้เช่าที่ login แล้วเท่านั้นที่ส่งรายงานได้
  tenantRouter.use(auth.requireRole("tenant"));
  tenantRouter.post("/", async (req, res) => {
    const dormId = Number(req.body?.dormId);
    const reason = typeof req.body?.reason === "string" ? req.body.reason.trim() : "";
    const description = typeof req.body?.description === "string" ? req.body.description.trim() : "";

    if (!Number.isInteger(dormId) || dormId <= 0) {
      return res.status(400).json({ success: false, message: "รหัสหอพักไม่ถูกต้อง" });
    }
    if (!reason || reason.length > 120) {
      return res.status(400).json({ success: false, message: "กรุณาเลือกเหตุผลในการรายงาน" });
    }
    if (description.length > 1000) {
      return res.status(400).json({ success: false, message: "รายละเอียดต้องไม่เกิน 1,000 ตัวอักษร" });
    }

    const [dorms] = await db.query("SELECT id FROM dorms WHERE id = ? LIMIT 1", [dormId]);
    if (!dorms.length) return res.status(404).json({ success: false, message: "ไม่พบหอพักนี้" });

    const [result] = await db.query(
      `INSERT INTO dorm_reports (dorm_id, reporter_id, reason, description, status)
       VALUES (?, ?, ?, ?, 'pending')`,
      [dormId, req.user.id, reason, description || null]
    );
    res.status(201).json({
      success: true,
      message: "ส่งรายงานให้ผู้ดูแลระบบแล้ว",
      data: { id: result.insertId, status: "pending" },
    });
  });

  // เฉพาะ Admin เท่านั้นที่อ่านและเปลี่ยนสถานะรายงานได้
  adminRouter.use(auth.requireRole("admin"));
  adminRouter.get("/", async (req, res) => {
    const status = (req.query.status || "all").toString();
    if (status !== "all" && !REPORT_STATUSES.includes(status)) {
      return res.status(400).json({ success: false, message: "status ไม่ถูกต้อง" });
    }
    const [rows] = await db.query(
      `SELECT r.id, r.dorm_id AS dormId, d.name AS dormName,
              r.reporter_id AS reporterId, reporter.full_name AS reporterName,
              reporter.email AS reporterEmail, d.owner_id AS ownerId,
              owner.full_name AS ownerName, r.reason, r.description,
              r.status, r.admin_note AS adminNote, r.created_at AS createdAt,
              r.reviewed_at AS reviewedAt, reviewer.full_name AS reviewedBy
         FROM dorm_reports r
         JOIN dorms d ON d.id = r.dorm_id
         JOIN users reporter ON reporter.id = r.reporter_id
         JOIN users owner ON owner.id = d.owner_id
         LEFT JOIN users reviewer ON reviewer.id = r.reviewed_by
        ${status === "all" ? "" : "WHERE r.status = ?"}
        ORDER BY (r.status = 'pending') DESC, r.created_at DESC, r.id DESC`,
      status === "all" ? [] : [status]
    );
    res.json({ success: true, count: rows.length, data: rows });
  });

  adminRouter.patch("/:id/status", async (req, res) => {
    const id = Number(req.params.id);
    const status = req.body?.status;
    const note = typeof req.body?.adminNote === "string" ? req.body.adminNote.trim().slice(0, 1000) : null;
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ success: false, message: "รหัสรายงานไม่ถูกต้อง" });
    }
    if (!REPORT_STATUSES.includes(status)) {
      return res.status(400).json({ success: false, message: "สถานะรายงานไม่ถูกต้อง" });
    }
    const [result] = await db.query(
      `UPDATE dorm_reports
          SET status = ?, admin_note = ?, reviewed_by = ?,
              reviewed_at = CASE WHEN ? = 'pending' THEN NULL ELSE NOW() END
        WHERE id = ?`,
      [status, note, req.user.id, status, id]
    );
    if (!result.affectedRows) {
      const [exists] = await db.query("SELECT id FROM dorm_reports WHERE id = ?", [id]);
      if (!exists.length) return res.status(404).json({ success: false, message: "ไม่พบรายงานนี้" });
    }
    res.json({ success: true, data: { id, status, adminNote: note } });
  });

  // สร้างตารางให้อัตโนมัติ หากยังไม่มี
  const ensureSchema = () => db.query(`
    CREATE TABLE IF NOT EXISTS dorm_reports (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      dorm_id BIGINT UNSIGNED NOT NULL,
      reporter_id BIGINT UNSIGNED NOT NULL,
      reason VARCHAR(120) NOT NULL,
      description TEXT NULL,
      status ENUM('pending','reviewed','dismissed') NOT NULL DEFAULT 'pending',
      admin_note TEXT NULL,
      reviewed_by BIGINT UNSIGNED NULL,
      reviewed_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      INDEX idx_dorm_reports_status_created (status, created_at),
      INDEX idx_dorm_reports_dorm (dorm_id),
      INDEX idx_dorm_reports_reporter (reporter_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  return { tenantRouter, adminRouter, ensureSchema };
};
