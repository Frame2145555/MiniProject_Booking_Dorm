require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./config/db');
const dashboardRoutes = require('./routes/dashboardRoutes');

const app = express();
app.use(cors());
app.use(express.json());

// เส้นทางทดสอบ: ตรวจว่าต่อ DB ได้
app.get('/api/health', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT DATABASE() AS db, COUNT(*) AS tables_count
       FROM information_schema.tables
       WHERE table_schema = DATABASE()`
    );
    res.json({
      status: 'ok',
      database: rows[0].db,
      tables: rows[0].tables_count,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// ระบบ Dashboard นักศึกษา
app.use('/api/dashboard', dashboardRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});