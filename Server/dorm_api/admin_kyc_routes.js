"use strict";
// Dorm Master - Admin KYC Verification API
//
// GET   /api/admin/kyc
// GET   /api/admin/kyc/:id
// PATCH /api/admin/kyc/:id/decision
const express = require("express");
const KYC_STATUSES = ["pending", "approved", "rejected"];
module.exports = (db, auth) => {
    const router = express.Router();
    // ตรวจสอบสิทธิ์ Admin
    router.use(auth.requireRole("admin"));
    // ส่ง Error Response
    const fail = (res, status, message) => {
        return res.status(status).json({ success: false, error: message, message });
    };
    // ตรวจสอบ ID
    const toId = (raw) => {
        const id = Number(raw);
        return Number.isSafeInteger(id) && id > 0
            ? id
            : null;
    };
    // ==========================================
    // 1. GET /api/admin/kyc
    // ดูรายการคำขอ KYC
    // ตัวอย่าง: /api/admin/kyc?status=pending
    // ==========================================
    router.get("/", async (req, res) => {
        const status = String(req.query.status || "pending");
        if (status !== "all" && !KYC_STATUSES.includes(status)) {
            return fail(res, 400, "status ต้องเป็น pending, approved, rejected หรือ all");
        }
        const [rows] = await db.query(`SELECT
         k.id,
         k.seller_id AS sellerId,
         u.full_name AS sellerName,
         u.email AS sellerEmail,
         u.phone AS sellerPhone,
         k.dorm_name AS dormName,
         k.status,
         k.submitted_at AS submittedAt,
         k.reviewed_by AS reviewedBy,
         reviewer.full_name AS reviewerName,
         k.reviewed_at AS reviewedAt,
         k.rejection_reason AS rejectionReason,
         COUNT(DISTINCT d.id) AS documentCount

       FROM kyc_requests k

       JOIN users u
         ON u.id = k.seller_id

       LEFT JOIN users reviewer
         ON reviewer.id = k.reviewed_by

       LEFT JOIN kyc_documents d
         ON d.kyc_request_id = k.id

       ${status === "all"
                ? ""
                : "WHERE k.status = ?"
            }

       GROUP BY
         k.id,
         k.seller_id,
         u.full_name,
         u.email,
         u.phone,
         k.dorm_name,
         k.status,
         k.submitted_at,
         k.reviewed_by,
         reviewer.full_name,
         k.reviewed_at,
         k.rejection_reason

       ORDER BY
         k.submitted_at DESC,
         k.id DESC`,
            status === "all"
                ? []
                : [status]);
        return res.json({ success: true, count: rows.length, data: rows });
    });
    // ==========================================
    // 2. GET /api/admin/kyc/:id
    // ดูรายละเอียดคำขอ KYC
    // ==========================================
    router.get("/:id", async (req, res) => {
        const id = toId(req.params.id);
        if (!id) {
            return fail(res, 400, "id ไม่ถูกต้อง");
        }
        const [rows] = await db.query(`SELECT
         k.id,
         k.seller_id AS sellerId,
         u.full_name AS sellerName,
         u.email AS sellerEmail,
         u.phone AS sellerPhone,
         k.dorm_name AS dormName,
         k.status,
         k.submitted_at AS submittedAt,
         k.reviewed_by AS reviewedBy,
         reviewer.full_name AS reviewerName,
         k.reviewed_at AS reviewedAt,
         k.rejection_reason AS rejectionReason

       FROM kyc_requests k

       JOIN users u
         ON u.id = k.seller_id

       LEFT JOIN users reviewer
         ON reviewer.id = k.reviewed_by

       WHERE k.id = ?

       LIMIT 1`, [id]);
        if (!rows.length) {
            return fail(res, 404, "ไม่พบคำขอ KYC นี้");
        }
        // ดึงข้อมูลเอกสารประกอบ
        const [documents] = await db.query(`SELECT
         id,
         document_type AS documentType,
         uploaded_at AS uploadedAt

       FROM kyc_documents

       WHERE kyc_request_id = ?

       ORDER BY uploaded_at, id`, [id]);
        return res.json({
            success: true,
            data: {
                ...rows[0],
                documents
            }
        });
    });
    // ==========================================
    // 3. PATCH /api/admin/kyc/:id/decision
    // อนุมัติหรือปฏิเสธคำขอ KYC
    // ==========================================
    router.patch("/:id/decision", async (req, res) => {
        const id = toId(req.params.id);
        if (!id) {
            return fail(res, 400, "id ไม่ถูกต้อง");
        }
        const status = req.body?.status;
        // ตรวจสอบสถานะ
        if (status !== "approved" && status !== "rejected") {
            return fail(res, 400, 'status ต้องเป็น "approved" หรือ "rejected"');
        }
        // ตรวจสอบเหตุผลกรณีปฏิเสธ
        let rejectionReason = null;
        if (status === "rejected") {
            if (typeof req.body?.rejection_reason !== "string" || !req
                .body
                .rejection_reason
                .trim()) {
                return fail(res, 400, "กรุณาระบุเหตุผลเมื่อปฏิเสธคำขอ");
            }
            rejectionReason = req
                .body
                .rejection_reason
                .trim()
                .slice(0, 1000);
        }
        const connection = await db.getConnection();
        try {
            await connection.beginTransaction();
            // Lock ข้อมูลเพื่อป้องกันการตัดสินคำขอซ้ำ
            const [requests] = await connection.query(`SELECT id, status
         FROM kyc_requests
         WHERE id = ?
         FOR UPDATE`, [id]);
            // ตรวจสอบว่ามีคำขอหรือไม่
            if (!requests.length) {
                await connection.rollback();
                return fail(res, 404, "ไม่พบคำขอ KYC นี้");
            }
            // ตรวจสอบว่าคำขอยังรอการตรวจสอบอยู่หรือไม่
            if (requests[0].status !== "pending") {
                await connection.rollback();
                return fail(res, 409, "คำขอนี้ได้รับการตรวจสอบไปแล้ว");
            }
            // อัปเดตสถานะ KYC
            await connection.query(`UPDATE kyc_requests

         SET
           status = ?,
           reviewed_by = ?,
           reviewed_at = NOW(),
           rejection_reason = ?

         WHERE id = ?`, [status, req.user.id, rejectionReason, id]);
            // บันทึกประวัติการดำเนินการของ Admin
            await connection.query(`INSERT INTO admin_audit_logs
           (admin_id, action, target_type, target_id, reason)

         VALUES (?, ?, 'kyc_request', ?, ?)`, [
                req.user.id,
                status === "approved"
                    ? "approve_kyc"
                    : "reject_kyc",
                id,
                rejectionReason
            ]);
            await connection.commit();
            return res.json({
                success: true,
                data: {
                    id,
                    status,
                    reviewedBy: req.user.id,
                    rejectionReason
                }
            });
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    });
    return router;
};
