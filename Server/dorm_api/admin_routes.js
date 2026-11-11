"use strict";
// ระบบแอดมิน: อนุมัติ/ปฏิเสธหอพัก + ระงับ/ปลดระงับบัญชี   (ต้อง login ด้วยบัญชี role = admin)
//   ใช้งาน (server.js): app.use("/api/admin", require("./admin_routes")(db, auth));
//
//   GET   /api/admin/overview                 ตัวเลขภาพรวม
//   GET   /api/admin/sellers                  รายชื่อเจ้าของหอ + หอ/ห้อง/ยอดวิว/การจอง
//   PATCH /api/admin/users/:id/status         { suspend: true|false, reason? }
//   GET   /api/admin/dorms?status=pending     หอตามสถานะ (pending|approved|rejected|all)
//   PATCH /api/admin/dorms/:id/approval       { approve: true|false, reason? }
const express = require("express");

const DORM_STATUSES = ["pending", "approved", "rejected"];

module.exports = (db, auth) => {
  const router = express.Router();
  router.use(auth.requireRole("admin"));

  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  const audit = (adminId, action, targetType, targetId, reason) =>
    db.query(
      "INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, reason) VALUES (?, ?, ?, ?, ?)",
      [adminId, action, targetType, targetId, reason || null]
    );

  const toId = (raw) => {
    const id = Number(raw);
    return Number.isInteger(id) && id > 0 ? id : null;
  };

  router.get("/overview", async (req, res) => {
    const [[row]] = await db.query(`
      SELECT
        (SELECT COUNT(*) FROM users WHERE role = 'seller')                    AS sellers,
        (SELECT COUNT(*) FROM users WHERE role = 'tenant')                    AS tenants,
        (SELECT COUNT(*) FROM users WHERE account_status = 'suspended')       AS suspended,
        (SELECT COUNT(*) FROM dorms WHERE approval_status = 'pending')        AS pending_dorms,
        (SELECT COUNT(*) FROM dorms WHERE approval_status = 'approved')       AS approved_dorms,
        (SELECT COUNT(*) FROM dorm_view_events)                               AS total_views,
        (SELECT COUNT(*) FROM bookings)                                       AS bookings`);
    res.json({ success: true, data: row });
  });

  router.get("/sellers", async (req, res) => {
    const [rows] = await db.query(`
      SELECT u.id, u.email, u.full_name AS name, u.phone, u.account_status AS status,
             u.created_at AS joined,
             (SELECT d.id   FROM dorms d WHERE d.owner_id = u.id ORDER BY d.id LIMIT 1) AS dormId,
             (SELECT d.name FROM dorms d WHERE d.owner_id = u.id ORDER BY d.id LIMIT 1) AS dorm,
             (SELECT COUNT(*) FROM dorms d WHERE d.owner_id = u.id)                      AS dorms,
             (SELECT COUNT(*) FROM rooms r JOIN dorms d ON d.id = r.dorm_id
               WHERE d.owner_id = u.id)                                                  AS rooms,
             (SELECT COUNT(*) FROM bookings b JOIN rooms r ON r.id = b.room_id
               JOIN dorms d ON d.id = r.dorm_id WHERE d.owner_id = u.id)                 AS bookings,
             (SELECT COUNT(*) FROM dorm_view_events v JOIN dorms d ON d.id = v.dorm_id
               WHERE d.owner_id = u.id)                                                  AS views,
             (SELECT COUNT(*) FROM dorm_reports p JOIN dorms d ON d.id = p.dorm_id
               WHERE d.owner_id = u.id)                                                  AS reports,
             (SELECT k.status FROM kyc_requests k WHERE k.seller_id = u.id
               ORDER BY k.id DESC LIMIT 1)                                               AS kyc
        FROM users u
       WHERE u.role = 'seller'
       ORDER BY u.id`);
    res.json({ success: true, count: rows.length, data: rows });
  });

  router.patch("/users/:id/status", async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
    if (typeof req.body?.suspend !== "boolean") return fail(res, 400, "ต้องส่ง suspend เป็น true หรือ false");
    if (id === req.user.id) return fail(res, 400, "ระงับบัญชีตัวเองไม่ได้");
    const suspend = req.body.suspend;
    const reason = typeof req.body.reason === "string" ? req.body.reason.slice(0, 1000) : null;

    const [r] = await db.query(
      `UPDATE users SET account_status = ?, suspended_at = ?, suspension_reason = ?
        WHERE id = ? AND role <> 'admin'`,
      [suspend ? "suspended" : "active", suspend ? new Date() : null, suspend ? reason : null, id]
    );
    if (r.affectedRows === 0) return fail(res, 404, "ไม่พบบัญชีนี้ (หรือเป็นบัญชีแอดมิน)");
    await audit(req.user.id, suspend ? "suspend_user" : "unsuspend_user", "user", id, reason);
    res.json({ success: true, data: { id, status: suspend ? "suspended" : "active" } });
  });

  router.get("/dorms", async (req, res) => {
    const status = (req.query.status || "pending").toString();
    if (status !== "all" && !DORM_STATUSES.includes(status)) {
      return fail(res, 400, "status ต้องเป็น pending, approved, rejected หรือ all");
    }
    const [dorms] = await db.query(
      `SELECT d.id, d.owner_id AS sellerId, u.full_name AS sellerName, u.email AS sellerEmail,
              d.name AS dormName, d.address AS location, d.phone, d.description,
              d.price_min_month AS priceMin, d.price_max_month AS priceMax,
              d.cover_image_url AS imageUrl, d.latitude, d.longitude,
              d.listing_status AS listingStatus, d.approval_status AS status,
              d.submitted_at AS submittedAt, d.reviewed_at AS reviewedAt, d.rejection_reason AS rejectionReason,
              (SELECT COUNT(*) FROM dorm_view_events v WHERE v.dorm_id = d.id) AS views,
              (SELECT COUNT(*) FROM rooms r WHERE r.dorm_id = d.id)            AS rooms
         FROM dorms d JOIN users u ON u.id = d.owner_id
        ${status === "all" ? "" : "WHERE d.approval_status = ?"}
        ORDER BY d.submitted_at DESC, d.id DESC`,
      status === "all" ? [] : [status]
    );
    if (dorms.length) {
      const ids = dorms.map((d) => d.id);
      const [amen] = await db.query(
        `SELECT da.dorm_id, a.name FROM dorm_amenities da JOIN amenities a ON a.id = da.amenity_id
          WHERE da.dorm_id IN (?)`,
        [ids]
      );
      const [docs] = await db.query(
        `SELECT dorm_id, document_type AS type, display_name AS name FROM dorm_documents WHERE dorm_id IN (?)`,
        [ids]
      );
      for (const d of dorms) {
        d.amenities = amen.filter((a) => a.dorm_id === d.id).map((a) => a.name);
        d.documents = docs.filter((x) => x.dorm_id === d.id).map(({ type, name }) => ({ type, name }));
      }
    }
    res.json({ success: true, count: dorms.length, data: dorms });
  });

  router.patch("/dorms/:id/approval", async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
    if (typeof req.body?.approve !== "boolean") return fail(res, 400, "ต้องส่ง approve เป็น true หรือ false");
    const approve = req.body.approve;
    const reason = typeof req.body.reason === "string" ? req.body.reason.slice(0, 1000) : null;

    const [r] = await db.query(
      `UPDATE dorms SET approval_status = ?, reviewed_by = ?, reviewed_at = NOW(), rejection_reason = ?
        WHERE id = ?`,
      [approve ? "approved" : "rejected", req.user.id, approve ? null : reason, id]
    );
    if (r.affectedRows === 0) return fail(res, 404, "ไม่พบหอพักนี้");
    await audit(req.user.id, approve ? "approve_dorm" : "reject_dorm", "dorm", id, reason);
    res.json({ success: true, data: { id, status: approve ? "approved" : "rejected" } });
  });

  return router;
};
