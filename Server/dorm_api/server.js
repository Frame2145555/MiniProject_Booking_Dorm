"use strict";
// Dorm Master — จุดเริ่มต้น server   รัน: node server.js
// ตั้งค่า: app.json (พอร์ต), db-config.json (ฐานข้อมูล → ต้องเป็น dorm_master), JWT_SECRET (env หรือ app.json: jwt_secret)
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");

const appCfg = require("./app.json");
const db = mysql.createPool({ ...require("./db-config.json"), charset: "utf8mb4", connectionLimit: 10 });

const app = express();
app.use(cors());
app.use(express.json({ limit: "100kb" }));

const auth = require("./loginandregister")(db, { jwtSecret: appCfg.jwt_secret });
app.use("/api", auth.router);                  // POST /api/register, /api/login · GET /api/me
app.use("/api", require("./searchandsort")(db)); // GET /api/dorms, /api/dorms/:id, /api/amenities

app.get("/", (req, res) => res.json({ message: "Dorm Master server is running" }));

// error handler กลาง (Express 5 ส่ง error จาก async handler มาที่นี่เอง)
app.use((err, req, res, next) => {
  if (err.type === "entity.parse.failed") return res.status(400).json({ error: "JSON ไม่ถูกต้อง" });
  console.error(err);
  res.status(500).json({ error: "เซิร์ฟเวอร์ผิดพลาด" });
});

const PORT = appCfg.port || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
