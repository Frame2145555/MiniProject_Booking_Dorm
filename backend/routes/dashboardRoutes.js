const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const dashboardController = require('../controllers/dashboardController');

// ทุกเส้นทางของ Dashboard ต้องผ่านด่านตรวจ token ก่อน
router.get('/bookings', verifyToken, dashboardController.getMyBookings);
router.get('/bookings/:id/roommates', verifyToken, dashboardController.getRoommates);
router.get('/payments', verifyToken, dashboardController.getMyPayments);

module.exports = router;