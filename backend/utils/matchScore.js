// สเกลของแต่ละคำถาม เรียงจากแบบหนึ่งไปอีกแบบ
const SCALES = {
  sleep_schedule: ['early_bird', 'flexible', 'night_owl'],
  cleanliness: ['very_neat', 'average', 'relaxed'],
  study_habit: ['quiet', 'music_ok', 'group_study'],
};

// น้ำหนักของแต่ละคำถาม (รวมกันได้ 100)
const WEIGHTS = {
  sleep_schedule: 40,
  cleanliness: 30,
  study_habit: 30,
};

// ความคล้ายของคำตอบ 1 ข้อ: เหมือนกัน = 1, ห่าง 1 ขั้น = 0.5, ห่างสุด = 0
function similarity(field, a, b) {
  const scale = SCALES[field];
  const ia = scale.indexOf(a);
  const ib = scale.indexOf(b);
  if (ia === -1 || ib === -1) return null; // ไม่มีคำตอบ
  return 1 - Math.abs(ia - ib) / (scale.length - 1);
}

// คืนค่า 0-100 หรือ null ถ้าคนใดคนหนึ่งยังไม่ได้ตอบแบบสอบถาม
function calculateMatch(mine, theirs) {
  if (!mine || !theirs) return null;

  let total = 0;
  for (const field of Object.keys(WEIGHTS)) {
    const s = similarity(field, mine[field], theirs[field]);
    if (s === null) return null;
    total += WEIGHTS[field] * s;
  }
  return Math.round(total);
}

module.exports = { calculateMatch };