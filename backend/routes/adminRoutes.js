const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminDormController');
const { verifyAdmin } = require('../middleware/auth');

// All routes require Admin JWT Authorization
router.use(verifyAdmin);

// Buildings
router.get('/buildings', adminController.getAllBuildings);
router.post('/buildings', adminController.createBuilding);
router.put('/buildings/:id', adminController.updateBuilding);
router.delete('/buildings/:id', adminController.deleteBuilding);

// Room Types
router.get('/room-types', adminController.getAllRoomTypes);
router.post('/room-types', adminController.createRoomType);

// Rooms
router.get('/rooms', adminController.getAllRooms);
router.post('/rooms', adminController.createRoom);
router.put('/rooms/:id', adminController.updateRoom);
router.delete('/rooms/:id', adminController.deleteRoom);

// Amenities
router.get('/amenities', adminController.getAllAmenities);
router.post('/amenities', adminController.createAmenity);

// Semesters
router.get('/semesters', adminController.getAllSemesters);
router.post('/semesters', adminController.createSemester);

// Addons
router.get('/addons', adminController.getAllAddons);
router.post('/addons', adminController.createAddon);

module.exports = router;
