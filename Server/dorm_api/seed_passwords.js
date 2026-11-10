// ตั้งรหัสผ่านให้ user ทดสอบทุกคนเป็น 1234 (รันครั้งเดียวหลัง import dorm_master.sql)
// วิธีรัน: node seed_passwords.js
const argon2 = require('@node-rs/argon2');
const mysql = require('mysql2');

const con = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'dorm_master',
    charset: 'utf8mb4'
});

const hash = argon2.hashSync('1234');
const emails = ['tenant@test.com', 'seller@test.com', 'other@test.com'];

con.query('UPDATE users SET password = ? WHERE email IN (?)', [hash, emails], (err, result) => {
    if(err){
        console.error(err);
    } else {
        console.log('อัปเดตรหัสผ่านแล้ว ' + result.affectedRows + ' คน (รหัสผ่าน = 1234)');
    }
    con.end();
});
