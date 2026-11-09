// แชทผ่าน terminal ใช้แทนเครื่องที่ 2 ตอนทดสอบ (ไม่ต้องเปิด emulator 2 ตัว)
// วิธีรัน: node chat_cli.js seller@test.com
//         node chat_cli.js seller@test.com https://xxxx.ngrok-free.app
// พิมพ์ข้อความแล้วกด Enter = ส่งเข้าห้องแชทล่าสุด
const { io } = require('socket.io-client');
const readline = require('readline');

const EMAIL = process.argv[2] || 'seller@test.com';
const BASE = (process.argv[3] || 'http://localhost:3000').replace(/\/+$/, '');   // ตัด / ท้าย URL
const headers = {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'};

let me = null;
let socket = null;
let currentConv = null;   // ห้องที่จะส่งข้อความไป (ห้องที่มีข้อความเข้ามาล่าสุด)

const getConversations = async () => {
    const res = await fetch(BASE + '/api/conversations', {
        headers: {...headers, 'Authorization': 'Bearer ' + me.token}
    });
    return res.json();
};

const joinAll = async () => {
    const list = await getConversations();
    list.forEach((c) => socket.emit('join_conversation', c.id));
    if(!currentConv && list.length) currentConv = list[0].id;
    return list;
};

const main = async () => {
    const res = await fetch(BASE + '/api/login', {
        method: 'POST', headers: headers,
        body: JSON.stringify({email: EMAIL, password: '1234'})
    });
    if(res.status != 200) return console.log('login ไม่ผ่าน: ' + await res.text());
    me = await res.json();
    console.log('login เป็น ' + me.full_name + ' (id ' + me.id + ')');

    socket = io(BASE, {transports: ['websocket'], auth: {token: me.token}});

    socket.on('connect', async () => {
        const list = await joinAll();
        console.log('เชื่อมต่อแล้ว มี ' + list.length + ' ห้องแชท' + (list.length ? '' : ' (รอให้อีกฝั่งเริ่มแชทก่อน)'));
    });
    socket.on('connect_error', (err) => console.log('ต่อ socket ไม่ได้: ' + err.message));

    // มีห้องใหม่หรือข้อความใหม่ -> join ให้ครบทุกห้อง
    socket.on('conversation_updated', async (data) => {
        await joinAll();
        currentConv = data.conversation_id;
    });

    socket.on('new_message', (msg) => {
        if(msg.sender_id == me.id) return;
        currentConv = msg.conversation_id;
        console.log('\n[ห้อง ' + msg.conversation_id + '] อีกฝั่ง: ' + msg.text);
        socket.emit('mark_read', msg.conversation_id);   // ให้แอปขึ้น "อ่านแล้ว"
        rl.prompt();
    });

    const rl = readline.createInterface({input: process.stdin, output: process.stdout, prompt: '> '});
    rl.prompt();
    rl.on('line', (line) => {
        const text = line.trim();
        if(!text) return rl.prompt();
        if(!currentConv){
            console.log('ยังไม่มีห้องแชท ให้แอปกด "เริ่มแชทกับเจ้าของหอ" ก่อน');
            return rl.prompt();
        }
        socket.emit('send_message', {conversation_id: currentConv, text: text}, (ack) => {
            console.log(ack.ok ? '✓ ส่งแล้ว (ห้อง ' + currentConv + ')' : '✗ ส่งไม่สำเร็จ');
            rl.prompt();
        });
    });
    rl.on('close', () => socket.close());
};

main().catch((err) => console.log('error: ' + err.message));