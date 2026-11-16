"use strict";
// กำหนด URL สำหรับงาน KYC; การตรวจสอบและบันทึกข้อมูลอยู่ใน adminController.js
const express = require("express");
const createAdminController = require("./Tcontrollers/adminController");

module.exports = (db, auth) => {
  const router = express.Router();
  const controller = createAdminController(db);

  // ป้องกัน endpoint KYC ให้ใช้ได้เฉพาะผู้ดูแลระบบ
  router.use(auth.requireRole("admin"));
  router.get("/", controller.getKycRequests);
  router.get("/:id", controller.getKycRequest);
  router.patch("/:id/decision", controller.decideKycRequest);

  return router;
};
