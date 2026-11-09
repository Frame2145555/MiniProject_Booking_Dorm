const jsonServer = require('json-server');
const http = require('http');
const { Server } = require('socket.io');
const argon2 = require('@node-rs/argon2');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2');

const JWT_KEY = 'thisisthesecretforjwt';   // ย้ายไป .env ทีหลัง
const server = jsonServer.create();
const router = jsonServer.router('db.json');   // json-server ยังใช้กับข้อมูลอื่นที่ยังไม่ย้ายไป MySQL
const middlewares = jsonServer.defaults();

server.use(middlewares);
server.use(jsonServer.bodyParser);

//------------------- MySQL (XAMPP) --------------
// XAMPP ปกติ user = root, ไม่มีรหัสผ่าน
const con = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'dorm_master',
    charset: 'utf8mb4'
});

//middleware
const verifyToken = (req, res, next) => {
    const header = req.headers['authorization'];
    //ตัด Bearer ทิ้ง
    const token = header && header.split(' ')[1];
    if(!token) return res.status(401).send('no token');

    jwt.verify(token, JWT_KEY, (err, payload) => {
        if(err){
            // wrong jwt or expired jwt
            return res.status(403).send('unauthorized');
        }
        req.payload = payload;
        next();
    });
};

// เช็คว่า user เป็นสมาชิกของห้องแชทนี้ไหม ได้ conv กลับมา หรือ null ถ้าไม่ใช่
const getConversation = (conversationId, userId, callback) => {
    const sql = 'SELECT * FROM conversations WHERE id = ? AND (tenant_id = ? OR owner_id = ?)';
    con.query(sql, [Number(conversationId) || 0, userId, userId], (err, results) => {
        if(err){
            console.error(err);
            return callback(null);
        }
        callback(results.length == 1 ? results[0] : null);
    });
};

//------------------- Login --------------
server.post('/api/login', (req, res) => {
    const {email, password} = req.body;
    if(!email || !password) return res.status(400).send('Email and password are required');

    const sql = 'SELECT id, email, password, full_name, role, account_status FROM users WHERE email = ?';
    con.query(sql, [email], (err, results) => {
        if(err){
            console.error(err);
            return res.status(500).send('Database error');
        }
        if(results.length != 1) return res.status(401).send('Wrong email');

        const user = results[0];
        let same = false;
        try {
            same = argon2.verifySync(user.password, password);
        } catch (e) {
            // password ใน DB ไม่ใช่ hash ที่ถูกต้อง (เช่นยังเป็น <HASH>) ให้รัน seed_passwords.js
            same = false;
        }
        if(!same) return res.status(401).send('Wrong password');
        if(user.account_status == 'suspended') return res.status(403).send('Account suspended');

        //payload ไม่ควรเก็บ password
        const payload = {id: user.id, email: user.email, role: user.role};
        const token = jwt.sign(payload, JWT_KEY, {expiresIn: '1d'});
        res.json({token: token, role: user.role, id: user.id, full_name: user.full_name});
    });
});

//------------------- Open (or create) conversation --------------
server.post('/api/conversations', verifyToken, (req, res) => {
    const uid = req.payload.id;
    const dormId = Number(req.body.dorm_id) || 0;

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
server.get('/api/conversations', verifyToken, (req, res) => {
    const uid = req.payload.id;
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
server.get('/api/conversations/:id/messages', verifyToken, (req, res) => {
    getConversation(req.params.id, req.payload.id, (conv) => {
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

//------------------- กัน REST อัตโนมัติของ json-server ที่ไม่ควรเปิด --------------
// users มี hash รหัสผ่าน / conversations กับ messages ต้องผ่านเส้นทางด้านบนเท่านั้น
server.use(['/api/users', '/api/conversations', '/api/messages'], (req, res) => {
    res.status(403).send('forbidden');
});

//------------------- json-server ปกติ: อ่านได้ทุกคน เขียนต้อง login --------------
server.use('/api', (req, res, next) => {
    if(req.method === 'GET') return next();
    verifyToken(req, res, next);
});
server.use('/api', router);

//=================== Socket.IO =======================
const httpServer = http.createServer(server);
const io = new Server(httpServer, { cors: { origin: '*' } });

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
        getConversation(conversationId, uid, (conv) => {
            if(!conv) return ack && ack({ok: false});
            socket.join('conv:' + conv.id);
            ack && ack({ok: true});
        });
    });

    socket.on('send_message', (data, ack) => {
        const text = String((data && data.text) || '').trim();
        if(!text || text.length > 2000) return ack && ack({ok: false});

        getConversation(data.conversation_id, uid, (conv) => {
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
        getConversation(conversationId, uid, (conv) => {
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

//=================== Starting server =======================
const port = 3000;
httpServer.listen(port, () => {
    console.log('Server is running at ' + port);
});
