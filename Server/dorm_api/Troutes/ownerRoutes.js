const express = require('express');
const router = express.Router();
const authController = require('../Tcontrollers/authController');
const ownerController = require('../Tcontrollers/ownerController');
const { requireAuth, requireOwnerRole } = require('../Tmiddleware/auth');

router.post('/login', authController.loginOwner);

router.use(requireAuth, requireOwnerRole);

// Dashboard Overview
router.get('/dashboard/stats', ownerController.getDashboardStats);

// Dormitory Management
router.get('/dorms', ownerController.getOwnerDorms);
router.post('/dorms', ownerController.createDorm);
router.put('/dorms/:id', ownerController.updateDorm);
router.patch('/dorms/:id/visibility', ownerController.toggleDormVisibility);

// Room Management
router.post('/dorms/:dormId/rooms', ownerController.addRoom);
router.patch('/rooms/:roomId/status', ownerController.updateRoomStatus);

// Visit Requests
router.get('/visit-requests', ownerController.getVisitRequests);

module.exports = router;