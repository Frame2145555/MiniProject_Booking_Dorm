require('dotenv').config();
const jwt = require('jsonwebtoken');

const id = Number(process.argv[2]);
const role = process.argv[3] || 'user';

if (!id) {
  console.log('วิธีใช้: node scripts/makeToken.js <user_id> [role]');
  process.exit(1);
}

const token = jwt.sign({ id, role }, process.env.JWT_SECRET, { expiresIn: '7d' });
console.log(token);