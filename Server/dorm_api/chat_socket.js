// ระบบแชท real-time (Socket.IO) แยกออกมาจาก server.js
// รับ con (MySQL) เข้ามาเป็น parameter เพื่อให้ตอน unit test ส่ง DB ปลอมเข้ามาแทนได้
const jwt = require('jsonwebtoken');
const { JWT_KEY, cleanMessageText } = require('./chat_rules');

// เช็คว่า user เป็นสมาชิกของห้องแชทนี้ไหม ได้ conv กลับมา หรือ null ถ้าไม่ใช่
const getConversation = (con, conversationId, userId, callback) => {
    const sql = 'SELECT * FROM conversations WHERE id = ? AND (tenant_id = ? OR owner_id = ?)';
    con.query(sql, [Number(conversationId) || 0, userId, userId], (err, results) => {
        if(err){
            console.error(err);
            return callback(null);
        }
        callback(results.length == 1 ? results[0] : null);
    });
};

const setupChatSocket = (io, con) => {
    io.use((socket, next) => {
        const token = socket.handshake.auth.token;
        jwt.verify(token, JWT_KEY, (err, payload) => {
            if(err) return next(new Error('unauthorized'));
            socket.payload = payload;
            next();
        });
    });

    io.on('connection', (socket) => {
        const uid = socket.payload.id;
        socket.join('user:' + uid);   // ห้องส่วนตัว ไว้แจ้งให้รายการแชทอัปเดต

        socket.on('join_conversation', (conversationId, ack) => {
            getConversation(con, conversationId, uid, (conv) => {
                if(!conv) return ack && ack({ok: false});
                socket.join('conv:' + conv.id);
                ack && ack({ok: true});
            });
        });

        socket.on('send_message', (data, ack) => {
            const text = cleanMessageText(data);
            if(!text) return ack && ack({ok: false});

            getConversation(con, data.conversation_id, uid, (conv) => {
                if(!conv) return ack && ack({ok: false});

                // sender_id ใช้จาก JWT เท่านั้น ห้ามเชื่อค่าจาก client
                const now = new Date();
                const sql = 'INSERT INTO messages (conversation_id, sender_id, message_text, sent_at) VALUES (?, ?, ?, ?)';
                con.query(sql, [conv.id, uid, text, now], (err, result) => {
                    if(err){
                        console.error(err);
                        return ack && ack({ok: false});
                    }
                    const msg = {
                        id: result.insertId,
                        conversation_id: conv.id,
                        sender_id: uid,
                        text: text,
                        sent_at: now,
                        read_at: null
                    };
                    con.query('UPDATE conversations SET updated_at = ? WHERE id = ?', [now, conv.id], (err) => {
                        if(err) console.error(err);
                    });

                    io.to('conv:' + conv.id).emit('new_message', msg);
                    io.to('user:' + conv.tenant_id).to('user:' + conv.owner_id)
                        .emit('conversation_updated', {conversation_id: conv.id});
                    ack && ack({ok: true, message: msg});
                });
            });
        });

        socket.on('mark_read', (conversationId) => {
            getConversation(con, conversationId, uid, (conv) => {
                if(!conv) return;
                const sql = 'UPDATE messages SET read_at = ? WHERE conversation_id = ? AND sender_id <> ? AND read_at IS NULL';
                con.query(sql, [new Date(), conv.id, uid], (err, result) => {
                    if(err) return console.error(err);
                    if(result.affectedRows > 0){
                        io.to('conv:' + conv.id).emit('messages_read', {conversation_id: conv.id, reader_id: uid});
                    }
                    io.to('user:' + uid).emit('conversation_updated', {conversation_id: conv.id});
                });
            });
        });
    });
};

module.exports = { getConversation, setupChatSocket };
