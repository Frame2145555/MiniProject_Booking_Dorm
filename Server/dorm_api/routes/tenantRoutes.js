const express = require('express');
const router = express.Router();
const tenantController = require('../controllers/tenantController');
const { requireAuth } = require('../middleware/auth');

// สาธารณะ (ผู้ใช้ไม่จำเป็นต้องล็อกอินก็ดูได้)
router.get('/dorms', tenantController.getDorms);
router.get('/dorms/:id', tenantController.getDormById);

// จำเป็นต้องล็อกอิน (Required Authentication)
router.use(requireAuth);

router.get('/notifications', tenantController.getNotifications);
router.patch('/notifications/read', tenantController.markNotificationsRead);
router.post('/dorms/favorite', tenantController.toggleFavorite);
router.post('/dorms/:dormId/reports', tenantController.createDormReport);
router.post('/visit-requests', tenantController.createVisitRequest);
router.post('/bookings', tenantController.createBooking);
router.get('/bookings/my-bookings', tenantController.getMyBookingsAndVisits);
router.patch('/bookings/:bookingId/cancel', tenantController.cancelBooking);

module.exports = router;