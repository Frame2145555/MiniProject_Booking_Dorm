"use strict";
// ส่วนเสริมระบบเจ้าของหอ: แก้ไขข้อมูลห้อง (เลขห้อง / ประเภท / ราคา / ชั้น)
// (ไม่ได้แก้ Troutes/ของพี่ -- เพิ่มเป็นไฟล์แยกเหมือน owner_booking_routes.js)
//   ใช้งาน (server.js): app.use("/api/owner", require("./owner_room_routes")(db, auth));  // ก่อน ownerRoutes
//
//   PUT    /api/owner/rooms/:roomId   { roomNumber, roomType, price, floor? }
//   DELETE /api/owner/rooms/:roomId   ลบห้อง (ลบไม่ได้ถ้ามีผู้เช่าอยู่ หรือมีประวัติการจอง เพื่อไม่ให้ประวัติ/รายได้หาย)
//   (สถานะห้องแก้ที่ PATCH /api/owner/rooms/:roomId/status ของเดิม)
const express = require("express");

module.exports = (db, auth) => {
  const router = express.Router();
  const sellerOnly = auth.requireRole("seller");
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  router.put("/rooms/:roomId", sellerOnly, async (req, res) => {
    const roomId = Number(req.params.roomId);
    if (!Number.isInteger(roomId) || roomId <= 0) return fail(res, 400, "รหัสห้องไม่ถูกต้อง");

    const roomNumber = String(req.body?.roomNumber ?? "").trim();
    const roomType = String(req.body?.roomType ?? "").trim();
    const price = Number(req.body?.price);
    const hasFloor = req.body?.floor !== undefined && req.body?.floor !== null && req.body?.floor !== "";
    const floor = hasFloor ? Number(req.body.floor) : null;

    if (!roomNumber || roomNumber.length > 30) return fail(res, 400, "เลขห้องต้องไม่ว่างและยาวไม่เกิน 30 ตัวอักษร");
    if (!roomType || roomType.length > 100) return fail(res, 400, "กรุณาระบุประเภทห้อง");
    if (!Number.isInteger(price) || price <= 0) return fail(res, 400, "ค่าเช่าต้องเป็นจำนวนเต็มมากกว่า 0 บาท");
    if (hasFloor && (!Number.isInteger(floor) || floor < 1 || floor > 200)) return fail(res, 400, "ชั้นไม่ถูกต้อง");

    try {
      // แก้ได้เฉพาะห้องในหอของตัวเอง
      const [result] = await db.query(
        `UPDATE rooms r
           JOIN dorms d ON d.id = r.dorm_id
            SET r.room_number = ?, r.room_type = ?, r.price_per_month = ?, r.floor = COALESCE(?, r.floor)
          WHERE r.id = ? AND d.owner_id = ?`,
        [roomNumber, roomType, price, floor, roomId, req.user.id]
      );
      if (result.affectedRows === 0) return fail(res, 404, "ไม่พบห้องนี้ หรือไม่ใช่ห้องในหอของคุณ");

      const [rows] = await db.query(
        `SELECT id, dorm_id AS dormId, room_number AS roomNumber, room_type AS roomType,
                price_per_month AS price, floor, status
           FROM rooms WHERE id = ?`,
        [roomId]
      );
      res.json({ success: true, message: `แก้ไขห้อง ${roomNumber} เรียบร้อยแล้ว`, data: rows[0] });
    } catch (err) {
      if (err.code === "ER_DUP_ENTRY") return fail(res, 400, "เลขห้องนี้มีอยู่แล้วในหอพักนี้");
      console.error("Error in PUT /api/owner/rooms/:roomId:", err);
      fail(res, 500, "Internal server error");
    }
  });

  router.delete("/rooms/:roomId", sellerOnly, async (req, res) => {
    const roomId = Number(req.params.roomId);
    if (!Number.isInteger(roomId) || roomId <= 0) return fail(res, 400, "รหัสห้องไม่ถูกต้อง");
    try {
      // ลบได้เฉพาะห้องในหอของตัวเอง
      const [rows] = await db.query(
        `SELECT r.id, r.room_number AS roomNumber, r.status
           FROM rooms r JOIN dorms d ON d.id = r.dorm_id
          WHERE r.id = ? AND d.owner_id = ?`,
        [roomId, req.user.id]
      );
      const room = rows[0];
      if (!room) return fail(res, 404, "ไม่พบห้องนี้ หรือไม่ใช่ห้องในหอของคุณ");
      if (room.status === "occupied") {
        return fail(res, 409, `ห้อง ${room.roomNumber} มีผู้เช่าอยู่ ลบไม่ได้ (เปลี่ยนสถานะเป็น "ว่าง" ก่อน)`);
      }
      // มีประวัติการจอง = ลบไม่ได้ (ไม่งั้นประวัติและรายได้ของห้องนั้นจะหาย)
      const [[{ n }]] = await db.query("SELECT COUNT(*) AS n FROM bookings WHERE room_id = ?", [roomId]);
      if (Number(n) > 0) {
        return fail(
          res, 409,
          `ห้อง ${room.roomNumber} มีประวัติการจอง ${n} รายการ จึงลบไม่ได้ (ถ้าไม่ต้องการให้เช่า ให้ตั้งสถานะเป็น "ปรับปรุง" แทน)`
        );
      }
      await db.query("DELETE FROM rooms WHERE id = ?", [roomId]);
      res.json({ success: true, message: `ลบห้อง ${room.roomNumber} เรียบร้อยแล้ว` });
    } catch (err) {
      if (err.code === "ER_ROW_IS_REFERENCED_2") return fail(res, 409, "ห้องนี้มีข้อมูลอื่นผูกอยู่ จึงลบไม่ได้");
      console.error("Error in DELETE /api/owner/rooms/:roomId:", err);
      fail(res, 500, "Internal server error");
    }
  });

  return router;
};
