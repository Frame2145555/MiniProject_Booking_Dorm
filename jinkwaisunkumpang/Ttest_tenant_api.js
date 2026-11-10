
const BASE_URL = 'http://localhost:3000/api/tenant';

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

function logTest(title) {
  console.log(`\n${colors.cyan}${colors.bold}=== ${title} ===${colors.reset}`);
}

function logResult(success, message, data = null) {
  if (success) {
    console.log(`${colors.green}✔ PASS:${colors.reset} ${message}`);
    if (data) console.log(colors.yellow, JSON.stringify(data, null, 2), colors.reset);
  } else {
    console.log(`${colors.red}✖ FAIL:${colors.reset} ${message}`);
    if (data) console.log(colors.red, JSON.stringify(data, null, 2), colors.reset);
  }
}

async function runTenantApiTests() {
  console.log(`${colors.bold}🚀 เริ่มต้นการทดสอบ Tenant / User APIs (Dorm Master Backend)${colors.reset}`);
  let createdBookingId = null;

  try {
    // 1. GET Search Dorms
    logTest('1. GET /api/tenant/dorms (ค้นหาและกรองหอพัก)');
    const resSearch = await fetch(`${BASE_URL}/dorms?search=รามคำแหง&minPrice=4000&maxPrice=9000`);
    const dataSearch = await resSearch.json();
    logResult(resSearch.ok && dataSearch.success, `ค้นหาสำเร็จ พบหอพักจำนวน ${dataSearch.count} แห่ง`);

    // 2. GET Dorm Detail (ID: 1)
    logTest('2. GET /api/tenant/dorms/1 (ดูรายละเอียดหอพัก + บันทึกยอดวิว)');
    const resDetail = await fetch(`${BASE_URL}/dorms/1`);
    const dataDetail = await resDetail.json();
    logResult(resDetail.ok && dataDetail.success, `ดึงรายละเอียดหอ: ${dataDetail.data?.title}`, {
      title: dataDetail.data?.title,
      price: `฿${dataDetail.data?.priceMin} - ฿${dataDetail.data?.priceMax}`,
      roomsCount: dataDetail.data?.rooms?.length,
      utilities: dataDetail.data?.utilities
    });

    // 3. POST Toggle Favorite
    logTest('3. POST /api/tenant/dorms/favorite (กดบันทึกเป็นหอพักโปรด)');
    const resFav = await fetch(`${BASE_URL}/dorms/favorite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ dormId: 1 })
    });
    const dataFav = await resFav.json();
    logResult(resFav.ok && dataFav.success, dataFav.message);

    // 4. POST Create Visit Request
    logTest('4. POST /api/tenant/visit-requests (ส่งคำขอนัดเข้าดูห้องพัก)');
    const visitPayload = {
      dormId: 1,
      roomId: 101,
      visitAt: '2026-11-20 14:00:00',
      tenantNote: 'ขอนัดชมห้องพักช่วงบ่ายสองครับ'
    };
    const resVisit = await fetch(`${BASE_URL}/visit-requests`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(visitPayload)
    });
    const dataVisit = await resVisit.json();
    logResult(resVisit.ok && dataVisit.success, dataVisit.message, dataVisit.data);

    // 5. POST Create Room Booking
    logTest('5. POST /api/tenant/bookings (ส่งคำขอจองห้องพัก)');
    const bookingPayload = {
      roomId: 101,
      startsAt: '2026-12-01',
      endsAt: '2027-11-30'
    };
    const resBooking = await fetch(`${BASE_URL}/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(bookingPayload)
    });
    const dataBooking = await resBooking.json();
    if (resBooking.ok && dataBooking.success) {
      createdBookingId = dataBooking.data.bookingId;
      logResult(true, `สร้างการจองสำเร็จ! Booking ID: ${createdBookingId}`, dataBooking.data);
    } else {
      logResult(false, 'การจองไม่สำเร็จ', dataBooking);
    }

    // 6. GET My Bookings & Visits
    logTest('6. GET /api/tenant/bookings/my-bookings (ดึงประวัติการจองและคำขอนัดของผู้ใช้)');
    const resMyBookings = await fetch(`${BASE_URL}/bookings/my-bookings`);
    const dataMyBookings = await resMyBookings.json();
    logResult(resMyBookings.ok && dataMyBookings.success, 'ดึงประวัติสำเร็จ', {
      totalBookings: dataMyBookings.data?.bookings?.length,
      totalVisits: dataMyBookings.data?.visitRequests?.length
    });

    // 7. PATCH Cancel Booking
    if (createdBookingId) {
      logTest(`7. PATCH /api/tenant/bookings/${createdBookingId}/cancel (ยกเลิกคำขอจองห้องพัก)`);
      const resCancel = await fetch(`${BASE_URL}/bookings/${createdBookingId}/cancel`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' }
      });
      const dataCancel = await resCancel.json();
      logResult(resCancel.ok && dataCancel.success, dataCancel.message);
    }

    console.log(`\n${colors.bold}${colors.green}🎉 การทดสอบระบบ Tenant APIs เสร็จสิ้นสมบูรณ์!${colors.reset}\n`);

  } catch (err) {
    console.error(`\n${colors.red}❌ เกิดข้อผิดพลาดขณะเชื่อมต่อกับ Server:${colors.reset}`, err.message);
  }
}

runTenantApiTests();