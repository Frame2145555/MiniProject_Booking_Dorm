"use strict";
// Routes ของระบบแอดมิน; business logic และการเข้าถึงฐานข้อมูลอยู่ใน Tcontrollers/adminController.js
const express = require("express");
const createAdminController = require("./Tcontrollers/adminController");

module.exports = (db, auth) => {
  const router = express.Router();
  const controller = createAdminController(db);

  router.use(auth.requireRole("admin"));
  router.get("/overview", controller.getOverview);
  router.get("/sellers", controller.getSellers);
  router.patch("/users/:id/status", controller.updateUserStatus);
  router.get("/dorms", controller.getDorms);
  router.patch("/dorms/:id/approval", controller.updateDormApproval);
  // รวม endpoint ตรวจสอบ KYC ไว้ใต้ /api/admin/kyc
  router.use("/kyc", require("./admin_kyc_routes")(db, auth));

  return router;
};
