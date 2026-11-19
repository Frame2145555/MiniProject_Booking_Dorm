"use strict";
// ระบบแจ้งเตือน (กระดิ่ง) ใช้ได้ทุกบทบาท -- เก็บในตาราง user_notifications (sql/user_notifications.sql)
// ตารางเดียวกับที่ระบบรายงานใช้แจ้งผู้เช่า (/api/tenant/notifications ของเดิมยังใช้ได้เหมือนเดิม)
//   ใช้งาน (server.js): app.use("/api/notifications", require("./routes/notificationRoutes")(db, auth));
//
//   GET   /api/notifications            รายการแจ้งเตือนของฉัน (ใหม่สุดก่อน 50 รายการ) + จำนวนที่ยังไม่อ่าน
//   POST  /api/notifications/read-all   ทำเครื่องหมายอ่านทั้งหมด
//   PATCH /api/notifications/:id/read   ทำเครื่องหมายอ่านรายการเดียว
//
// ส่งแจ้งเตือนจากโค้ดฝั่ง server ด้วย notify():
//   const { notify } = require("./notificationRoutes");
//   await notify(db, { userId, type: "deposit_approved", title, body });
const express = require("express");

/** เพิ่มแจ้งเตือนให้ผู้ใช้ 1 คน -- ถ้าเพิ่มไม่ได้จะแค่ log ไม่ทำให้เรื่องหลัก (เช่น การอนุมัติ) พัง */
const notify = async (db, { userId, type, title, body }) => {
  try {
    await db.query(
      "INSERT INTO user_notifications (user_id, type, title, message) VALUES (?, ?, ?, ?)",
      [userId, String(type).slice(0, 50), String(title).slice(0, 160), String(body)]
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

  router.get("/", async (req, res) => {
    try {
      const [rows] = await db.query(
        `SELECT id, type, title, message, related_report_id AS relatedId,
                is_read AS isRead, created_at AS createdAt
           FROM user_notifications WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 50`,
        [req.user.id]
      );
      const [[{ unread }]] = await db.query(
        "SELECT COUNT(*) AS unread FROM user_notifications WHERE user_id = ? AND is_read = 0",
        [req.user.id]
      );
      res.json({
        success: true,
        unread: Number(unread),
        // body = ชื่อเดิมที่แอปฝั่งเจ้าของหอใช้, message = ชื่อคอลัมน์ในตาราง
        data: rows.map((r) => ({ ...r, body: r.message, isRead: !!r.isRead })),
      });
    } catch (err) {
      console.error("GET /api/notifications:", err);
      fail(res, 500, "Internal server error");
    }
  });

  router.post("/read-all", async (req, res) => {
    try {
      const [r] = await db.query(
        "UPDATE user_notifications SET is_read = 1, read_at = COALESCE(read_at, NOW()) WHERE user_id = ? AND is_read = 0",
        [req.user.id]
      );
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
      const [r] = await db.query(
        "UPDATE user_notifications SET is_read = 1, read_at = COALESCE(read_at, NOW()) WHERE id = ? AND user_id = ?",
        [id, req.user.id]
      );
      if (r.affectedRows === 0) {
        const [[own]] = await db.query("SELECT id FROM user_notifications WHERE id = ? AND user_id = ?", [id, req.user.id]);
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
