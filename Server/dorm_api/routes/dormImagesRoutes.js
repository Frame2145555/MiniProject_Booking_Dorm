"use strict";
// รูปภาพเพิ่มเติมของหอพัก (ส่วนเสริม ไม่ได้แก้ routes/ownerRoutes.js ของพี่)
//   POST /api/owner/dorms/:dormId/images   body = ไฟล์รูปดิบ (jpg/png/webp/gif ไม่เกิน 8 MB) -> { data: { url } }
//   PUT  /api/owner/dorms/:dormId/images   { images: [url, ...] }  บันทึกรายการรูป (ลำดับตามที่ส่ง, สูงสุด 10)
//   GET  /uploads/dorms/<dormId>/<file>    เสิร์ฟไฟล์รูป (mount ใน server.js)
// ตาราง dorm_images สร้างเองตอนเปิด server (ensureSchema)
// attach(db, dorms) ใส่ dorm.images = [url, ...] ให้รายการหอพัก (ใช้ใน ownerController / tenantController)
const express = require("express");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const UPLOAD_ROOT = path.join(__dirname, "..", "uploads", "dorms");
const MAX_IMAGES = 10;
const MAX_BYTES = 8 * 1024 * 1024;
const MAX_FILES_PER_DORM = 50; // กันอัปโหลดวนจนเต็มดิสก์

// ดูชนิดไฟล์จากไบต์แรก (ไม่เชื่อ Content-Type ที่ client ส่งมา)
function sniffExt(b) {
  if (b.length < 12) return null;
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "jpg";
  if (b.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "png";
  if (b.slice(0, 4).toString("latin1") === "GIF8") return "gif";
  if (b.slice(0, 4).toString("latin1") === "RIFF" && b.slice(8, 12).toString("latin1") === "WEBP") return "webp";
  return null;
}

async function ensureSchema(pool) {
  const p = pool.promise();
  const head = `CREATE TABLE IF NOT EXISTS dorm_images (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    dorm_id BIGINT UNSIGNED NOT NULL,
    url VARCHAR(1000) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_dorm_images_dorm (dorm_id, sort_order)`;
  const tail = `) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`;
  try {
    await p.query(`${head}, CONSTRAINT fk_dorm_images_dorm FOREIGN KEY (dorm_id) REFERENCES dorms(id) ON DELETE CASCADE${tail}`);
  } catch (err) {
    await p.query(`${head}${tail}`); // ถ้าสร้าง foreign key ไม่ได้ ก็สร้างแบบไม่มี FK
  }
}

// ใส่ images ให้รายการหอ (หรือหอเดียว) -- ถ้าตารางยังไม่มีให้เป็น [] ไม่ให้หน้าหลักพัง
async function attach(db, items) {
  const list = (Array.isArray(items) ? items : [items]).filter(Boolean);
  list.forEach((d) => { d.images = []; });
  const ids = list.map((d) => d.id).filter((id) => id !== undefined && id !== null);
  if (!ids.length) return;
  try {
    const [rows] = await db.query("SELECT dorm_id, url FROM dorm_images WHERE dorm_id IN (?) ORDER BY sort_order, id", [ids]);
    const byDorm = new Map();
    for (const r of rows) {
      const key = String(r.dorm_id);
      if (!byDorm.has(key)) byDorm.set(key, []);
      byDorm.get(key).push(r.url);
    }
    list.forEach((d) => { d.images = byDorm.get(String(d.id)) || []; });
  } catch (err) {
    console.error("attach dorm images:", err.message);
  }
}

module.exports = (db, auth) => {
  const router = express.Router();
  const sellerOnly = auth.requireRole("seller");
  const fail = (res, status, message) => res.status(status).json({ success: false, error: message, message });

  const ownedDorm = async (dormId, ownerId) => {
    const [rows] = await db.query("SELECT id FROM dorms WHERE id = ? AND owner_id = ?", [dormId, ownerId]);
    return rows[0];
  };

  const rawBody = (req, res, next) =>
    express.raw({ type: () => true, limit: MAX_BYTES })(req, res, (err) => {
      if (!err) return next();
      if (err.type === "entity.too.large") return fail(res, 413, "รูปใหญ่เกินไป (สูงสุด 8 MB ต่อรูป)");
      return fail(res, 400, "อ่านไฟล์รูปไม่สำเร็จ");
    });

  router.post("/dorms/:dormId/images", sellerOnly, rawBody, async (req, res) => {
    const dormId = Number(req.params.dormId);
    if (!Number.isInteger(dormId) || dormId <= 0) return fail(res, 400, "รหัสหอพักไม่ถูกต้อง");
    try {
      if (!(await ownedDorm(dormId, req.user.id))) return fail(res, 404, "ไม่พบหอพักนี้ หรือไม่ใช่หอพักของคุณ");
      const body = req.body;
      if (!Buffer.isBuffer(body) || body.length === 0) return fail(res, 400, "ไม่พบไฟล์รูป");
      const ext = sniffExt(body);
      if (!ext) return fail(res, 400, "รองรับเฉพาะไฟล์รูป jpg, png, webp, gif");

      const dir = path.join(UPLOAD_ROOT, String(dormId));
      await fs.promises.mkdir(dir, { recursive: true });
      if ((await fs.promises.readdir(dir)).length >= MAX_FILES_PER_DORM) {
        return fail(res, 429, "อัปโหลดรูปของหอนี้มากเกินไป กรุณาลบรูปที่ไม่ใช้ก่อน");
      }
      const name = `${Date.now()}-${crypto.randomBytes(4).toString("hex")}.${ext}`;
      await fs.promises.writeFile(path.join(dir, name), body);
      res.status(201).json({ success: true, data: { url: `/uploads/dorms/${dormId}/${name}` } });
    } catch (err) {
      console.error("Error in POST /api/owner/dorms/:dormId/images:", err);
      fail(res, 500, "Internal server error");
    }
  });

  router.put("/dorms/:dormId/images", sellerOnly, async (req, res) => {
    const dormId = Number(req.params.dormId);
    if (!Number.isInteger(dormId) || dormId <= 0) return fail(res, 400, "รหัสหอพักไม่ถูกต้อง");
    const images = req.body?.images;
    if (!Array.isArray(images) || images.length > MAX_IMAGES) return fail(res, 400, `ใส่รูปเพิ่มเติมได้สูงสุด ${MAX_IMAGES} รูป`);

    const prefix = `/uploads/dorms/${dormId}/`;
    const urls = [];
    for (const raw of images) {
      const u = String(raw ?? "").trim();
      const isLink = /^https?:\/\//i.test(u);
      const isUpload = u.startsWith(prefix) && /^[A-Za-z0-9._-]+$/.test(u.slice(prefix.length)) && !u.includes("..");
      if (!u || u.length > 1000 || !(isLink || isUpload)) return fail(res, 400, "รูปแบบลิงก์รูปไม่ถูกต้อง");
      if (!urls.includes(u)) urls.push(u);
    }

    let conn;
    try {
      if (!(await ownedDorm(dormId, req.user.id))) return fail(res, 404, "ไม่พบหอพักนี้ หรือไม่ใช่หอพักของคุณ");
      const [oldRows] = await db.query("SELECT url FROM dorm_images WHERE dorm_id = ?", [dormId]);
      conn = await db.getConnection();
      await conn.beginTransaction();
      await conn.query("DELETE FROM dorm_images WHERE dorm_id = ?", [dormId]);
      if (urls.length) {
        await conn.query("INSERT INTO dorm_images (dorm_id, url, sort_order) VALUES ?", [urls.map((u, i) => [dormId, u, i])]);
      }
      await conn.commit();
      // ลบไฟล์ที่เจ้าของเอาออกจากรายการแล้ว (เฉพาะไฟล์ที่อัปโหลดไว้ในโฟลเดอร์ของหอนี้)
      for (const r of oldRows) {
        if (r.url.startsWith(prefix) && !urls.includes(r.url)) {
          fs.promises.unlink(path.join(UPLOAD_ROOT, String(dormId), path.basename(r.url))).catch(() => {});
        }
      }
      res.json({ success: true, message: "บันทึกรูปภาพเพิ่มเติมแล้ว", data: { images: urls } });
    } catch (err) {
      if (conn) await conn.rollback().catch(() => {});
      console.error("Error in PUT /api/owner/dorms/:dormId/images:", err);
      fail(res, 500, "Internal server error");
    } finally {
      if (conn) conn.release();
    }
  });

  return router;
};
module.exports.ensureSchema = ensureSchema;
module.exports.attach = attach;
