import 'package:flutter/material.dart';
import '../Logic/Frame_Chat.dart';
import '../services/chat_service.dart';

/// หน้าห้องแชท 1 ห้อง (View) — logic ทั้งหมดอยู่ใน ChatRoomController
class ChatRoomView extends StatefulWidget {
  final int conversationId;
  final String title;
  final String? subtitle;
  final ChatService? service; // ไม่ต้องส่ง = ใช้ server จริง (ส่งตัวปลอมตอน widget test)

  const ChatRoomView({
    super.key,
    required this.conversationId,
    required this.title,
    this.subtitle,
    this.service,
  });

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatRoomController _controller;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ChatRoomController(widget.conversationId, service: widget.service);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onSendPressed() async {
    final ok = await _controller.send(_textController.text);
    if (!mounted || ok == null) return;
    if (ok) {
      _textController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
      // controller เปลี่ยน (ข้อความใหม่ / อ่านแล้ว / กำลังส่ง) -> วาดหน้าใหม่
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            Expanded(child: _messageList()),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final messages = _controller.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีข้อความ เริ่มทักทายได้เลย',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    // reverse: true ทำให้ list ติดด้านล่างเสมอ ข้อความใหม่อยู่ล่างสุด
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _bubble(messages[messages.length - 1 - index]),
    );
  }

  Widget _inputBar() => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _onSendPressed(),
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: _controller.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _onSendPressed,
                      ),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(Map<String, dynamic> msg) {
    final mine = _controller.isMine(msg);
    final status = mine && msg['read_at'] != null ? ' • อ่านแล้ว' : '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: EdgeInsets.only(
              top: 10,
              left: mine ? 60 : 0,
              right: mine ? 0 : 60,
            ),
            decoration: BoxDecoration(
              color: mine ? Colors.deepOrange : Colors.grey[200],
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: mine ? Radius.zero : null,
                bottomLeft: mine ? null : Radius.zero,
              ),
            ),
            child: Text(
              msg['text']?.toString() ?? '',
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatChatTime(msg['sent_at'])}$status',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}