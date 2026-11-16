"use strict";
// ระบบจองห้องแบบจ่ายเงินผ่านแอดมิน + แจ้งเตือนในแชท   (ไฟล์แยก ไม่แก้ไฟล์ของเพื่อน)
//   ใช้งาน (server.js): app.use("/api/booking", require("./routes/bookingPaymentRoutes")(db, auth, io, appCfg.jwt_secret));
//
// ขั้นตอน
//   1. ผู้เช่าเลือกห้องจากผัง 2D + เลือกระยะเวลา -> กดจอง                       = awaiting_payment (ห้องติดจอง 30 นาที)
//      ยอดเงิน = ค่าเช่าต่อเดือนของห้องนั้น (เจ้าของหอตั้งตอนเพิ่มห้อง) x ระยะเวลา  (ดู priceFor)
//      เจ้าของหอเลือกได้ว่าหอนี้เปิดให้เช่าแบบไหนบ้าง (ยังไม่ตั้ง = เปิดทุกแบบ)
//   2. ผู้เช่ากดจ่ายเงิน (mock: ระบบบังคับยอดตามราคาที่ตั้ง)                    = paid      (รอแอดมินตรวจ)
//   3. แอดมินตรวจยอดเงิน -> อนุมัติ                                              = approved  -> แจ้งเตือนในแชทถึงเจ้าของหอ
//                         -> ไม่อนุมัติ                                           = rejected  (ยกเลิกการจอง ห้องว่างอีกครั้ง)
//   4. เจ้าของหอยืนยัน                                                           = completed -> ห้องเป็น "มีผู้เช่า" + แจ้งเตือนในแชทถึงผู้เช่า
//                     หรือปฏิเสธ                                                  = owner_rejected (แอดมินคืนเงิน)
//   ไม่จ่ายภายใน 30 นาที = expired / ผู้เช่ายกเลิกก่อนจ่าย = cancelled
//
// API
//   GET   /api/booking/dorms/:dormId/plan              ผัง 2D: ชั้น > ห้อง + สถานะ + ราคาเช่าแต่ละแบบ (ไม่ต้อง login)
//   POST  /api/booking/reservations                    { roomId, plan, startsAt? }      (ผู้เช่า)
//   GET   /api/booking/reservations/mine               การจองของฉัน                     (ผู้เช่า)
//   GET   /api/booking/reservations/:id                รายละเอียด (ผู้เช่าเจ้าของรายการ / เจ้าของหอ / แอดมิน)
//   POST  /api/booking/reservations/:id/pay            จ่ายเงิน (mock)                  (ผู้เช่า)
//   POST  /api/booking/reservations/:id/cancel         ยกเลิกก่อนจ่าย                    (ผู้เช่า)
//   GET   /api/booking/admin/payments?status=paid      รายการรอตรวจเงิน                 (แอดมิน)
//   PATCH /api/booking/admin/payments/:id              { approve: true|false, note? }    (แอดมิน)
//   GET   /api/booking/owner/reservations?status=approved                                (เจ้าของหอ)
//   PATCH /api/booking/owner/reservations/:id          { action: 'confirm'|'reject', note? } (เจ้าของหอ)
//   GET   /api/booking/owner/dorms/:dormId/plans       ราคาเช่าที่ตั้งไว้                  (เจ้าของหอ)
//   PUT   /api/booking/owner/dorms/:dormId/plans       { plans: [{ plan, active }] }     (เจ้าของหอ)
const express = require("express");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");
const createAdminController = require("../controllers/adminController");

const HOLD_MINUTES = 30;

// rate = คูณกับค่าเช่าต่อเดือนของห้อง (1 อาทิตย์ = 1/4 เดือน)
const PLANS = {
  week:  { label: "1 อาทิตย์", days: 7, rate: 0.25, rateLabel: "ค่าเช่าเดือน ÷ 4" },
  month: { label: "1 เดือน", months: 1, rate: 1, rateLabel: "ค่าเช่า 1 เดือน" },
  term:  { label: "1 เทอม (4 เดือน)", months: 4, rate: 4, rateLabel: "ค่าเช่า x 4 เดือน" },
  year:  { label: "1 ปี", months: 12, rate: 12, rateLabel: "ค่าเช่า x 12 เดือน" },
};
const PLAN_KEYS = Object.keys(PLANS);

/** ยอดที่ต้องจ่าย = ค่าเช่าต่อเดือนของห้อง x ระยะเวลา (ปัดขึ้นเป็นบาท) */
const priceFor = (monthlyPrice, plan) => Math.ceil(Number(monthlyPrice) * PLANS[plan].rate);

const STATUS_LABEL = {
  awaiting_payment: "รอชำระเงิน",
  paid: "รอแอดมินตรวจสอบการชำระเงิน",
  approved: "รอเจ้าของหอยืนยัน",
  rejected: "แอดมินไม่อนุมัติการชำระเงิน",
  completed: "จองสำเร็จ",
  owner_rejected: "เจ้าของหอปฏิเสธ (รอคืนเงิน)",
  cancelled: "ยกเลิกแล้ว",
  expired: "หมดเวลาชำระเงิน",
};
// สถานะที่ยังถือห้องไว้ (คนอื่นจองห้องนี้ไม่ได้)
const HOLDING = ["awaiting_payment", "paid", "approved"];

const ROOM_STATE_LABEL = {
  available: "ว่าง",
  occupied: "มีผู้เช่า",
  reserved: "ติดจอง",
  maintenance: "ปรับปรุง",
};

const money = (n) => Number(n || 0).toLocaleString("en-US");
const pad = (n) => String(n).padStart(2, "0");
const ymd = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/** วันสิ้นสุดสัญญาตามแบบที่เลือก */
const endDate = (start, plan) => {
  const d = new Date(start.getTime());
  const p = PLANS[plan];
  if (p.days) d.setDate(d.getDate() + p.days);
  else d.setMonth(d.getMonth() + p.months);
  d.setDate(d.getDate() - 1);
  return d;
};

/** เลขอ้างอิงการโอน (mock) เช่น DM20261115-4F7K2Q */
const paymentRef = () => {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return "DM" + ymd(new Date()).replace(/-/g, "") + "-" + s;
};

/** สร้างตาราง (sql/booking_payment.sql) ตอนเปิด server — รันซ้ำได้ */
const ensureSchema = async (pool) => {
  const sql = fs.readFileSync(path.join(__dirname, "sql", "booking_payment.sql"), "utf8");
  const statements = sql
    .split(/;\s*(?:\r?\n|$)/)
    .map((s) => s.replace(/^\s*--.*$/gm, "").trim())
    .filter(Boolean);
  for (const st of statements) await pool.promise().query(st);
};

module.exports = (db, auth, io, jwtSecret) => {
  const router = express.Router();
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  // ไม่บังคับ login (หน้าผังห้อง) แต่ถ้ามี token ให้รู้ว่าใครดู -> ห้องที่ฉันจองไว้ขึ้นว่า "ของฉัน"
  const optionalUser = (req, res, next) => {
    const m = /^Bearer (.+)$/i.exec(req.header("authorization") || "");
    if (m) {
      try {
        const p = jwt.verify(m[1], jwtSecret);
        req.user = { id: p.id, role: p.role };
      } catch { /* token เสีย = ดูแบบไม่ login */ }
    }
    next();
  };

  const toId = (raw) => {
    const id = Number(raw);
    return Number.isInteger(id) && id > 0 ? id : null;
  };

  /** หอนี้เปิดให้เช่าแบบไหนบ้าง (เจ้าของหอยังไม่เคยตั้ง = เปิดทุกแบบ) */
  const enabledPlans = async (dormId, q = db) => {
    const [rows] = await q.query("SELECT plan, is_active FROM dorm_rent_plans WHERE dorm_id = ?", [dormId]);
    if (rows.length === 0) return [...PLAN_KEYS];
    return PLAN_KEYS.filter((k) => rows.some((r) => r.plan === k && r.is_active));
  };

  /** ปล่อยห้องที่ไม่จ่ายภายในเวลา */
  const expireStale = async () => {
    await db.query(
      `UPDATE booking_payments p JOIN bookings b ON b.id = p.booking_id
          SET p.status = 'expired', b.status = 'cancelled'
        WHERE p.status = 'awaiting_payment' AND p.expires_at < NOW()`
    );
  };

  /** ส่งข้อความแจ้งเตือนจากระบบเข้าห้องแชทระหว่างผู้เช่ากับเจ้าของหอ (สร้างห้องให้ถ้ายังไม่เคยคุย)
   *  senderId = ฝั่งที่ทำให้เกิดเรื่อง -> อีกฝั่งเห็นเป็น "ยังไม่อ่าน" (ตัวเลขแจ้งเตือนขึ้นในรายการแชท) */
  const notifyChat = async ({ dormId, tenantId, ownerId, senderId, text }) => {
    await db.query(
      "INSERT IGNORE INTO conversations (dorm_id, tenant_id, owner_id) VALUES (?, ?, ?)",
      [dormId, tenantId, ownerId]
    );
    const [[conv]] = await db.query(
      "SELECT id FROM conversations WHERE dorm_id = ? AND tenant_id = ? AND owner_id = ?",
      [dormId, tenantId, ownerId]
    );
    const now = new Date();
    const [r] = await db.query(
      `INSERT INTO messages (conversation_id, sender_id, message_text, message_type, sent_at)
       VALUES (?, ?, ?, 'system', ?)`,
      [conv.id, senderId, text, now]
    );
    await db.query("UPDATE conversations SET updated_at = ? WHERE id = ?", [now, conv.id]);
    const msg = {
      id: r.insertId, conversation_id: conv.id, sender_id: senderId,
      text, type: "system", sent_at: now, read_at: null,
    };
    if (io) {
      io.to("conv:" + conv.id).emit("new_message", msg);
      io.to("user:" + tenantId).to("user:" + ownerId).emit("conversation_updated", { conversation_id: conv.id });
    }
    return conv.id;
  };

  /** รายละเอียดการจอง 1 รายการ (ใช้ร่วมกันทุกหน้า) */
  const RESERVATION_SQL = `
    SELECT p.id, p.booking_id AS bookingId, p.status, p.plan, p.amount, p.paid_amount AS paidAmount,
           p.payment_ref AS paymentRef, p.paid_at AS paidAt, p.expires_at AS expiresAt, p.created_at AS createdAt,
           p.admin_reviewed_at AS adminReviewedAt, p.admin_note AS adminNote,
           p.owner_reviewed_at AS ownerReviewedAt, p.owner_note AS ownerNote,
           b.starts_at AS startsAt, b.ends_at AS endsAt,
           d.id AS dormId, d.name AS dormName, d.owner_id AS ownerId, o.full_name AS ownerName,
           r.id AS roomId, r.room_number AS roomNumber, r.room_type AS roomType, r.floor,
           p.tenant_id AS tenantId, t.full_name AS tenantName, t.phone AS tenantPhone, t.email AS tenantEmail
      FROM booking_payments p
      JOIN bookings b ON b.id = p.booking_id
      JOIN dorms d ON d.id = p.dorm_id
      JOIN users o ON o.id = d.owner_id
      JOIN rooms r ON r.id = p.room_id
      JOIN users t ON t.id = p.tenant_id`;

  const decorate = (row) => ({
    ...row,
    planLabel: PLANS[row.plan]?.label || row.plan,
    statusLabel: STATUS_LABEL[row.status] || row.status,
    amountMatches: row.paidAmount == null ? null : Number(row.paidAmount) === Number(row.amount),
    startsAt: row.startsAt instanceof Date ? ymd(row.startsAt) : row.startsAt,
    endsAt: row.endsAt instanceof Date ? ymd(row.endsAt) : row.endsAt,
  });

  const getReservation = async (id) => {
    const [[row]] = await db.query(RESERVATION_SQL + " WHERE p.id = ?", [id]);
    return row ? decorate(row) : null;
  };

  // ส่ง helper ของระบบจองให้ adminController จัดการ endpoint ตรวจการชำระเงิน
  const adminController = createAdminController(db, {
    STATUS_LABEL, expireStale, RESERVATION_SQL, decorate, getReservation, notifyChat, money,
  });

  // ───────────────────────── ผัง 2D ─────────────────────────
  router.get("/dorms/:dormId/plan", optionalUser, async (req, res) => {
    const dormId = toId(req.params.dormId);
    if (!dormId) return fail(res, 400, "เลขหอไม่ถูกต้อง");
    await expireStale();

    const [[dorm]] = await db.query(
      `SELECT id, name, owner_id AS ownerId, approval_status, listing_status FROM dorms WHERE id = ?`,
      [dormId]
    );
    const isOwner = dorm && req.user && req.user.id === dorm.ownerId;
    if (!dorm || (!isOwner && (dorm.approval_status !== "approved" || dorm.listing_status !== "active"))) {
      return fail(res, 404, "ไม่พบหอพัก หรือประกาศถูกปิดใช้งาน");
    }

    const plans = await enabledPlans(dormId);
    const [rooms] = await db.query(
      `SELECT id, room_number AS number, room_type AS type, price_per_month AS monthlyPrice, floor, status
         FROM rooms WHERE dorm_id = ? ORDER BY floor DESC, room_number ASC`,
      [dormId]
    );
    const [holds] = await db.query(
      `SELECT id, room_id, tenant_id, status FROM booking_payments
        WHERE dorm_id = ? AND status IN (?)`,
      [dormId, HOLDING]
    );

    const floors = new Map();
    for (const room of rooms) {
      const hold = holds.find((h) => h.room_id === room.id);
      let state = "available";
      if (room.status === "maintenance") state = "maintenance";
      else if (room.status === "occupied") state = "occupied";
      else if (hold) state = "reserved";
      const mine = Boolean(hold && req.user && hold.tenant_id === req.user.id);
      if (!floors.has(room.floor)) floors.set(room.floor, []);
      floors.get(room.floor).push({
        id: room.id, number: room.number, type: room.type, monthlyPrice: room.monthlyPrice,
        floor: room.floor, state, stateLabel: ROOM_STATE_LABEL[state],
        myReservationId: mine ? hold.id : null,
        // ราคาของห้องนี้ในแต่ละระยะเวลาที่หอเปิดให้เช่า
        prices: Object.fromEntries(plans.map((k) => [k, priceFor(room.monthlyPrice, k)])),
      });
    }

    res.json({
      success: true,
      data: {
        dorm: { id: dorm.id, name: dorm.name, ownerId: dorm.ownerId },
        plans: plans.map((k) => ({ plan: k, label: PLANS[k].label, rate: PLANS[k].rate, rateLabel: PLANS[k].rateLabel })),
        floors: [...floors.entries()].map(([floor, list]) => ({ floor, rooms: list })),
        holdMinutes: HOLD_MINUTES,
      },
    });
  });

  // ───────────────────────── ผู้เช่า ─────────────────────────
  const tenantOnly = auth.requireRole("tenant");

  router.post("/reservations", tenantOnly, async (req, res) => {
    const roomId = toId(req.body?.roomId);
    const plan = req.body?.plan;
    if (!roomId) return fail(res, 400, "กรุณาเลือกห้อง");
    if (!PLAN_KEYS.includes(plan)) return fail(res, 400, "กรุณาเลือกระยะเวลาเช่า (week, month, term, year)");

    const today = new Date(ymd(new Date()) + "T00:00:00");
    let start = today;
    if (req.body.startsAt) {
      start = new Date(String(req.body.startsAt).slice(0, 10) + "T00:00:00");
      const max = new Date(today.getTime() + 90 * 86400000);
      if (isNaN(start) || start < today || start > max) {
        return fail(res, 400, "วันเข้าพักต้องอยู่ระหว่างวันนี้ถึง 90 วันข้างหน้า");
      }
    }
    await expireStale();

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [[room]] = await conn.query(
        `SELECT r.id, r.status, r.price_per_month, r.dorm_id, d.owner_id
           FROM rooms r JOIN dorms d ON d.id = r.dorm_id
          WHERE r.id = ? AND d.approval_status = 'approved' AND d.listing_status = 'active'
          FOR UPDATE`,
        [roomId]
      );
      if (!room) {
        await conn.rollback();
        return fail(res, 404, "ไม่พบห้องนี้ หรือหอยังไม่เปิดให้จอง");
      }
      if (room.status !== "available") {
        await conn.rollback();
        return fail(res, 409, room.status === "maintenance" ? "ห้องนี้อยู่ระหว่างปรับปรุง" : "ห้องนี้มีผู้เช่าแล้ว");
      }
      const [held] = await conn.query(
        "SELECT id, tenant_id FROM booking_payments WHERE room_id = ? AND status IN (?) FOR UPDATE",
        [roomId, HOLDING]
      );
      if (held.length) {
        await conn.rollback();
        return held[0].tenant_id === req.user.id
          ? fail(res, 409, "คุณจองห้องนี้ไว้แล้ว ดูได้ที่การจองของฉัน")
          : fail(res, 409, "ห้องนี้ติดจองอยู่");
      }
      if (!(await enabledPlans(room.dorm_id, conn)).includes(plan)) {
        await conn.rollback();
        return fail(res, 400, "หอนี้ไม่เปิดให้เช่าแบบ " + PLANS[plan].label);
      }
      if (!(Number(room.price_per_month) > 0)) {
        await conn.rollback();
        return fail(res, 400, "ห้องนี้ยังไม่ได้ตั้งค่าเช่า ติดต่อเจ้าของหอ");
      }

      const [b] = await conn.query(
        `INSERT INTO bookings (room_id, tenant_id, status, monthly_price, starts_at, ends_at)
         VALUES (?, ?, 'pending', ?, ?, ?)`,
        [roomId, req.user.id, room.price_per_month, ymd(start), ymd(endDate(start, plan))]
      );
      const [p] = await conn.query(
        `INSERT INTO booking_payments (booking_id, tenant_id, dorm_id, room_id, plan, amount, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW() + INTERVAL ${HOLD_MINUTES} MINUTE)`,
        [b.insertId, req.user.id, room.dorm_id, roomId, plan, priceFor(room.price_per_month, plan)]
      );
      await conn.commit();
      res.status(201).json({ success: true, data: await getReservation(p.insertId) });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  });

  router.get("/reservations/mine", tenantOnly, async (req, res) => {
    await expireStale();
    const [rows] = await db.query(RESERVATION_SQL + " WHERE p.tenant_id = ? ORDER BY p.id DESC", [req.user.id]);
    res.json({ success: true, data: rows.map(decorate) });
  });

  router.get("/reservations/:id", auth.verifyToken, async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "เลขการจองไม่ถูกต้อง");
    await expireStale();
    const r = await getReservation(id);
    const allowed = r && (r.tenantId === req.user.id || r.ownerId === req.user.id || req.user.role === "admin");
    if (!allowed) return fail(res, 404, "ไม่พบการจองนี้");
    res.json({ success: true, data: r });
  });

  router.post("/reservations/:id/pay", tenantOnly, async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "เลขการจองไม่ถูกต้อง");
    await expireStale();
    // mock: เหมือนจ่ายผ่าน QR ที่ระบบสร้างยอดให้ -> ยอดที่จ่าย = ยอดที่ต้องจ่ายเสมอ (ไม่รับยอดจากแอป)
    const [r] = await db.query(
      `UPDATE booking_payments
          SET status = 'paid', paid_amount = amount, payment_ref = ?, paid_at = NOW()
        WHERE id = ? AND tenant_id = ? AND status = 'awaiting_payment'`,
      [paymentRef(), id, req.user.id]
    );
    if (r.affectedRows === 0) {
      const cur = await getReservation(id);
      if (!cur || cur.tenantId !== req.user.id) return fail(res, 404, "ไม่พบการจองนี้");
      return fail(res, 400, "จ่ายเงินไม่ได้: สถานะตอนนี้คือ " + cur.statusLabel);
    }
    res.json({ success: true, data: await getReservation(id) });
  });

  router.post("/reservations/:id/cancel", tenantOnly, async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "เลขการจองไม่ถูกต้อง");
    const [r] = await db.query(
      `UPDATE booking_payments p JOIN bookings b ON b.id = p.booking_id
          SET p.status = 'cancelled', b.status = 'cancelled'
        WHERE p.id = ? AND p.tenant_id = ? AND p.status = 'awaiting_payment'`,
      [id, req.user.id]
    );
    if (r.affectedRows === 0) return fail(res, 400, "ยกเลิกได้เฉพาะรายการที่ยังไม่ได้ชำระเงิน");
    res.json({ success: true, data: await getReservation(id) });
  });

  // ───────────────────────── แอดมิน ─────────────────────────
  const adminOnly = auth.requireRole("admin");

  router.get("/admin/payments", adminOnly, adminController.getAdminPayments);
  router.patch("/admin/payments/:id", adminOnly, adminController.reviewAdminPayment);

  // ───────────────────────── เจ้าของหอ ─────────────────────────
  const ownerOnly = auth.requireRole("seller");

  router.get("/owner/reservations", ownerOnly, async (req, res) => {
    const status = String(req.query.status || "approved");
    if (status !== "all" && !STATUS_LABEL[status]) return fail(res, 400, "status ไม่ถูกต้อง");
    // เจ้าของหอเห็นเฉพาะรายการที่แอดมินตรวจเงินแล้ว
    const visible = ["approved", "completed", "owner_rejected"];
    const statuses = status === "all" ? visible : [status];
    const [rows] = await db.query(
      RESERVATION_SQL + " WHERE d.owner_id = ? AND p.status IN (?) ORDER BY p.admin_reviewed_at DESC, p.id DESC",
      [req.user.id, statuses]
    );
    res.json({ success: true, data: rows.map(decorate) });
  });

  router.patch("/owner/reservations/:id", ownerOnly, async (req, res) => {
    const id = toId(req.params.id);
    const action = req.body?.action;
    if (!id) return fail(res, 400, "เลขการจองไม่ถูกต้อง");
    if (action !== "confirm" && action !== "reject") return fail(res, 400, "action ต้องเป็น confirm หรือ reject");
    const note = typeof req.body.note === "string" ? req.body.note.slice(0, 500) : null;

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [[p]] = await conn.query(
        `SELECT p.id, p.status, p.room_id, p.booking_id FROM booking_payments p
           JOIN dorms d ON d.id = p.dorm_id
          WHERE p.id = ? AND d.owner_id = ? FOR UPDATE`,
        [id, req.user.id]
      );
      if (!p) {
        await conn.rollback();
        return fail(res, 404, "ไม่พบการจองนี้");
      }
      if (p.status !== "approved") {
        await conn.rollback();
        return fail(res, 400, "ยืนยันได้เฉพาะรายการที่แอดมินตรวจเงินแล้ว (สถานะตอนนี้: " + STATUS_LABEL[p.status] + ")");
      }
      if (action === "confirm") {
        const [[room]] = await conn.query("SELECT status FROM rooms WHERE id = ? FOR UPDATE", [p.room_id]);
        if (room.status !== "available") {
          await conn.rollback();
          return fail(res, 409, "ห้องนี้ไม่ว่างแล้ว ให้กดปฏิเสธเพื่อคืนเงินผู้เช่า");
        }
        await conn.query("UPDATE rooms SET status = 'occupied' WHERE id = ?", [p.room_id]);
        await conn.query("UPDATE bookings SET status = 'confirmed' WHERE id = ?", [p.booking_id]);
      } else {
        await conn.query("UPDATE bookings SET status = 'cancelled' WHERE id = ?", [p.booking_id]);
      }
      await conn.query(
        "UPDATE booking_payments SET status = ?, owner_reviewed_at = NOW(), owner_note = ? WHERE id = ?",
        [action === "confirm" ? "completed" : "owner_rejected", note, id]
      );
      await conn.commit();
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }

    const v = await getReservation(id);
    await notifyChat({
      dormId: v.dormId, tenantId: v.tenantId, ownerId: v.ownerId, senderId: v.ownerId,
      text: action === "confirm"
        ? `[แจ้งเตือนจากระบบ] เจ้าของหอยืนยันการจองห้อง ${v.roomNumber} (${v.planLabel}) แล้ว\n` +
          `การจองเสร็จสมบูรณ์ เข้าพักได้ตั้งแต่ ${v.startsAt}`
        : `[แจ้งเตือนจากระบบ] เจ้าของหอปฏิเสธการจองห้อง ${v.roomNumber}` +
          (note ? ` (เหตุผล: ${note})` : "") + `\nแอดมินจะคืนเงิน ${money(v.paidAmount)} บาท`,
    });
    res.json({ success: true, data: v });
  });

  const ownsDorm = async (dormId, userId) => {
    const [[d]] = await db.query("SELECT id FROM dorms WHERE id = ? AND owner_id = ?", [dormId, userId]);
    return Boolean(d);
  };

  router.get("/owner/dorms/:dormId/plans", ownerOnly, async (req, res) => {
    const dormId = toId(req.params.dormId);
    if (!dormId || !(await ownsDorm(dormId, req.user.id))) return fail(res, 404, "ไม่พบหอพักของคุณ");
    const enabled = await enabledPlans(dormId);
    res.json({
      success: true,
      data: PLAN_KEYS.map((k) => ({
        plan: k, label: PLANS[k].label, rate: PLANS[k].rate, rateLabel: PLANS[k].rateLabel, active: enabled.includes(k),
      })),
    });
  });

  router.put("/owner/dorms/:dormId/plans", ownerOnly, async (req, res) => {
    const dormId = toId(req.params.dormId);
    if (!dormId || !(await ownsDorm(dormId, req.user.id))) return fail(res, 404, "ไม่พบหอพักของคุณ");
    const plans = req.body?.plans;
    if (!Array.isArray(plans) || plans.length === 0) return fail(res, 400, "ต้องส่ง plans เป็นรายการ");
    for (const p of plans) {
      if (!PLAN_KEYS.includes(p?.plan)) return fail(res, 400, "plan ต้องเป็น week, month, term หรือ year");
      if (typeof p.active !== "boolean") return fail(res, 400, "active ต้องเป็น true หรือ false");
    }
    // ส่งมาเฉพาะบางแบบได้ -> แบบที่ไม่ได้ส่งใช้ค่าเดิม แล้วเช็กว่ายังเปิดให้เช่าอย่างน้อย 1 แบบ
    const current = await enabledPlans(dormId);
    const activeAfter = PLAN_KEYS.filter((k) => {
      const sent = plans.find((p) => p.plan === k);
      return sent ? sent.active : current.includes(k);
    });
    if (activeAfter.length === 0) return fail(res, 400, "ต้องเปิดให้เช่าอย่างน้อย 1 แบบ");
    // บันทึกครบทั้ง 4 แบบ (หอที่ยังไม่เคยตั้ง จะได้ไม่กลายเป็น "ปิด" แบบที่ไม่ได้ส่งมา)
    for (const k of PLAN_KEYS) {
      await db.query(
        `INSERT INTO dorm_rent_plans (dorm_id, plan, price, is_active) VALUES (?, ?, 0, ?)
         ON DUPLICATE KEY UPDATE is_active = VALUES(is_active)`,
        [dormId, k, activeAfter.includes(k) ? 1 : 0]
      );
    }
    res.json({ success: true });
  });

  return router;
};

module.exports.ensureSchema = ensureSchema;
module.exports.PLANS = PLANS;
module.exports.priceFor = priceFor;
module.exports.STATUS_LABEL = STATUS_LABEL;
