// ใส่หอพักตัวอย่างลง MySQL ให้ตรงกับหอ mock ในแอป (DormCatalog: dorm_1 - dorm_4)
// + สร้างบัญชีเจ้าของหอแต่ละหอ (รหัสผ่าน 1234) เพื่อให้ผู้เช่ากดแชทได้ทุกหอ
// + ห้องพักหอละ 3 ห้อง (ไว้ทดสอบการจอง) + บัญชีแอดมิน admin@test.com (รหัส 1234)
// วิธีรัน: node seed_dorms.js   (รันซ้ำได้ ไม่สร้างข้อมูลซ้ำ จะอัปเดตทับของเดิม)
const argon2 = require('@node-rs/argon2');
const mysql = require('mysql2/promise');

// id ต้องตรงกับเลขหลัง dorm_ ในแอป (dorm_1 -> 1) เพราะหน้ารายละเอียดหอแปลงแบบนั้น
const DORMS = [
    {
        id: 1, name: 'หอรวย เธะ', priceMin: 5000, priceMax: 8500, phone: '081-234-5678',
        address: 'ซอยรามคำแหง 24 • ใกล้มหาวิทยาลัยรามคำแหง',
        amenities: ['แอร์', 'Wi-Fi', 'ที่จอดรถ'],
        owner: {email: 'seller@test.com', name: 'เจ้าของหอทดสอบ', phone: '081-234-5678'}
    },
    {
        id: 2, name: 'หออิสลาม แกรนด์', priceMin: 6500, priceMax: 9000, phone: '089-876-5432',
        address: 'ซอยรามคำแหง 24 • ใกล้ Airport Link หัวหมาก',
        amenities: ['แอร์', 'กล้องวงจรปิด', 'ลิฟต์'],
        owner: {email: 'seller2@test.com', name: 'นางสาววิภาวดี รุ่งเรือง', phone: '089-876-5432'}
    },
    {
        id: 3, name: 'HU 24 อพาร์ตเมนต์', priceMin: 7200, priceMax: 11000, phone: '082-333-4455',
        address: 'รามคำแหง 24 แยก 2 • ใกล้เอแบค ABAC',
        amenities: ['ฟิตเนส', 'สระว่ายน้ำ', 'เลี้ยงสัตว์ได้', 'แอร์', 'ที่จอดรถ'],
        owner: {email: 'seller3@test.com', name: 'นายธนกฤต วัฒนา', phone: '082-333-4455'}
    },
    {
        id: 4, name: 'กรีนวิลล์ คอนโดเช่า', priceMin: 4800, priceMax: 7000, phone: '086-555-6677',
        address: 'ซอยหลังราม • ใกล้สนามราชมังคลาฯ และ MRT',
        amenities: ['เครื่องซักผ้า', 'รปภ. 24ชม.', 'แอร์', 'เลี้ยงสัตว์ได้'],
        owner: {email: 'seller4@test.com', name: 'เจ้าของกรีนวิลล์', phone: '086-555-6677'}
    }
];
const DESCRIPTION = 'หอพักใกล้มหาวิทยาลัย เดินทางสะดวกและมีระบบรักษาความปลอดภัย';

const main = async () => {
    const db = await mysql.createConnection({...require('./db-config.json'), charset: 'utf8mb4'});
    const hash = await argon2.hash('1234');

    for (const d of DORMS) {
        // 1. บัญชีเจ้าของหอ (มีอยู่แล้ว = ให้เป็น seller และรหัส 1234)
        await db.query(
            `INSERT INTO users (email, password, full_name, phone, role) VALUES (?, ?, ?, ?, 'seller')
             ON DUPLICATE KEY UPDATE password = VALUES(password), role = 'seller', account_status = 'active'`,
            [d.owner.email, hash, d.owner.name, d.owner.phone]
        );
        const [[owner]] = await db.query('SELECT id FROM users WHERE email = ?', [d.owner.email]);

        // 2. หอพัก (อนุมัติแล้ว + เปิดประกาศ)
        await db.query(
            `INSERT INTO dorms (id, owner_id, name, address, description, price_min_month, price_max_month,
                                phone, listing_status, approval_status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', 'approved')
             ON DUPLICATE KEY UPDATE owner_id = VALUES(owner_id), name = VALUES(name), address = VALUES(address),
                description = VALUES(description), price_min_month = VALUES(price_min_month),
                price_max_month = VALUES(price_max_month), phone = VALUES(phone),
                listing_status = 'active', approval_status = 'approved'`,
            [d.id, owner.id, d.name, d.address, DESCRIPTION, d.priceMin, d.priceMax, d.phone]
        );

        // 3. สิ่งอำนวยความสะดวก (ชื่อตรงกับตาราง amenities)
        await db.query('DELETE FROM dorm_amenities WHERE dorm_id = ?', [d.id]);
        await db.query(
            `INSERT INTO dorm_amenities (dorm_id, amenity_id)
             SELECT ?, id FROM amenities WHERE name IN (?)`,
            [d.id, d.amenities]
        );

        // 4. ห้องพัก 3 ห้อง (มีอยู่แล้วไม่สร้างซ้ำ ไม่แตะสถานะเดิม)
        const rooms = [
            ['101', 'ห้องพัดลม', d.priceMin],
            ['102', 'ห้องแอร์', Math.round((d.priceMin + d.priceMax) / 2)],
            ['201', 'ห้องแอร์ (ใหญ่)', d.priceMax],
        ];
        for (const [number, type, price] of rooms) {
            await db.query(
                `INSERT IGNORE INTO rooms (dorm_id, room_number, room_type, price_per_month, floor, status)
                 VALUES (?, ?, ?, ?, ?, 'available')`,
                [d.id, number, type, price, Number(number[0])]
            );
        }
        console.log(`dorm_${d.id} ${d.name}  ->  เจ้าของ ${d.owner.email} (user id ${owner.id})`);
    }

    // 5. บัญชีแอดมิน (สมัครผ่านแอปเป็น admin ไม่ได้ ต้องสร้างจากตรงนี้)
    await db.query(
        `INSERT INTO users (email, password, full_name, role) VALUES ('admin@test.com', ?, 'ผู้ดูแลระบบ', 'admin')
         ON DUPLICATE KEY UPDATE password = VALUES(password), role = 'admin', account_status = 'active'`,
        [hash]
    );
    console.log('แอดมิน -> admin@test.com');

    console.log('\nเสร็จแล้ว: หอ ' + DORMS.length + ' หอ (หอละ 3 ห้อง) / ทุกบัญชีรหัสผ่าน 1234');
    await db.end();
};

main().catch((err) => {
    console.error('ใส่ข้อมูลไม่สำเร็จ:', err.message);
    process.exitCode = 1;
});
