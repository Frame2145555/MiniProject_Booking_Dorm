"use strict";
// ระบบแจ้งเตือน (กระดิ่ง) -- เก็บในตาราง notifications ของฐานข้อมูลจริง
//   ใช้งาน (server.js): app.use("/api/notifications", require("./notification_routes")(db, auth));
//
//   GET   /api/notifications            รายการแจ้งเตือนของฉัน (ใหม่สุดก่อน 50 รายการ) + จำนวนที่ยังไม่อ่าน
//   POST  /api/notifications/read-all   ทำเครื่องหมายอ่านทั้งหมด
//   PATCH /api/notifications/:id/read   ทำเครื่องหมายอ่านรายการเดียว
//
// ส่งแจ้งเตือนจากโค้ดฝั่ง server ด้วย notify():
//   const { notify } = require("./notification_routes");
//   await notify(db, { userId, type: "deposit_approved", title, body, refId });
const express = require("express");

const SCHEMA = `
CREATE TABLE IF NOT EXISTS notifications (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,                 -- คนที่ได้รับแจ้งเตือน (users.id)
  type       VARCHAR(40)  NOT NULL,                    -- เช่น deposit_approved (ค่ามัดจำผ่านการตรวจจากแอดมิน)
  title      VARCHAR(200) NOT NULL,
  body       VARCHAR(1000) NOT NULL,
  ref_id     BIGINT UNSIGNED NULL,                     -- อ้างอิงรายการที่เกี่ยวข้อง (เช่น booking_payments.id)
  is_read    TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY notifications_user_idx (user_id, is_read, created_at),
  CONSTRAINT notifications_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`;

/** สร้างตาราง (ถ้ายังไม่มี) -- รับ pool แบบ callback (เหมือน bookingPayment.ensureSchema) หรือ promise ก็ได้ */
const ensureSchema = async (pool) => {
  const p = typeof pool.promise === "function" ? pool.promise() : pool;
  await p.query(SCHEMA);
};

const ensured = new WeakSet();
const ensureOnce = async (db) => {
  if (ensured.has(db)) return;
  await ensureSchema(db);
  ensured.add(db);
};

/** เพิ่มแจ้งเตือนให้ผู้ใช้ 1 คน -- ถ้าเพิ่มไม่ได้จะแค่ log ไม่ทำให้เรื่องหลัก (เช่น การอนุมัติ) พัง */
const notify = async (db, { userId, type, title, body, refId = null }) => {
  try {
    await ensureOnce(db);
    await db.query(
      "INSERT INTO notifications (user_id, type, title, body, ref_id) VALUES (?, ?, ?, ?, ?)",
      [userId, String(type).slice(0, 40), String(title).slice(0, 200), String(body).slice(0, 1000), refId]
    );
    return true;
  } catch (err) {
    console.error("notify ไม่สำเร็จ:", err.message);
    return false;
  }
};

module.exports = (db, auth) => {
  const router = express.Router();
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  router.use(auth.verifyToken);
  router.use(async (req, res, next) => {
    try { await ensureOnce(db); next(); } catch (err) {
      console.error("notifications schema:", err.message);
      fail(res, 500, "Internal server error");
    }
  });

  router.get("/", async (req, res) => {
    try {
      const [rows] = await db.query(
        `SELECT id, type, title, body, ref_id AS refId, is_read AS isRead, created_at AS createdAt
           FROM notifications WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 50`,
        [req.user.id]
      );
      const [[{ unread }]] = await db.query(
        "SELECT COUNT(*) AS unread FROM notifications WHERE user_id = ? AND is_read = 0",
        [req.user.id]
      );
      res.json({
        success: true,
        unread: Number(unread),
        data: rows.map((r) => ({ ...r, isRead: !!r.isRead })),
      });
    } catch (err) {
      console.error("GET /api/notifications:", err);
      fail(res, 500, "Internal server error");
    }
  });

  router.post("/read-all", async (req, res) => {
    try {
      const [r] = await db.query("UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0", [req.user.id]);
      res.json({ success: true, updated: r.affectedRows });
    } catch (err) {
      console.error("POST /api/notifications/read-all:", err);
      fail(res, 500, "Internal server error");
    }
  });

  router.patch("/:id/read", async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) return fail(res, 400, "รหัสแจ้งเตือนไม่ถูกต้อง");
    try {
      // อ่านได้เฉพาะของตัวเอง
      const [r] = await db.query("UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?", [id, req.user.id]);
      if (r.affectedRows === 0) {
        const [[own]] = await db.query("SELECT id FROM notifications WHERE id = ? AND user_id = ?", [id, req.user.id]);
        if (!own) return fail(res, 404, "ไม่พบการแจ้งเตือนนี้");
      }
      res.json({ success: true });
    } catch (err) {
      console.error("PATCH /api/notifications/:id/read:", err);
      fail(res, 500, "Internal server error");
    }
  });

  return router;
};

module.exports.notify = notify;
module.exports.ensureSchema = ensureSchema;
