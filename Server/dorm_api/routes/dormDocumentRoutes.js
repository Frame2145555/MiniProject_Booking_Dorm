"use strict";
// เอกสารแนบของคำขอลงประกาศหอ (หลักฐานกรรมสิทธิ์ / ทะเบียนพาณิชย์) -- ให้แอดมินเปิดดูไฟล์ได้จริง
//
// เจ้าของหอส่งไฟล์มากับ POST /api/owner/dorms ในช่อง documents[].fileData (data URL เหมือนระบบ KYC)
// ตัวไฟล์เก็บลงดิสก์ที่ storage/dorm_documents/<dormId>/ (ไม่ได้เปิดเป็น static ให้คนทั่วไปเข้า)
// ส่วนฐานข้อมูลเก็บแค่ที่อยู่ไฟล์ใน dorm_documents.private_storage_key
// (ไม่เก็บไฟล์ลง MySQL ตรงๆ เพราะ XAMPP ตั้ง max_allowed_packet ไว้ 1 MB -> ไฟล์ใหญ่จะทำให้ MySQL ตัดการเชื่อมต่อ)
//
//   GET /api/admin/dorm-documents/:id        (แอดมิน) ข้อมูลเอกสาร + ไฟล์ (data URL) ไว้แสดงในแอป
//   GET /api/admin/dorm-documents/:id/link   (แอดมิน) ลิงก์ชั่วคราว 10 นาที ไว้เปิดในเบราว์เซอร์ (เช่นไฟล์ PDF)
//   GET /api/files/dorm-documents/:id?exp=&sig=   เปิดไฟล์จากลิงก์ชั่วคราว (ไม่ต้องมี token แต่ลายเซ็นต้องถูก)
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const express = require("express");

// โฟลเดอร์เก็บไฟล์เอกสาร (อยู่นอก uploads/ เพื่อไม่ให้เปิดดูได้โดยไม่ผ่านลิงก์ที่มีลายเซ็น)
const STORAGE_ROOT = path.join(__dirname, "..", "storage");
const KEY_PREFIX = "storage/dorm_documents/";
const EXT_BY_MIME = {
  "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif", "application/pdf": "pdf",
};

const ALLOWED_MIME = ["image/png", "image/jpeg", "image/webp", "image/gif", "application/pdf"];
const MAX_DATA_URL_LENGTH = 8_000_000; // ~6 MB ไฟล์จริง (base64 ใหญ่กว่าไฟล์ ~33%)
const LINK_TTL_SECONDS = 10 * 60;

/** แยก data URL -> { mime, base64 } หรือ null ถ้าไม่ใช่ไฟล์ที่รับ */
const parseDataUrl = (value) => {
  if (typeof value !== "string" || value.length > MAX_DATA_URL_LENGTH) return null;
  const m = /^data:([a-z]+\/[a-z0-9.+-]+);base64,([A-Za-z0-9+/=\s]+)$/i.exec(value);
  if (!m) return null;
  const mime = m[1].toLowerCase() === "image/jpg" ? "image/jpeg" : m[1].toLowerCase();
  if (!ALLOWED_MIME.includes(mime)) return null;
  return { mime, base64: m[2].replace(/\s/g, "") };
};

/** ใช้ใน ownerController.createDorm: คืน { buffer, mimeType } (ไม่มีไฟล์ = null) หรือ { error } */
const validateDocumentFile = (doc) => {
  if (doc?.fileData == null || doc.fileData === "") return { buffer: null, mimeType: null };
  const parsed = parseDataUrl(doc.fileData);
  if (!parsed) {
    return { error: "ไฟล์เอกสารต้องเป็น PDF, JPG, PNG, WEBP หรือ GIF และมีขนาดไม่เกิน 6 MB" };
  }
  return { buffer: Buffer.from(parsed.base64, "base64"), mimeType: parsed.mime };
};

/** บันทึกไฟล์ลงดิสก์ -> คืน key (เช่น storage/dorm_documents/12/1795...-ab12cd34.pdf) ไว้เก็บใน private_storage_key */
const saveDocumentFile = async (dormId, buffer, mimeType) => {
  const dir = path.join(STORAGE_ROOT, "dorm_documents", String(dormId));
  await fs.promises.mkdir(dir, { recursive: true });
  const name = `${Date.now()}-${crypto.randomBytes(4).toString("hex")}.${EXT_BY_MIME[mimeType] || "bin"}`;
  await fs.promises.writeFile(path.join(dir, name), buffer);
  return `${KEY_PREFIX}${dormId}/${name}`;
};

/** แปลง key -> path จริง (กันไม่ให้หลุดออกนอกโฟลเดอร์ storage) */
const keyToPath = (key) => {
  if (typeof key !== "string" || !key.startsWith(KEY_PREFIX)) return null;
  const full = path.resolve(path.join(__dirname, ".."), key);
  return full.startsWith(path.resolve(STORAGE_ROOT) + path.sep) ? full : null;
};

/** ลบไฟล์ที่เขียนไปแล้ว (ใช้ตอนบันทึกหอไม่สำเร็จ) */
const removeDocumentFiles = async (keys) => {
  for (const key of keys) {
    const file = keyToPath(key);
    if (file) await fs.promises.unlink(file).catch(() => {});
  }
};

/** อ่านไฟล์ของเอกสาร: รองรับทั้งไฟล์บนดิสก์ และแถวที่เคยเก็บเป็น data URL ใน file_data */
const readDocumentFile = async (doc) => {
  const file = keyToPath(doc?.storageKey);
  if (file) {
    try {
      return { buffer: await fs.promises.readFile(file), mime: doc.mimeType || "application/octet-stream" };
    } catch {
      return null;
    }
  }
  const parsed = parseDataUrl(doc?.fileData);
  return parsed ? { buffer: Buffer.from(parsed.base64, "base64"), mime: parsed.mime } : null;
};

/** เงื่อนไข SQL ว่าเอกสารมีตัวไฟล์ (ใช้ใน adminRoutes / adminController) */
const HAS_FILE_SQL = `(file_data IS NOT NULL OR private_storage_key LIKE '${KEY_PREFIX}%')`;

const ensureSchema = async (pool) => {
  for (const statement of [
    "ALTER TABLE dorm_documents ADD COLUMN file_data LONGTEXT NULL",
    "ALTER TABLE dorm_documents ADD COLUMN mime_type VARCHAR(100) NULL",
  ]) {
    try {
      await pool.promise().query(statement);
    } catch (error) {
      if (error.code !== "ER_DUP_FIELDNAME" && error.code !== "ER_DUP_FIELD_NAME") throw error;
    }
  }
};

module.exports = (db, auth, jwtSecret) => {
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });
  const sign = (id, exp) =>
    crypto.createHmac("sha256", `${jwtSecret}:dorm-document`).update(`${id}.${exp}`).digest("hex");

  const loadDocument = async (id) => {
    const [[doc]] = await db.query(
      `SELECT dd.id, dd.dorm_id AS dormId, d.name AS dormName, dd.document_type AS type,
              dd.display_name AS name, dd.mime_type AS mimeType, dd.file_data AS fileData,
              dd.private_storage_key AS storageKey
         FROM dorm_documents dd JOIN dorms d ON d.id = dd.dorm_id
        WHERE dd.id = ?`,
      [id]
    );
    return doc;
  };

  const toId = (v) => {
    const n = Number(v);
    return Number.isInteger(n) && n > 0 ? n : null;
  };

  // ---------- แอดมิน ----------
  const adminRouter = express.Router();
  adminRouter.use(auth.requireRole("admin"));

  adminRouter.get("/:id", async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "เลขเอกสารไม่ถูกต้อง");
    const doc = await loadDocument(id);
    if (!doc) return fail(res, 404, "ไม่พบเอกสารนี้");
    const file = await readDocumentFile(doc);
    if (!file) return fail(res, 404, "เอกสารนี้ส่งมาก่อนมีระบบอัปโหลดไฟล์ จึงมีแค่ชื่อไฟล์ ให้เจ้าของหอส่งเอกสารใหม่");
    const { storageKey, fileData, ...info } = doc;
    res.json({
      success: true,
      data: { ...info, mimeType: file.mime, fileData: `data:${file.mime};base64,${file.buffer.toString("base64")}` },
    });
  });

  adminRouter.get("/:id/link", async (req, res) => {
    const id = toId(req.params.id);
    if (!id) return fail(res, 400, "เลขเอกสารไม่ถูกต้อง");
    const [[row]] = await db.query(`SELECT id, ${HAS_FILE_SQL} AS hasFile FROM dorm_documents WHERE id = ?`, [id]);
    if (!row) return fail(res, 404, "ไม่พบเอกสารนี้");
    if (!row.hasFile) return fail(res, 404, "เอกสารนี้ไม่มีไฟล์แนบ");
    const exp = Math.floor(Date.now() / 1000) + LINK_TTL_SECONDS;
    const path = `/api/files/dorm-documents/${id}?exp=${exp}&sig=${sign(id, exp)}`;
    res.json({ success: true, data: { path, expiresAt: new Date(exp * 1000).toISOString() } });
  });

  // ---------- เปิดไฟล์จากลิงก์ชั่วคราว ----------
  const fileRouter = express.Router();
  fileRouter.get("/dorm-documents/:id", async (req, res) => {
    const id = toId(req.params.id);
    const exp = Number(req.query.exp);
    const sig = String(req.query.sig || "");
    const expected = id && Number.isInteger(exp) ? sign(id, exp) : "";
    const valid =
      expected &&
      sig.length === expected.length &&
      crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected)) &&
      exp >= Math.floor(Date.now() / 1000);
    if (!valid) return res.status(403).send("ลิงก์หมดอายุหรือไม่ถูกต้อง กรุณากดดูเอกสารจากหน้าแอดมินอีกครั้ง");
    const doc = await loadDocument(id);
    const file = doc && (await readDocumentFile(doc));
    if (!file) return res.status(404).send("ไม่พบไฟล์เอกสาร");
    const filename = encodeURIComponent(doc.name || `document-${id}`);
    res.set({
      "Content-Type": file.mime,
      "Content-Disposition": `inline; filename*=UTF-8''${filename}`,
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
    });
    res.send(file.buffer);
  });

  return { adminRouter, fileRouter };
};

module.exports.ensureSchema = ensureSchema;
module.exports.validateDocumentFile = validateDocumentFile;
module.exports.saveDocumentFile = saveDocumentFile;
module.exports.removeDocumentFiles = removeDocumentFiles;
module.exports.HAS_FILE_SQL = HAS_FILE_SQL;
