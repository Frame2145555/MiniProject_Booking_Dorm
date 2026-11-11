// REST ของระบบแชท (ส่วน real time อยู่ใน chat_socket.js)
// ใช้งาน:  app.use('/api', require('./chat_routes')(con, auth.verifyToken));
//   POST /api/conversations                เปิด (หรือสร้าง) ห้องแชทกับเจ้าของหอ  body: {dorm_id}
//   GET  /api/conversations                รายการห้องแชทของฉัน
//   GET  /api/conversations/:id/messages   ประวัติ 50 ข้อความล่าสุด
// con = mysql2 แบบ callback / verifyToken ของ loginandregister.js (ใส่ req.user ให้)
const express = require('express');
const { getConversation } = require('./chat_socket');

module.exports = function createChatRoutes(con, verifyToken) {
    const router = express.Router();

    //------------------- Open (or create) conversation --------------
    router.post('/conversations', verifyToken, (req, res) => {
        const uid = req.user.id;
        const dormId = Number(req.body && req.body.dorm_id) || 0;

        const sql = "SELECT id, owner_id FROM dorms WHERE id = ? AND approval_status = 'approved'";
        con.query(sql, [dormId], (err, results) => {
            if(err){
                console.error(err);
                return res.status(500).send('Database error');
            }
            if(results.length != 1) return res.status(404).send('Dorm not found');
            const dorm = results[0];
            if(dorm.owner_id == uid) return res.status(400).send('Cannot chat with yourself');

            // ถ้ามีห้องแชทอยู่แล้ว INSERT IGNORE จะไม่สร้างซ้ำ (มี UNIQUE dorm_id, tenant_id, owner_id)
            const insertSql = 'INSERT IGNORE INTO conversations (dorm_id, tenant_id, owner_id) VALUES (?, ?, ?)';
            con.query(insertSql, [dorm.id, uid, dorm.owner_id], (err) => {
                if(err){
                    console.error(err);
                    return res.status(500).send('Database error');
                }
                const findSql = 'SELECT id FROM conversations WHERE dorm_id = ? AND tenant_id = ? AND owner_id = ?';
                con.query(findSql, [dorm.id, uid, dorm.owner_id], (err, rows) => {
                    if(err || rows.length != 1){
                        console.error(err);
                        return res.status(500).send('Database error');
                    }
                    res.json({id: rows[0].id});
                });
            });
        });
    });

    //------------------- Conversation list --------------
    router.get('/conversations', verifyToken, (req, res) => {
        const uid = req.user.id;
        const sql = `
            SELECT c.id, c.dorm_id, c.updated_at, d.name AS dorm_name,
                IF(c.tenant_id = ?, o.full_name, t.full_name) AS other_name,
                (SELECT m.message_text FROM messages m WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message,
                (SELECT m.sent_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_sent_at,
                (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.sender_id <> ? AND m.read_at IS NULL) AS unread
            FROM conversations c
            JOIN dorms d ON d.id = c.dorm_id
            JOIN users t ON t.id = c.tenant_id
            JOIN users o ON o.id = c.owner_id
            WHERE c.tenant_id = ? OR c.owner_id = ?
            ORDER BY c.updated_at DESC`;
        con.query(sql, [uid, uid, uid, uid], (err, results) => {
            if(err){
                console.error(err);
                return res.status(500).send('Database error');
            }
            res.json(results);
        });
    });

    //------------------- Message history (50 ข้อความล่าสุด) --------------
    router.get('/conversations/:id/messages', verifyToken, (req, res) => {
        getConversation(con, req.params.id, req.user.id, (conv) => {
            if(!conv) return res.status(403).send('Not your conversation');
            const sql = `
                SELECT * FROM (
                    SELECT id, conversation_id, sender_id, message_text AS text, sent_at, read_at
                    FROM messages WHERE conversation_id = ? ORDER BY id DESC LIMIT 50
                ) AS last50 ORDER BY id ASC`;
            con.query(sql, [conv.id], (err, results) => {
                if(err){
                    console.error(err);
                    return res.status(500).send('Database error');
                }
                res.json(results);
            });
        });
    });

    return router;
};
