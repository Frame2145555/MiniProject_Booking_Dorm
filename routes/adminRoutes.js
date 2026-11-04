const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');

// Buildings
router.get('/buildings', adminController.getAllBuildings);
router.post('/buildings', adminController.createBuilding);
router.put('/buildings/:id', adminController.updateBuilding);
router.delete('/buildings/:id', adminController.deleteBuilding);

// Room Types
router.get('/room-types', adminController.getAllRoomTypes);
router.post('/room-types', adminController.createRoomType);
router.put('/room-types/:id', adminController.updateRoomType);
router.delete('/room-types/:id', adminController.deleteRoomType);

// Amenities
router.get('/amenities', adminController.getAllAmenities);
router.post('/amenities', adminController.createAmenity);
router.put('/amenities/:id', adminController.updateAmenity);
router.delete('/amenities/:id', adminController.deleteAmenity);

// Rooms & Room Amenities
router.get('/rooms', adminController.getAllRooms);
router.post('/rooms', adminController.createRoom);
router.put('/rooms/:id', adminController.updateRoom);
router.delete('/rooms/:id', adminController.deleteRoom);
router.post('/rooms/:id/amenities', adminController.setRoomAmenities);

// Room Images
router.post('/room-images', adminController.addRoomImage);
router.delete('/room-images/:id', adminController.deleteRoomImage);

// Semesters
router.get('/semesters', adminController.getAllSemesters);
router.post('/semesters', adminController.createSemester);
router.put('/semesters/:id', adminController.updateSemester);
router.delete('/semesters/:id', adminController.deleteSemester);

// Addons
router.get('/addons', adminController.getAllAddons);
router.post('/addons', adminController.createAddon);
router.put('/addons/:id', adminController.updateAddon);
router.delete('/addons/:id', adminController.deleteAddon);

// Users (Suspend User)
router.get('/users', adminController.getAllUsers);
router.patch('/users/:id/status', adminController.toggleUserStatus);

module.exports = router;
