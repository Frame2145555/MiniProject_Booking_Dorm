const BASE_URL = 'http://localhost:3000/api/owner';

// ANSI Colors สำหรับการแสดงผล Terminal
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

async function runOwnerApiTests() {
  console.log(`${colors.bold}🚀 เริ่มต้นการทดสอบ Owner APIs (Dorm Master Backend)${colors.reset}`);
  let createdDormId = null;
  let createdRoomId = null;

  try {
    // 1. GET Dashboard Stats
    logTest('1. GET /api/owner/dashboard/stats (ดึงสถิติภาพรวม)');
    const resStats = await fetch(`${BASE_URL}/dashboard/stats`);
    const dataStats = await resStats.json();
    logResult(resStats.ok && dataStats.success, 'ดึงข้อมูล Dashboard สำเร็จ', dataStats.data);

    // 2. GET Owner Dorms List
    logTest('2. GET /api/owner/dorms (ดึงรายการหอพักทั้งหมดของเจ้าของ)');
    const resDorms = await fetch(`${BASE_URL}/dorms`);
    const dataDorms = await resDorms.json();
    logResult(resDorms.ok && dataDorms.success, `พบหอพักจำนวน ${dataDorms.count} แห่ง`);

    // 3. POST Create New Dorm Request
    logTest('3. POST /api/owner/dorms (ส่งคำขอเพิ่มหอพักใหม่ + เอกสาร)');
    const newDormPayload = {
      title: 'หอพักอัจฉริยะ เทสโต้ (Smart Dorm)',
      location: 'ซอยรามคำแหง 24 แยก 8 กรุงเทพฯ',
      description: 'หอพักใหม่ล่าสุด ห้องกว้าง ปลอดภัยด้วย Keycard',
      phone: '089-999-9999',
      priceMin: 4500,
      priceMax: 7000,
      latitude: 13.7570,
      longitude: 100.6210,
      imageUrl: 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5',
      amenities: ['แอร์', 'Wi-Fi', 'กล้องวงจรปิด', 'ลิฟต์'],
      documents: [
        {
          type: 'proof_of_right',
          name: 'โฉนดที่ดิน_เทสโต้.pdf',
          key: 'uploads/dorms/test_deed.pdf'
        }
      ]
    };
    const resCreateDorm = await fetch(`${BASE_URL}/dorms`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newDormPayload)
    });
    const dataCreateDorm = await resCreateDorm.json();
    if (resCreateDorm.ok && dataCreateDorm.success) {
      createdDormId = dataCreateDorm.data.dormId;
      logResult(true, `สร้างหอพักสำเร็จ! ได้รับ Dorm ID: ${createdDormId}`, dataCreateDorm);
    } else {
      logResult(false, 'สร้างหอพักไม่สำเร็จ', dataCreateDorm);
    }

    // 4. PUT Update Dorm Details
    const targetDormId = createdDormId || 1;
    logTest(`4. PUT /api/owner/dorms/${targetDormId} (แก้ไขรายละเอียดหอพัก)`);
    const updateDormPayload = {
      title: 'หอพักอัจฉริยะ เทสโต้ (ปรับปรุงใหม่)',
      location: 'ซอยรามคำแหง 24 แยก 8 กรุงเทพฯ',
      phone: '089-999-8888',
      description: 'อัปเดตรายละเอียดหอพักเรียบร้อย',
      priceMin: 4800,
      priceMax: 7500,
      imageUrl: 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5'
    };
    const resUpdateDorm = await fetch(`${BASE_URL}/dorms/${targetDormId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updateDormPayload)
    });
    const dataUpdateDorm = await resUpdateDorm.json();
    logResult(resUpdateDorm.ok && dataUpdateDorm.success, dataUpdateDorm.message);

    // 5. PATCH Toggle Dorm Visibility (Close Temporarily)
    logTest(`5. PATCH /api/owner/dorms/${targetDormId}/visibility (ปิดประกาศชั่วคราว)`);
    const resVisibility = await fetch(`${BASE_URL}/dorms/${targetDormId}/visibility`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ isClosed: true })
    });
    const dataVisibility = await resVisibility.json();
    logResult(resVisibility.ok && dataVisibility.success, dataVisibility.message);

    // 6. POST Add Room to Dorm
    logTest(`6. POST /api/owner/dorms/${targetDormId}/rooms (เพิ่มห้องพักใหม่เข้าหอ)`);
    const newRoomPayload = {
      roomNumber: `T-${Math.floor(100 + Math.random() * 900)}`,
      roomType: 'เตียง 5 ฟุต (Studio)',
      price: 5200,
      floor: 2,
      status: 'ว่าง'
    };
    const resAddRoom = await fetch(`${BASE_URL}/dorms/${targetDormId}/rooms`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newRoomPayload)
    });
    const dataAddRoom = await resAddRoom.json();
    if (resAddRoom.ok && dataAddRoom.success) {
      createdRoomId = dataAddRoom.data.id;
      logResult(true, `เพิ่มห้องพักสำเร็จ! Room ID: ${createdRoomId}`, dataAddRoom.data);
    } else {
      logResult(false, 'เพิ่มห้องพักไม่สำเร็จ', dataAddRoom);
    }

    // 7. PATCH Update Room Status
    const targetRoomId = createdRoomId || 101;
    logTest(`7. PATCH /api/owner/rooms/${targetRoomId}/status (อัปเดตสถานะห้องพัก)`);
    const resRoomStatus = await fetch(`${BASE_URL}/rooms/${targetRoomId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'มีผู้เช่า' })
    });
    const dataRoomStatus = await resRoomStatus.json();
    logResult(resRoomStatus.ok && dataRoomStatus.success, dataRoomStatus.message);

    // 8. GET Visit Requests
    logTest('8. GET /api/owner/visit-requests (ดึงรายการคำขอนัดดูห้องพัก)');
    const resVisits = await fetch(`${BASE_URL}/visit-requests`);
    const dataVisits = await resVisits.json();
    logResult(resVisits.ok && dataVisits.success, `พบคำขอนัดดูห้องจำนวน ${dataVisits.count} รายการ`);

    console.log(`\n${colors.bold}${colors.green}🎉 การทดสอบระบบ Owner APIs เสร็จสิ้นสมบูรณ์!${colors.reset}\n`);

  } catch (err) {
    console.error(`\n${colors.red}❌ เกิดข้อผิดพลาดขณะเชื่อมต่อกับ Server:${colors.reset}`, err.message);
    console.log(`${colors.yellow}💡 คำแนะนำ: ตรวจสอบว่าสั่งรัน 'npm run dev' หรือ 'node server.js' แล้วหรือยัง${colors.reset}`);
  }
}

runOwnerApiTests();