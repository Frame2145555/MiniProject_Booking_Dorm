"use strict";
// Dorm Master — จุดเริ่มต้น server   รัน: node server.js
// ตั้งค่า: app.json (พอร์ต + jwt_secret), db-config.json (ฐานข้อมูล → ต้องเป็น dorm_master)
//         JWT_SECRET ใน env จะใช้แทน jwt_secret ใน app.json (login และแชทใช้ key เดียวกัน)
const http = require("http");
const express = require("express"); // ต้องเป็น Express 5 (ดู package.json) ไม่งั้น error จาก async ทำ server ล่ม
const cors = require("cors");
const mysql = require("mysql2");
const jsonServer = require("json-server");
const { Server } = require("socket.io");

const appCfg = require("./app.json");
// ระบบหอ/จองของพี่ (Tmiddleware/auth.js, Tcontrollers/authController.js) อ่าน key จาก process.env.JWT_SECRET
// ตั้งให้เป็นค่าเดียวกับ app.json -> token จาก /api/login ใช้ได้ทั้งแชท ระบบหอ และระบบจอง
if (!process.env.JWT_SECRET) process.env.JWT_SECRET = appCfg.jwt_secret;
// pool เดียว ใช้ได้ 2 แบบ: promise (login/search) และ callback (แชท)
const pool = mysql.createPool({ ...require("./db-config.json"), charset: "utf8mb4", connectionLimit: 10 });
const db = pool.promise();

const app = express();
app.use(cors());
app.use(express.json({ limit: "100kb" }));

const auth = require("./loginandregister")(db, { jwtSecret: appCfg.jwt_secret });
app.use("/api", auth.router);                                  // POST /api/register, /api/login · GET /api/me
app.use("/api", require("./searchandsort")(db));               // GET /api/dorms, /api/dorms/:id, /api/amenities
app.use("/api", require("./chat_routes")(pool, auth.verifyToken)); // /api/conversations ... (แชท)
app.use("/api/owner", require("./Troutes/ownerRoutes"));       // ระบบเจ้าของหอ (ของพี่): /api/owner/...
app.use("/api/tenant", require("./Troutes/tenantRoutes"));     // ระบบค้นหา/จอง (ของพี่): /api/tenant/...
// ไม่ได้ mount Troutes/authRoutes (/api/login ของพี่) เพราะซ้ำกับ loginandregister.js ด้านบน

app.get("/", (req, res) => res.json({ message: "Dorm Master server is running" }));

//------------------- json-server (ข้อมูลอื่นใน db.json) --------------
// users / conversations / messages ต้องอยู่ใน MySQL และผ่านเส้นทางด้านบนเท่านั้น
app.use(["/api/users", "/api/conversations", "/api/messages"], (req, res) => {
  res.status(403).json({ error: "forbidden" });
});
// อ่านได้ทุกคน เขียนต้อง login
app.use("/api", (req, res, next) => (req.method === "GET" ? next() : auth.verifyToken(req, res, next)));
app.use("/api", jsonServer.router("db.json"));

// error handler กลาง (Express 5 ส่ง error จาก async handler มาที่นี่เอง)
app.use((err, req, res, next) => {
  if (err.type === "entity.parse.failed") return res.status(400).json({ error: "JSON ไม่ถูกต้อง" });
  console.error(err);
  res.status(500).json({ error: "เซิร์ฟเวอร์ผิดพลาด" });
});

//=================== Socket.IO (แชท real time) =======================
const httpServer = http.createServer(app);
const io = new Server(httpServer, { cors: { origin: "*" } });
require("./chat_socket").setupChatSocket(io, pool);

const PORT = appCfg.port || 3000;
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log("แชท real time (Socket.IO) พร้อมใช้งาน"); // ไม่เห็นบรรทัดนี้ = รัน server.js ตัวเก่าอยู่
});
