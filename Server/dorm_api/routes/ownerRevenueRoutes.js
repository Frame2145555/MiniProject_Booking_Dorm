"use strict";
// ส่วนเสริมระบบเจ้าของหอ: ดูรายได้ (Revenue) จากการจองห้องแบบชำระเงิน
// (ไม่ได้แก้ routes/ownerRoutes.js ของพี่ -- เพิ่มเป็นไฟล์แยกเหมือน routes/ownerBookingRoutes.js)
//   ใช้งาน (server.js): app.use("/api/owner", require("./routes/ownerRevenueRoutes")(db, auth));  // ก่อน ownerRoutes
//
//   GET /api/owner/revenue?year=2026
//
// นิยาม
//   รายได้      = booking_payments.status = 'completed' (เจ้าของหอกดยืนยันการจองแล้ว)
//                 ยอด = paid_amount (ยอดที่แอดมินตรวจแล้ว) ถ้าไม่มีใช้ amount
//                 เดือนที่นับ = วันที่เจ้าของหอกดยืนยัน (owner_reviewed_at)
//   รอยืนยัน    = status = 'approved' (แอดมินตรวจเงินแล้ว รอเจ้าของหอกดยืนยัน) ยังไม่นับเป็นรายได้
//   ไม่รวมการจองแบบเก่า (ตาราง bookings ที่ไม่มีแถวใน booking_payments) เพราะไม่มียอดเงินที่จ่ายจริง
const express = require("express");

const PLAN_LABEL = { week: "1 อาทิตย์", month: "1 เดือน", term: "1 เทอม (4 เดือน)", year: "1 ปี" };
const AMOUNT = "COALESCE(p.paid_amount, p.amount)";
const num = (v) => Number(v || 0);

module.exports = (db, auth) => {
  const router = express.Router();
  const sellerOnly = auth.requireRole("seller");
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  router.get("/revenue", sellerOnly, async (req, res) => {
    const nowYear = new Date().getFullYear();
    const year = req.query.year === undefined ? nowYear : Number(req.query.year);
    if (!Number.isInteger(year) || year < 2000 || year > 2100) return fail(res, 400, "ปีไม่ถูกต้อง");
    const ownerId = req.user.id;

    try {
      const [[sum]] = await db.query(
        `SELECT COALESCE(SUM(CASE WHEN p.status = 'completed' THEN ${AMOUNT} END), 0) AS totalRevenue,
                COALESCE(SUM(p.status = 'completed'), 0)                              AS completedCount,
                COALESCE(SUM(CASE WHEN p.status = 'approved' THEN ${AMOUNT} END), 0)  AS pendingAmount,
                COALESCE(SUM(p.status = 'approved'), 0)                               AS pendingCount
           FROM booking_payments p
           JOIN dorms d ON d.id = p.dorm_id
          WHERE d.owner_id = ?`,
        [ownerId]
      );

      const [monthRows] = await db.query(
        `SELECT MONTH(p.owner_reviewed_at) AS month, SUM(${AMOUNT}) AS revenue, COUNT(*) AS count
           FROM booking_payments p
           JOIN dorms d ON d.id = p.dorm_id
          WHERE d.owner_id = ? AND p.status = 'completed' AND YEAR(p.owner_reviewed_at) = ?
          GROUP BY MONTH(p.owner_reviewed_at)`,
        [ownerId, year]
      );
      const byMonth = Array.from({ length: 12 }, (_, i) => ({ month: i + 1, revenue: 0, count: 0 }));
      for (const r of monthRows) {
        const m = byMonth[Number(r.month) - 1];
        if (m) { m.revenue = num(r.revenue); m.count = num(r.count); }
      }

      const [dormRows] = await db.query(
        `SELECT d.id AS dormId, d.name AS dormName, COALESCE(SUM(${AMOUNT}), 0) AS revenue, COUNT(p.id) AS count
           FROM dorms d
           LEFT JOIN booking_payments p
                  ON p.dorm_id = d.id AND p.status = 'completed' AND YEAR(p.owner_reviewed_at) = ?
          WHERE d.owner_id = ?
          GROUP BY d.id, d.name
          ORDER BY revenue DESC, d.id`,
        [year, ownerId]
      );

      const [recentRows] = await db.query(
        `SELECT p.id, d.name AS dormName, r.room_number AS roomNumber, u.full_name AS tenantName,
                p.plan, ${AMOUNT} AS amount, p.owner_reviewed_at AS confirmedAt
           FROM booking_payments p
           JOIN dorms d ON d.id = p.dorm_id
           JOIN rooms r ON r.id = p.room_id
           JOIN users u ON u.id = p.tenant_id
          WHERE d.owner_id = ? AND p.status = 'completed'
          ORDER BY p.owner_reviewed_at DESC, p.id DESC
          LIMIT 10`,
        [ownerId]
      );

      const [yearRows] = await db.query(
        `SELECT DISTINCT YEAR(p.owner_reviewed_at) AS y
           FROM booking_payments p
           JOIN dorms d ON d.id = p.dorm_id
          WHERE d.owner_id = ? AND p.status = 'completed' AND p.owner_reviewed_at IS NOT NULL
          ORDER BY y DESC`,
        [ownerId]
      );
      const years = new Set(yearRows.map((r) => Number(r.y)));
      years.add(nowYear);
      years.add(year);

      const yearRevenue = byMonth.reduce((s, m) => s + m.revenue, 0);
      const yearCount = byMonth.reduce((s, m) => s + m.count, 0);

      res.json({
        success: true,
        data: {
          year,
          years: [...years].sort((a, b) => b - a),
          totalRevenue: num(sum.totalRevenue),
          completedCount: num(sum.completedCount),
          pendingAmount: num(sum.pendingAmount),
          pendingCount: num(sum.pendingCount),
          yearRevenue,
          yearCount,
          byMonth,
          byDorm: dormRows.map((r) => ({
            dormId: r.dormId, dormName: r.dormName, revenue: num(r.revenue), count: num(r.count),
          })),
          recent: recentRows.map((r) => ({
            id: r.id, dormName: r.dormName, roomNumber: r.roomNumber, tenantName: r.tenantName,
            plan: r.plan, planLabel: PLAN_LABEL[r.plan] || r.plan, amount: num(r.amount), confirmedAt: r.confirmedAt,
          })),
        },
      });
    } catch (err) {
      console.error("Error in GET /api/owner/revenue:", err);
      fail(res, 500, "Internal server error");
    }
  });

  return router;
};
