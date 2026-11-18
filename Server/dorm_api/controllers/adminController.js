"use strict";

const DORM_STATUSES = ["pending", "approved", "rejected"];
const KYC_STATUSES = ["pending", "approved", "rejected"];

// รวมงานของแอดมินทั้งหมดไว้ที่นี่; paymentHelpers ใช้เฉพาะส่วนตรวจการชำระเงิน
// ซึ่งส่ง helper ของระบบจองเข้ามาจาก routes/bookingPaymentRoutes.js
module.exports = (db, paymentHelpers = {}) => {
  const fail = (res, status, message) =>
    res.status(status).json({ success: false, error: message, message });

  const audit = (adminId, action, targetType, targetId, reason) =>
    db.query(
      "INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, reason) VALUES (?, ?, ?, ?, ?)",
      [adminId, action, targetType, targetId, reason || null]
    );

  const toId = (raw) => {
    const id = Number(raw);
    return Number.isInteger(id) && id > 0 ? id : null;
  };

  const toSafeId = (raw) => {
    const id = Number(raw);
    return Number.isSafeInteger(id) && id > 0 ? id : null;
  };

  return {
    // สรุปจำนวนผู้ใช้ หอพัก ยอดเข้าชม และรายการจองบนหน้า dashboard แอดมิน
    getOverview: async (_req, res) => {
      const [[row]] = await db.query(`
        SELECT
          (SELECT COUNT(*) FROM users WHERE role = 'seller') AS sellers,
          (SELECT COUNT(*) FROM users WHERE role = 'tenant') AS tenants,
          (SELECT COUNT(*) FROM users WHERE account_status = 'suspended') AS suspended,
          (SELECT COUNT(*) FROM dorms WHERE approval_status = 'pending') AS pending_dorms,
          (SELECT COUNT(*) FROM dorms WHERE approval_status = 'approved') AS approved_dorms,
          (SELECT COUNT(*) FROM dorm_view_events) AS total_views,
          (SELECT COUNT(*) FROM bookings) AS bookings`);
      res.json({ success: true, data: row });
    },

    // แสดงรายชื่อเจ้าของหอพร้อมสถิติหอ ห้อง การจอง ยอดดู รายงาน และสถานะ KYC ล่าสุด
    getSellers: async (_req, res) => {
      const [rows] = await db.query(`
        SELECT u.id, u.email, u.full_name AS name, u.phone, u.account_status AS status,
               u.created_at AS joined,
               (SELECT d.id FROM dorms d WHERE d.owner_id = u.id ORDER BY d.id LIMIT 1) AS dormId,
               (SELECT d.name FROM dorms d WHERE d.owner_id = u.id ORDER BY d.id LIMIT 1) AS dorm,
               (SELECT COUNT(*) FROM dorms d WHERE d.owner_id = u.id) AS dorms,
               (SELECT COUNT(*) FROM rooms r JOIN dorms d ON d.id = r.dorm_id WHERE d.owner_id = u.id) AS rooms,
               (SELECT COUNT(*) FROM bookings b JOIN rooms r ON r.id = b.room_id JOIN dorms d ON d.id = r.dorm_id WHERE d.owner_id = u.id) AS bookings,
               (SELECT COUNT(*) FROM dorm_view_events v JOIN dorms d ON d.id = v.dorm_id WHERE d.owner_id = u.id) AS views,
               (SELECT COUNT(*) FROM user_dorm_reports p JOIN dorms d ON d.id = p.dorm_id WHERE d.owner_id = u.id) AS reports,
               (SELECT k.status FROM kyc_requests k WHERE k.seller_id = u.id ORDER BY k.id DESC LIMIT 1) AS kyc
          FROM users u WHERE u.role = 'seller' ORDER BY u.id`);
      res.json({ success: true, count: rows.length, data: rows });
    },

    // ระงับหรือเปิดบัญชีผู้ใช้ และบันทึกเหตุการณ์ลง audit log
    updateUserStatus: async (req, res) => {
      const id = toId(req.params.id);
      if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
      if (typeof req.body?.suspend !== "boolean") return fail(res, 400, "ต้องส่ง suspend เป็น true หรือ false");
      if (id === req.user.id) return fail(res, 400, "ระงับบัญชีตัวเองไม่ได้");
      const suspend = req.body.suspend;
      const reason = typeof req.body.reason === "string" ? req.body.reason.slice(0, 1000) : null;
      const [result] = await db.query(
        `UPDATE users SET account_status = ?, suspended_at = ?, suspension_reason = ? WHERE id = ? AND role <> 'admin'`,
        [suspend ? "suspended" : "active", suspend ? new Date() : null, suspend ? reason : null, id]
      );
      if (result.affectedRows === 0) return fail(res, 404, "ไม่พบบัญชีนี้ (หรือเป็นบัญชีแอดมิน)");
      await audit(req.user.id, suspend ? "suspend_user" : "unsuspend_user", "user", id, reason);
      res.json({ success: true, data: { id, status: suspend ? "suspended" : "active" } });
    },

    // แสดงคำขอลงประกาศหอ พร้อมสิ่งอำนวยความสะดวกและเอกสารประกอบ
    getDorms: async (req, res) => {
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
                (SELECT COUNT(*) FROM rooms r WHERE r.dorm_id = d.id) AS rooms
           FROM dorms d JOIN users u ON u.id = d.owner_id
          ${status === "all" ? "" : "WHERE d.approval_status = ?"}
          ORDER BY d.submitted_at DESC, d.id DESC`,
        status === "all" ? [] : [status]
      );
      if (dorms.length) {
        const ids = dorms.map((dorm) => dorm.id);
        const [amenities] = await db.query(
          `SELECT da.dorm_id, a.name FROM dorm_amenities da JOIN amenities a ON a.id = da.amenity_id WHERE da.dorm_id IN (?)`,
          [ids]
        );
        const [docs] = await db.query(
          `SELECT dorm_id, document_type AS type, display_name AS name FROM dorm_documents WHERE dorm_id IN (?)`,
          [ids]
        );
        for (const dorm of dorms) {
          dorm.amenities = amenities.filter((item) => item.dorm_id === dorm.id).map((item) => item.name);
          dorm.documents = docs.filter((item) => item.dorm_id === dorm.id).map(({ type, name }) => ({ type, name }));
        }
      }
      res.json({ success: true, count: dorms.length, data: dorms });
    },

    // อนุมัติหรือปฏิเสธประกาศหอ พร้อมบันทึกผู้ตรวจและ audit log
    updateDormApproval: async (req, res) => {
      const id = toId(req.params.id);
      if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
      if (typeof req.body?.approve !== "boolean") return fail(res, 400, "ต้องส่ง approve เป็น true หรือ false");
      const approve = req.body.approve;
      const reason = typeof req.body.reason === "string" ? req.body.reason.slice(0, 1000) : null;
      const [result] = await db.query(
        `UPDATE dorms SET approval_status = ?, reviewed_by = ?, reviewed_at = NOW(), rejection_reason = ? WHERE id = ?`,
        [approve ? "approved" : "rejected", req.user.id, approve ? null : reason, id]
      );
      if (result.affectedRows === 0) return fail(res, 404, "ไม่พบหอพักนี้");
      await audit(req.user.id, approve ? "approve_dorm" : "reject_dorm", "dorm", id, reason);
      res.json({ success: true, data: { id, status: approve ? "approved" : "rejected" } });
    },

    // แสดงคิวคำขอ KYC ตามสถานะ พร้อมข้อมูลเจ้าของหอและจำนวนเอกสาร
    getKycRequests: async (req, res) => {
      const status = String(req.query.status || "pending");
      if (status !== "all" && !KYC_STATUSES.includes(status)) {
        return fail(res, 400, "status ต้องเป็น pending, approved, rejected หรือ all");
      }
      const [rows] = await db.query(`
        SELECT k.id, k.seller_id AS sellerId, u.full_name AS sellerName,
               u.email AS sellerEmail, u.phone AS sellerPhone, k.id_card_number AS idCardNumber,
               k.dorm_name AS dormName,
                  k.status, k.submitted_at AS submittedAt, k.reviewed_by AS reviewedBy,
               reviewer.full_name AS reviewerName, k.reviewed_at AS reviewedAt,
               k.rejection_reason AS rejectionReason, COUNT(DISTINCT d.id) AS documentCount
          FROM kyc_requests k
          JOIN users u ON u.id = k.seller_id
          LEFT JOIN users reviewer ON reviewer.id = k.reviewed_by
          LEFT JOIN kyc_documents d ON d.kyc_request_id = k.id
          ${status === "all" ? "" : "WHERE k.status = ?"}
         GROUP BY k.id, k.seller_id, u.full_name, u.email, u.phone, k.id_card_number, k.dorm_name,
                  k.status, k.submitted_at, k.reviewed_by, reviewer.full_name,
                  k.reviewed_at, k.rejection_reason
         ORDER BY k.submitted_at DESC, k.id DESC`,
      status === "all" ? [] : [status]);
      res.json({ success: true, count: rows.length, data: rows });
    },

    // แสดงรายละเอียดคำขอ KYC หนึ่งรายการ รวมรายการเอกสารที่ส่งมา
    getKycRequest: async (req, res) => {
      const id = toSafeId(req.params.id);
      if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
      const [rows] = await db.query(`
        SELECT k.id, k.seller_id AS sellerId, u.full_name AS sellerName,
               u.email AS sellerEmail, u.phone AS sellerPhone, k.id_card_number AS idCardNumber,
               k.dorm_name AS dormName,
               k.status, k.submitted_at AS submittedAt, k.reviewed_by AS reviewedBy,
               reviewer.full_name AS reviewerName, k.reviewed_at AS reviewedAt,
               k.rejection_reason AS rejectionReason
          FROM kyc_requests k JOIN users u ON u.id = k.seller_id
          LEFT JOIN users reviewer ON reviewer.id = k.reviewed_by
         WHERE k.id = ? LIMIT 1`, [id]);
      if (!rows.length) return fail(res, 404, "ไม่พบคำขอ KYC นี้");
      const [documents] = await db.query(`
        SELECT id, document_type AS documentType, file_data AS fileData,
               watermark_text AS watermarkText, uploaded_at AS uploadedAt
          FROM kyc_documents WHERE kyc_request_id = ? ORDER BY uploaded_at, id`, [id]);
      res.json({ success: true, data: { ...rows[0], documents } });
    },

    // ตัดสินคำขอ KYC แบบ transaction และ lock แถวเพื่อป้องกันการตัดสินซ้ำ
    decideKycRequest: async (req, res) => {
      const id = toSafeId(req.params.id);
      if (!id) return fail(res, 400, "id ไม่ถูกต้อง");
      const status = req.body?.status;
      if (status !== "approved" && status !== "rejected") {
        return fail(res, 400, 'status ต้องเป็น "approved" หรือ "rejected"');
      }
      let rejectionReason = null;
      if (status === "rejected") {
        if (typeof req.body?.rejection_reason !== "string" || !req.body.rejection_reason.trim()) {
          return fail(res, 400, "กรุณาระบุเหตุผลเมื่อปฏิเสธคำขอ");
        }
        rejectionReason = req.body.rejection_reason.trim().slice(0, 1000);
      }
      const connection = await db.getConnection();
      try {
        await connection.beginTransaction();
        const [requests] = await connection.query(
          "SELECT id, status FROM kyc_requests WHERE id = ? FOR UPDATE", [id]);
        if (!requests.length) {
          await connection.rollback();
          return fail(res, 404, "ไม่พบคำขอ KYC นี้");
        }
        if (requests[0].status !== "pending") {
          await connection.rollback();
          return fail(res, 409, "คำขอนี้ได้รับการตรวจสอบไปแล้ว");
        }
        await connection.query(`
          UPDATE kyc_requests SET status = ?, reviewed_by = ?, reviewed_at = NOW(), rejection_reason = ?
           WHERE id = ?`, [status, req.user.id, rejectionReason, id]);
        await connection.query(`
          INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, reason)
          VALUES (?, ?, 'kyc_request', ?, ?)`,
        [req.user.id, status === "approved" ? "approve_kyc" : "reject_kyc", id, rejectionReason]);
        await connection.commit();
        res.json({ success: true, data: { id, status, reviewedBy: req.user.id, rejectionReason } });
      } catch (error) {
        await connection.rollback();
        throw error;
      } finally {
        connection.release();
      }
    },

    // แสดงรายการชำระเงินในคิวตรวจสอบหรือกรองตามสถานะ
    getAdminPayments: async (req, res) => {
      const { STATUS_LABEL, expireStale, RESERVATION_SQL, decorate } = paymentHelpers;
      if (!STATUS_LABEL) throw new Error("Admin payment helpers are not configured");
      const status = String(req.query.status || "paid");
      if (status !== "all" && !STATUS_LABEL[status]) return fail(res, 400, "status ไม่ถูกต้อง");
      await expireStale();
      const [rows] = await db.query(
        RESERVATION_SQL + (status === "all" ? "" : " WHERE p.status = ?") + " ORDER BY p.paid_at DESC, p.id DESC",
        status === "all" ? [] : [status]);
      res.json({ success: true, data: rows.map(decorate) });
    },

    // อนุมัติหรือปฏิเสธยอดชำระ; เมื่ออนุมัติแจ้งเจ้าของหอผ่านห้องแชท
    reviewAdminPayment: async (req, res) => {
      const { expireStale, RESERVATION_SQL, getReservation, notifyChat, money } = paymentHelpers;
      if (!getReservation) throw new Error("Admin payment helpers are not configured");
      const id = toId(req.params.id);
      if (!id) return fail(res, 400, "เลขรายการไม่ถูกต้อง");
      if (typeof req.body?.approve !== "boolean") return fail(res, 400, "ต้องส่ง approve เป็น true หรือ false");
      const approve = req.body.approve;
      const note = typeof req.body.note === "string" ? req.body.note.slice(0, 500) : null;
      await expireStale();
      const [result] = await db.query(`
        UPDATE booking_payments p JOIN bookings b ON b.id = p.booking_id
           SET p.status = ?, p.admin_id = ?, p.admin_reviewed_at = NOW(), p.admin_note = ?,
               b.status = IF(?, b.status, 'cancelled')
         WHERE p.id = ? AND p.status = 'paid'`,
      [approve ? "approved" : "rejected", req.user.id, note, approve, id]);
      if (result.affectedRows === 0) return fail(res, 400, "อนุมัติได้เฉพาะรายการที่ชำระเงินแล้วและรอตรวจสอบ");
      const reservation = await getReservation(id);
      if (approve) {
        await notifyChat({
          dormId: reservation.dormId, tenantId: reservation.tenantId,
          ownerId: reservation.ownerId, senderId: reservation.tenantId,
          text: `[แจ้งเตือนจากระบบ] ${reservation.tenantName} จองห้อง ${reservation.roomNumber} (${reservation.planLabel}) ` +
            `เข้าพัก ${reservation.startsAt} ถึง ${reservation.endsAt}\n` +
            `ชำระเงิน ${money(reservation.paidAmount)} บาทแล้ว แอดมินตรวจสอบยอดเงินถูกต้อง\n` +
            "รอเจ้าของหอยืนยันการจอง",
        });
      }
      res.json({ success: true, data: reservation });
    },
  };
};
