"use strict";
// =====================================================================
//  Dorm Master — ระบบ Search & Sort หอพัก (ฐานข้อมูล dorm_master)
//  ใช้งาน:  app.use("/api", require("./searchandsort")(db));
//
//  GET /api/dorms        ค้นหา + กรอง + เรียง + แบ่งหน้า
//     q             คำค้น (ชื่อหอ/ที่อยู่/รายละเอียด) หลายคำ = ต้องตรงทุกคำ
//     min_price     ราคาต่ำสุดที่รับได้   max_price  ราคาสูงสุดที่รับได้
//                   (หอที่ช่วงราคา "ทับซ้อน" กับช่วงที่เลือก — ตรงกับตัวกรองใน Flutter)
//     amenities     ชื่อสิ่งอำนวยความสะดวก คั่นด้วย , (ต้องมีครบทุกอย่าง) เช่น แอร์,Wi-Fi
//     available_only=1   เฉพาะหอที่มีห้องว่าง
//     lat, lng, radius_km  จุดอ้างอิง (+ จำกัดรัศมี)  ใช้คู่กับ sort=distance
//     sort          newest(ค่าเริ่มต้น) | price_asc | price_desc | name | popular | distance
//     page, limit   หน้า (เริ่ม 1) / จำนวนต่อหน้า (1-50, ค่าเริ่มต้น 20)
//  GET /api/dorms/:id   รายละเอียดหอ + ห้อง
//  GET /api/amenities   รายการสิ่งอำนวยความสะดวก (ไว้ทำตัวกรอง)
//
//  แสดงเฉพาะหอ approved + active และเจ้าของบัญชียังไม่ถูกระงับ (ตรงกับ isDormClosed ใน Flutter)
//  หมายเหตุ: ฐานข้อมูลนี้ยังไม่มีตารางรีวิว จึงส่ง rating = null และยังไม่มี sort ตามคะแนน
// =====================================================================

const SORT_ORDER = {
  newest: "d.created_at DESC, d.id DESC",
  price_asc:
    "(COALESCE(d.price_min_month, d.price_max_month) IS NULL), COALESCE(d.price_min_month, d.price_max_month) ASC, d.id ASC",
  price_desc:
    "(COALESCE(d.price_max_month, d.price_min_month) IS NULL), COALESCE(d.price_max_month, d.price_min_month) DESC, d.id ASC",
  name: "d.name ASC, d.id ASC",
  popular: "view_count DESC, d.created_at DESC, d.id DESC",
  distance: "(distance_km IS NULL), distance_km ASC, d.id ASC",
};

// เฉพาะหอที่ผู้เช่าควรเห็น
const VISIBLE_WHERE = "d.approval_status = 'approved' AND d.listing_status = 'active'";
const VISIBLE_JOIN = "JOIN users o ON o.id = d.owner_id AND o.account_status = 'active'";

const toNum = (v) => (v === undefined || v === null || String(v).trim() === "" ? null : Number(v));
const isInt = (n) => Number.isInteger(n);
const escapeLike = (s) => s.replace(/[\\%_]/g, "\\$&");
const first = (v) => (Array.isArray(v) ? v[0] : v);

// แปลง query string -> { error } หรือ { opts }
function parseSearch(query) {
  const q = query || {};
  const opts = {};

  const text = typeof first(q.q) === "string" ? first(q.q).trim() : "";
  if (text.length > 100) return { error: "คำค้นยาวเกิน 100 ตัวอักษร" };
  opts.words = text.split(/\s+/).filter(Boolean).slice(0, 5);

  for (const key of ["min_price", "max_price"]) {
    const n = toNum(first(q[key]));
    if (n === null) {
      opts[key] = null;
    } else if (!isInt(n) || n < 0 || n > 10_000_000) {
      return { error: `${key} ต้องเป็นจำนวนเต็ม 0-10,000,000` };
    } else {
      opts[key] = n;
    }
  }
  if (opts.min_price !== null && opts.max_price !== null && opts.min_price > opts.max_price) {
    return { error: "min_price ต้องไม่มากกว่า max_price" };
  }

  const raw = [].concat(q.amenities ?? []).flatMap((s) => String(s).split(","));
  opts.amenities = [...new Set(raw.map((s) => s.trim()).filter(Boolean))];
  if (opts.amenities.length > 15) return { error: "เลือกสิ่งอำนวยความสะดวกได้ไม่เกิน 15 อย่าง" };

  const av = String(first(q.available_only) ?? "").toLowerCase();
  opts.availableOnly = av === "1" || av === "true";

  const lat = toNum(first(q.lat));
  const lng = toNum(first(q.lng));
  if ((lat === null) !== (lng === null)) return { error: "ต้องระบุ lat และ lng คู่กัน" };
  if (lat !== null) {
    if (!Number.isFinite(lat) || lat < -90 || lat > 90) return { error: "lat ต้องอยู่ระหว่าง -90 ถึง 90" };
    if (!Number.isFinite(lng) || lng < -180 || lng > 180) return { error: "lng ต้องอยู่ระหว่าง -180 ถึง 180" };
  }
  opts.lat = lat;
  opts.lng = lng;

  const radius = toNum(first(q.radius_km));
  if (radius !== null) {
    if (lat === null) return { error: "radius_km ต้องใช้คู่กับ lat/lng" };
    if (!Number.isFinite(radius) || radius <= 0 || radius > 500) return { error: "radius_km ต้องอยู่ระหว่าง 0-500" };
  }
  opts.radius = radius;

  opts.sort = first(q.sort) ? String(first(q.sort)) : "newest";
  if (!Object.prototype.hasOwnProperty.call(SORT_ORDER, opts.sort)) {
    return { error: `sort ต้องเป็นหนึ่งใน: ${Object.keys(SORT_ORDER).join(", ")}` };
  }
  if (opts.sort === "distance" && lat === null) return { error: "sort=distance ต้องระบุ lat และ lng" };

  const page = toNum(first(q.page)) ?? 1;
  const limit = toNum(first(q.limit)) ?? 20;
  if (!isInt(page) || page < 1 || page > 100000) return { error: "page ต้องเป็นจำนวนเต็ม ≥ 1" };
  if (!isInt(limit) || limit < 1 || limit > 50) return { error: "limit ต้องเป็นจำนวนเต็ม 1-50" };
  opts.page = page;
  opts.limit = limit;
  return { opts };
}

// สร้าง SQL (ใช้ ? ทั้งหมด ไม่ต่อ string จากผู้ใช้) — ลำดับ params ต้องตรงกับลำดับ ? ใน SQL
function buildQuery(opts) {
  const params = [];
  const where = [VISIBLE_WHERE];
  let distanceSelect = "";

  if (opts.lat !== null) {
    distanceSelect = `,
      6371 * ACOS(LEAST(1, COS(RADIANS(?)) * COS(RADIANS(d.latitude)) * COS(RADIANS(d.longitude) - RADIANS(?))
                           + SIN(RADIANS(?)) * SIN(RADIANS(d.latitude)))) AS distance_km`;
    params.push(opts.lat, opts.lng, opts.lat); // อยู่ใน SELECT จึงมาก่อน WHERE
  }

  const whereParams = [];
  for (const w of opts.words) {
    where.push("(d.name LIKE ? OR d.address LIKE ? OR d.description LIKE ?)");
    const like = `%${escapeLike(w)}%`;
    whereParams.push(like, like, like);
  }
  if (opts.min_price !== null) {
    where.push("COALESCE(d.price_max_month, d.price_min_month) >= ?");
    whereParams.push(opts.min_price);
  }
  if (opts.max_price !== null) {
    where.push("COALESCE(d.price_min_month, d.price_max_month) <= ?");
    whereParams.push(opts.max_price);
  }
  if (opts.amenities.length) {
    where.push(`(SELECT COUNT(DISTINCT a.id) FROM dorm_amenities da JOIN amenities a ON a.id = da.amenity_id
                 WHERE da.dorm_id = d.id AND a.name IN (?)) = ?`);
    whereParams.push(opts.amenities, opts.amenities.length);
  }
  if (opts.availableOnly) {
    where.push("EXISTS (SELECT 1 FROM rooms r2 WHERE r2.dorm_id = d.id AND r2.status = 'available')");
  }
  params.push(...whereParams);

  let having = "";
  if (opts.radius !== null) {
    having = "HAVING distance_km <= ?";
    params.push(opts.radius);
  }

  const inner = `SELECT d.id, d.name, d.address, d.description, d.price_min_month, d.price_max_month,
      d.cover_image_url, d.latitude, d.longitude, d.phone, d.created_at,
      COALESCE(v.views, 0) AS view_count,
      (SELECT COUNT(*) FROM rooms r WHERE r.dorm_id = d.id AND r.status = 'available') AS available_rooms${distanceSelect}
    FROM dorms d
    ${VISIBLE_JOIN}
    LEFT JOIN (SELECT dorm_id, COUNT(*) AS views FROM dorm_view_events
               WHERE viewed_at >= NOW() - INTERVAL 30 DAY GROUP BY dorm_id) v ON v.dorm_id = d.id
    WHERE ${where.join(" AND ")}
    ${having}`;

  return {
    countSql: `SELECT COUNT(*) AS total FROM (${inner}) x`,
    dataSql: `${inner} ORDER BY ${SORT_ORDER[opts.sort]} LIMIT ? OFFSET ?`,
    params,
    dataParams: [...params, opts.limit, (opts.page - 1) * opts.limit],
  };
}

const fmt = (n) => Number(n).toLocaleString("en-US");
function priceText(min, max) {
  if (min == null && max == null) return "สอบถามราคา";
  if (min == null || max == null || min === max) return fmt(min ?? max);
  return `${fmt(min)} - ${fmt(max)}`;
}

// รูปแบบ key เดียวกับที่ DormCard / DormDetailView ของ Flutter ใช้
function toDormJson(r, tags) {
  return {
    id: r.id,
    title: r.name,
    location: r.address,
    description: r.description,
    price: priceText(r.price_min_month, r.price_max_month),
    minPrice: r.price_min_month,
    maxPrice: r.price_max_month,
    phone: r.phone,
    imageUrl: r.cover_image_url || "",
    latitude: r.latitude === null || r.latitude === undefined ? null : Number(r.latitude),
    longitude: r.longitude === null || r.longitude === undefined ? null : Number(r.longitude),
    rating: null,
    tags: tags || [],
    view_count: Number(r.view_count ?? 0),
    available_rooms: Number(r.available_rooms ?? 0),
    ...(r.distance_km !== undefined && { distance_km: r.distance_km === null ? null : Math.round(r.distance_km * 100) / 100 }),
  };
}

async function loadTags(db, ids) {
  const map = new Map();
  if (!ids.length) return map;
  const [rows] = await db.query(
    `SELECT da.dorm_id, a.name FROM dorm_amenities da JOIN amenities a ON a.id = da.amenity_id
     WHERE da.dorm_id IN (?) ORDER BY a.id`,
    [ids]
  );
  for (const r of rows) {
    if (!map.has(r.dorm_id)) map.set(r.dorm_id, []);
    map.get(r.dorm_id).push(r.name);
  }
  return map;
}

module.exports = function createSearch(db) {
  const express = require("express");
  const router = express.Router();

  router.get("/dorms", async (req, res) => {
    const { error, opts } = parseSearch(req.query);
    if (error) return res.status(400).json({ error });

    const q = buildQuery(opts);
    const [[countRow], [rows]] = await Promise.all([
      db.query(q.countSql, q.params),
      db.query(q.dataSql, q.dataParams),
    ]);
    const total = Number(countRow[0].total);
    const tags = await loadTags(db, rows.map((r) => r.id));
    res.json({
      items: rows.map((r) => toDormJson(r, tags.get(r.id))),
      page: opts.page,
      limit: opts.limit,
      total,
      total_pages: Math.ceil(total / opts.limit),
      sort: opts.sort,
    });
  });

  router.get("/dorms/:id", async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ error: "id ไม่ถูกต้อง" });
    const [rows] = await db.query(
      `SELECT d.id, d.name, d.address, d.description, d.price_min_month, d.price_max_month,
              d.cover_image_url, d.latitude, d.longitude, d.phone, d.created_at, 0 AS view_count,
              (SELECT COUNT(*) FROM rooms r WHERE r.dorm_id = d.id AND r.status = 'available') AS available_rooms
       FROM dorms d ${VISIBLE_JOIN} WHERE d.id = ? AND ${VISIBLE_WHERE}`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: "ไม่พบหอพัก" });
    const tags = await loadTags(db, [id]);
    const [rooms] = await db.query(
      `SELECT id, room_number, room_type, price_per_month, floor, status
       FROM rooms WHERE dorm_id = ? ORDER BY floor, room_number`,
      [id]
    );
    res.json({ ...toDormJson(rows[0], tags.get(id)), rooms });
  });

  router.get("/amenities", async (req, res) => {
    const [rows] = await db.query("SELECT id, name FROM amenities ORDER BY id");
    res.json(rows);
  });

  return router;
};

module.exports._test = { parseSearch, buildQuery, priceText, escapeLike };
