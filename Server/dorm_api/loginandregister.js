"use strict";
// =====================================================================
//  Dorm Master — ระบบ Login / Register  (ใช้กับฐานข้อมูล dorm_master)
//  ใช้งาน:  const auth = require("./loginandregister")(db, { jwtSecret });
//           app.use("/api", auth.router);     // POST /api/register, /api/login, GET /api/me
//           auth.verifyToken / auth.requireRole("admin") ไว้ป้องกัน route อื่น
//
//  Response ของ login/register ตรงกับที่ Flutter (AuthService) อ่าน:
//     { token, id, role, full_name, email }
//  Status code: 400 ข้อมูลไม่ถูกต้อง | 401 อีเมล/รหัสผ่านผิด หรือ token ใช้ไม่ได้
//               403 บัญชีถูกระงับ | 409 อีเมลซ้ำ | 429 ลองบ่อยเกินไป
// =====================================================================
const crypto = require("crypto");

const SELF_REGISTER_ROLES = ["tenant", "seller"]; // admin สมัครเองไม่ได้ (สร้างใน DB เท่านั้น)
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const PHONE_RE = /^[0-9+\-\s()]{6,30}$/;

const normalizeEmail = (v) => (typeof v === "string" ? v.trim().toLowerCase() : "");

// ตรวจข้อมูลสมัครสมาชิก -> { error } หรือ { value }
function validateRegister(body) {
  const b = body || {};
  const email = normalizeEmail(b.email);
  const password = b.password;
  const fullName = typeof b.full_name === "string" ? b.full_name.trim().replace(/\s+/g, " ") : "";
  const phone = typeof b.phone === "string" && b.phone.trim() !== "" ? b.phone.trim() : null;
  const role = b.role === undefined || b.role === null || b.role === "" ? "tenant" : b.role;

  if (!email || email.length > 254 || !EMAIL_RE.test(email)) return { error: "รูปแบบอีเมลไม่ถูกต้อง" };
  if (typeof password !== "string" || password.length < 8) return { error: "รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร" };
  if (password.length > 128) return { error: "รหัสผ่านต้องไม่เกิน 128 ตัวอักษร" };
  if (password.trim() === "") return { error: "รหัสผ่านต้องไม่เป็นช่องว่างล้วน" };
  if (fullName.length < 1 || fullName.length > 150) return { error: "กรุณากรอกชื่อ (ไม่เกิน 150 ตัวอักษร)" };
  if (phone !== null && !PHONE_RE.test(phone)) return { error: "รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง" };
  if (!SELF_REGISTER_ROLES.includes(role)) return { error: "role ต้องเป็น tenant หรือ seller" };

  return { value: { email, password, fullName, phone, role } };
}

// จำกัดจำนวนครั้งที่ลองผิด (เก็บใน memory — รีสตาร์ท server แล้วรีเซ็ต)
function makeLimiter({ windowMs, max }) {
  const map = new Map();
  const timer = setInterval(() => {
    const now = Date.now();
    for (const [k, v] of map) if (v.reset <= now) map.delete(k);
  }, windowMs);
  if (timer.unref) timer.unref();
  const live = (k) => {
    const r = map.get(k);
    return r && r.reset > Date.now() ? r : null;
  };
  return {
    blocked: (k) => (live(k) ? live(k).count >= max : false),
    retryAfterSec: (k) => (live(k) ? Math.ceil((live(k).reset - Date.now()) / 1000) : 0),
    fail(k) {
      const r = live(k);
      if (r) r.count++;
      else map.set(k, { count: 1, reset: Date.now() + windowMs });
    },
    reset: (k) => map.delete(k),
  };
}

function resolveSecret(cfgSecret) {
  const s = process.env.JWT_SECRET || cfgSecret;
  if (s) {
    if (String(s).length < 16) throw new Error("JWT_SECRET ต้องยาวอย่างน้อย 16 ตัวอักษร");
    return String(s);
  }
  if (process.env.NODE_ENV === "production") throw new Error("ต้องตั้งค่า JWT_SECRET ก่อนรัน production");
  console.warn("[auth] ไม่ได้ตั้ง JWT_SECRET → สุ่ม secret ชั่วคราว (รีสตาร์ท server แล้วทุกคนต้อง login ใหม่)");
  return crypto.randomBytes(48).toString("hex");
}

module.exports = function createAuth(db, options = {}) {
  const express = require("express");
  const argon2 = require("@node-rs/argon2");
  const jwt = require("jsonwebtoken");

  const secret = resolveSecret(options.jwtSecret);
  const expiresIn = options.expiresIn || "1d";
  const loginLimiter = makeLimiter({ windowMs: 15 * 60 * 1000, max: 8 }); // ผิด 8 ครั้ง/15 นาที ต่อ IP+อีเมล
  const registerLimiter = makeLimiter({ windowMs: 60 * 60 * 1000, max: 20 }); // สมัคร 20 ครั้ง/ชม. ต่อ IP

  // hash หลอก ไว้ verify เมื่อไม่พบอีเมล เพื่อให้เวลาตอบใกล้เคียงกัน (กันเดาว่าอีเมลมีในระบบ)
  let dummyHashPromise = null;
  const dummyHash = () => (dummyHashPromise ??= argon2.hash("dummy-password-for-timing"));

  const sessionOf = (u) => ({
    token: jwt.sign({ id: u.id, role: u.role }, secret, { expiresIn, algorithm: "HS256" }),
    id: u.id,
    role: u.role,
    full_name: u.full_name,
    email: u.email,
  });

  // ---------- middleware ----------
  async function verifyToken(req, res, next) {
    const m = /^Bearer (.+)$/i.exec(req.header("authorization") || "");
    if (!m) return res.status(401).json({ error: "กรุณาเข้าสู่ระบบ" });
    let payload;
    try {
      payload = jwt.verify(m[1], secret, { algorithms: ["HS256"] });
    } catch {
      return res.status(401).json({ error: "เซสชันหมดอายุหรือไม่ถูกต้อง กรุณาเข้าสู่ระบบใหม่" });
    }
    // ดึงสถานะล่าสุดจาก DB → ถูกระงับ/เปลี่ยน role แล้วมีผลทันที ไม่ต้องรอ token หมดอายุ
    const [rows] = await db.query(
      "SELECT id, email, full_name, role, account_status FROM users WHERE id = ? LIMIT 1",
      [payload.id]
    );
    const u = rows[0];
    if (!u) return res.status(401).json({ error: "ไม่พบบัญชีนี้" });
    if (u.account_status !== "active") return res.status(403).json({ error: "บัญชีนี้ถูกระงับ" });
    req.user = { id: u.id, email: u.email, full_name: u.full_name, role: u.role };
    next();
  }

  const requireRole = (...roles) => [
    verifyToken,
    (req, res, next) =>
      roles.includes(req.user.role) ? next() : res.status(403).json({ error: "ไม่มีสิทธิ์ใช้งานส่วนนี้" }),
  ];

  // ---------- routes ----------
  const router = express.Router();

  router.post("/register", async (req, res) => {
    const ipKey = `reg|${req.ip}`;
    if (registerLimiter.blocked(ipKey)) {
      res.set("Retry-After", String(registerLimiter.retryAfterSec(ipKey)));
      return res.status(429).json({ error: "สมัครบ่อยเกินไป กรุณาลองใหม่ภายหลัง" });
    }
    registerLimiter.fail(ipKey); // นับทุกครั้งที่เรียก (กันสแปมสมัคร)

    const { error, value } = validateRegister(req.body);
    if (error) return res.status(400).json({ error });

    const hash = await argon2.hash(value.password); // argon2id ค่าเริ่มต้น ตรงกับ hash ใน dump
    try {
      const [r] = await db.query(
        "INSERT INTO users (email, password, full_name, phone, role) VALUES (?, ?, ?, ?, ?)",
        [value.email, hash, value.fullName, value.phone, value.role]
      );
      res.status(201).json(
        sessionOf({ id: r.insertId, role: value.role, full_name: value.fullName, email: value.email })
      );
    } catch (e) {
      if (e && e.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "อีเมลนี้ถูกใช้งานแล้ว" });
      throw e;
    }
  });

  router.post("/login", async (req, res) => {
    const email = normalizeEmail(req.body?.email ?? req.body?.username); // รับ username เดิมได้ด้วย
    const password = req.body?.password;
    if (!email || typeof password !== "string" || password === "" || password.length > 128) {
      return res.status(400).json({ error: "กรุณากรอกอีเมลและรหัสผ่าน" });
    }

    const key = `login|${req.ip}|${email}`;
    if (loginLimiter.blocked(key)) {
      res.set("Retry-After", String(loginLimiter.retryAfterSec(key)));
      return res.status(429).json({ error: "ลองเข้าสู่ระบบผิดหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่" });
    }

    const [rows] = await db.query(
      "SELECT id, email, password, full_name, role, account_status FROM users WHERE email = ? LIMIT 1",
      [email]
    );
    const user = rows[0];
    const hash = user && user.password ? user.password : await dummyHash();
    let ok = false;
    try {
      ok = await argon2.verify(hash, password);
    } catch {
      ok = false;
    }
    if (!user || !user.password || !ok) {
      loginLimiter.fail(key);
      return res.status(401).json({ error: "อีเมลหรือรหัสผ่านไม่ถูกต้อง" });
    }
    if (user.account_status !== "active") {
      return res.status(403).json({ error: "บัญชีนี้ถูกระงับ" }); // บอกเฉพาะคนที่รหัสผ่านถูกต้อง
    }
    loginLimiter.reset(key);
    res.json(sessionOf(user));
  });

  router.get("/me", verifyToken, (req, res) => res.json(req.user));

  return { router, verifyToken, requireRole };
};

module.exports._test = { validateRegister, makeLimiter, normalizeEmail };
