const express = require('express');
const cors = require('cors');
require('dotenv').config();

const ownerRoutes = require('./Troutes/ownerRoutes');
const tenantRoutes = require('./Troutes/tenantRoutes'); // [เพิ่มส่วนนี้]
const authRoutes = require('./Troutes/authRoutes');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Routes Module
app.use('/api/owner', ownerRoutes);
app.use('/api/tenant', tenantRoutes); // [เพิ่มส่วนนี้]
app.use('/api', authRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Dorm Master Backend API running on port ${PORT}`);
});