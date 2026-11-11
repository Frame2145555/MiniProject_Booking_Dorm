"use strict";
// ส่วนเสริมระบบเจ้าของหอ: ดูคำขอจอง + ตอบรับ/ปฏิเสธการจองและนัดดูห้อง
// (ระบบเจ้าของหอหลักอยู่ใน Troutes/ownerRoutes.js ของพี่ ไฟล์นี้เพิ่มเฉพาะที่ยังไม่มี ไม่ได้แก้ของพี่)
//   ใช้งาน (server.js): app.use("/api/owner", require("./owner_booking_routes")(db, auth));  // ก่อน ownerRoutes
//
//   GET   /api/owner/bookings                     คำขอจองห้องของหอเรา
//   PATCH /api/owner/bookings/:id/status          { status: confirmed|cancelled|completed }
//   PATCH /api/owner/visit-requests/:id/status    { status: accepted|declined|completed, ownerNote? }
const express = require("express");

const BOOKING_STATUSES = ["confirmed", "cancelled", "completed"];
const VISIT_STATUSES = ["accepted", "declined", "completed"];

module.exports = (db, auth) => {
  const router = express.Router();
  const sellerOnly = auth.requireRole("seller");
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  router.get("/bookings", sellerOnly, async (req, res) => {
    const [rows] = await db.query(
      `SELECT b.id, b.status, b.monthly_price AS monthlyPrice, b.starts_at AS startsAt, b.ends_at AS endsAt,
              b.created_at AS createdAt, d.id AS dormId, d.name AS dormName,
              r.id AS roomId, r.room_number AS roomNumber, r.room_type AS roomType,
              u.full_name AS tenantName, u.phone AS tenantPhone, u.email AS tenantEmail
         FROM bookings b
         JOIN rooms r ON r.id = b.room_id
         JOIN dorms d ON d.id = r.dorm_id
         JOIN users u ON u.id = b.tenant_id
        WHERE d.owner_id = ?
        ORDER BY b.created_at DESC, b.id DESC`,
      [req.user.id]
    );
    res.json({ success: true, count: rows.length, data: rows });
  });

  router.patch("/bookings/:id/status", sellerOnly, async (req, res) => {
    const status = req.body?.status;
    if (!BOOKING_STATUSES.includes(status)) return fail(res, 400, "status ต้องเป็น confirmed, cancelled หรือ completed");

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [[booking]] = await conn.query(
        `SELECT b.id, b.status, b.room_id FROM bookings b
           JOIN rooms r ON r.id = b.room_id JOIN dorms d ON d.id = r.dorm_id
          WHERE b.id = ? AND d.owner_id = ? FOR UPDATE`,
        [req.params.id, req.user.id]
      );
      if (!booking) {
        await conn.rollback();
        return fail(res, 404, "ไม่พบคำขอจองนี้");
      }
      if (status === "confirmed") {
        if (booking.status !== "pending") {
          await conn.rollback();
          return fail(res, 400, "ยืนยันได้เฉพาะคำขอที่รอดำเนินการ");
        }
        const [[room]] = await conn.query("SELECT status FROM rooms WHERE id = ? FOR UPDATE", [booking.room_id]);
        if (room.status !== "available") {
          await conn.rollback();
          return fail(res, 400, "ห้องนี้ไม่ว่างแล้ว");
        }
        await conn.query("UPDATE rooms SET status = 'occupied' WHERE id = ?", [booking.room_id]);
      }
      // ยกเลิก/จบสัญญาการจองที่ยืนยันแล้ว -> ห้องกลับมาว่าง
      if ((status === "cancelled" || status === "completed") && booking.status === "confirmed") {
        await conn.query("UPDATE rooms SET status = 'available' WHERE id = ?", [booking.room_id]);
      }
      await conn.query("UPDATE bookings SET status = ? WHERE id = ?", [status, booking.id]);
      await conn.commit();
      res.json({ success: true, data: { id: booking.id, status } });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  });

  router.patch("/visit-requests/:id/status", sellerOnly, async (req, res) => {
    const status = req.body?.status;
    if (!VISIT_STATUSES.includes(status)) return fail(res, 400, "status ต้องเป็น accepted, declined หรือ completed");
    const note = typeof req.body.ownerNote === "string" ? req.body.ownerNote.slice(0, 1000) : null;

    const [r] = await db.query(
      `UPDATE visit_requests vr JOIN dorms d ON d.id = vr.dorm_id
          SET vr.status = ?, vr.owner_note = COALESCE(?, vr.owner_note)
        WHERE vr.id = ? AND d.owner_id = ?`,
      [status, note, req.params.id, req.user.id]
    );
    if (r.affectedRows === 0) return fail(res, 404, "ไม่พบคำขอนัดนี้");
    res.json({ success: true, data: { id: Number(req.params.id), status } });
  });

  return router;
};
