import 'package:flutter/material.dart';
import '../Logic/Frame_Chat.dart';
import '../services/chat_service.dart';
import '../services/session.dart';
import 'chat_room_view.dart';

/// รายการห้องแชท (View) — logic อยู่ใน ChatListController
class ChatView extends StatefulWidget {
  final ChatService? service; // ไม่ต้องส่ง = ใช้ server จริง (ส่งตัวปลอมตอน widget test)

  const ChatView({super.key, this.service});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final ChatListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatListController(service: widget.service);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openRoom(Map<String, dynamic> conv) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomView(
          conversationId: conv['id'],
          title: conv['other_name']?.toString() ?? 'แชท',
          subtitle: conv['dorm_name']?.toString(),
          service: widget.service,
        ),
      ),
    );
    _controller.load(); // กลับมาแล้วอัปเดตจำนวนที่ยังไม่อ่าน
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แชทสนทนา (DM)')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!Session.isLoggedIn) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'กรุณาเข้าสู่ระบบที่แท็บ "บัญชี" ก่อนใช้งานแชท',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    if (_controller.loading) return const Center(child: CircularProgressIndicator());

    final conversations = _controller.conversations;
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: conversations.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 160),
                Center(
                  child: Text(
                    'ยังไม่มีห้องแชท\nผู้เช่าเริ่มแชทได้จากหน้ารายละเอียดหอพัก',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            )
          : ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _conversationTile(conversations[index]),
            ),
    );
  }

  Widget _conversationTile(Map<String, dynamic> conv) {
    final name = conv['other_name']?.toString() ?? '';
    final unread = conv['unread'] ?? 0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: const TextStyle(color: Colors.deepOrange),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${conv['dorm_name'] ?? ''} • ${conv['last_message'] ?? 'ยังไม่มีข้อความ'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatChatTime(conv['last_sent_at']),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          if (unread > 0)
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.deepOrange,
              child: Text(
                '$unread',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      onTap: () => _openRoom(conv),
    );
  }
}