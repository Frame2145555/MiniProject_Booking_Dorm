const dashboardModel = require('../models/dashboardModel');
const { calculateMatch } = require('../utils/matchScore');

// GET /api/dashboard/bookings
async function getMyBookings(req, res) {
  try {
    // ใช้ id จาก token เท่านั้น ไม่รับ id จากผู้ใช้ จึงดูของคนอื่นไม่ได้
    const bookings = await dashboardModel.getBookingsByUser(req.user.id);
    res.json({ success: true, data: bookings });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
}

// GET /api/dashboard/bookings/:id/roommates
async function getRoommates(req, res) {
  try {
    const bookingId = Number(req.params.id);
    if (!Number.isInteger(bookingId) || bookingId <= 0) {
      return res
        .status(400)
        .json({ success: false, message: 'Invalid booking id' });
    }

    // การจองนี้ต้องเป็นของคนที่ล็อกอินอยู่ ไม่งั้นตอบว่าไม่พบ
    const booking = await dashboardModel.getBookingForUser(
      bookingId,
      req.user.id
    );
    if (!booking) {
      return res
        .status(404)
        .json({ success: false, message: 'Booking not found' });
    }

    const myPrefs = await dashboardModel.getPreferences(req.user.id);
    const rows = await dashboardModel.getRoommates(
      booking.room_id,
      booking.semester_id,
      req.user.id
    );

    // ส่งเฉพาะข้อมูลที่หน้าจอต้องใช้ ไม่ส่งอีเมล/เบอร์โทรของรูมเมท
    const roommates = rows.map((r) => ({
      full_name: r.full_name,
      faculty: r.faculty,
      match_percent: calculateMatch(myPrefs, r),
      same_sleep_habit: !!myPrefs && r.sleep_schedule === myPrefs.sleep_schedule,
    }));

    res.json({ success: true, data: roommates });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
}

// GET /api/dashboard/payments
async function getMyPayments(req, res) {
  try {
    const payments = await dashboardModel.getPaymentsByUser(req.user.id);

    // รวมยอดตามสถานะ (amount จาก MySQL เป็นข้อความ จึงแปลงเป็นตัวเลขก่อนบวก)
    const sumByStatus = (status) =>
      payments
        .filter((p) => p.status === status)
        .reduce((total, p) => total + Number(p.amount), 0);

    const round2 = (n) => Math.round(n * 100) / 100;

    res.json({
      success: true,
      summary: {
        total_paid: round2(sumByStatus('paid')),
        total_refunded: round2(sumByStatus('refunded')),
        total_pending: round2(sumByStatus('pending')),
      },
      data: payments,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
}

module.exports = { getMyBookings, getRoommates, getMyPayments };