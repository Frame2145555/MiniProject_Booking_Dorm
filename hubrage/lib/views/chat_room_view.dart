import 'package:flutter/material.dart';

import '../Logic/Frame_Chat.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';

/// ห้องแชทกับคู่สนทนาคนหนึ่ง (View) — logic ทั้งหมดอยู่ใน ChatRoomController
class ChatRoomView extends StatefulWidget {
  final int conversationId;
  final String title; // ชื่อคนที่เราคุยด้วย
  final String? subtitle; // เช่น ชื่อหอพัก
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: CircleIconButton(
              size: 40,
              tooltip: 'ย้อนกลับ',
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: Row(
          children: [
            ChatAvatar(name: widget.title, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // controller เปลี่ยน (ข้อความใหม่ / อ่านแล้ว / กำลังส่ง) -> วาดใหม่
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
      return Center(
        child: Text(
          'เริ่มต้นการสนทนากับ ${widget.title}',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    // reverse: true ทำให้รายการติดด้านล่างเสมอ ข้อความใหม่อยู่ล่างสุด
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _bubble(messages[messages.length - 1 - index]),
    );
  }

  Widget _inputBar() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          color: AppColors.bg,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AppShadows.soft,
                  ),
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _onSendPressed(),
                    textInputAction: TextInputAction.send,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.dark,
                ),
                child: _controller.sending
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _onSendPressed,
                      ),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(Map<String, dynamic> msg) {
    final me = _controller.isMine(msg);
    final read = me && msg['read_at'] != null;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.only(bottom: 12, left: me ? 56 : 0, right: me ? 0 : 56),
        decoration: BoxDecoration(
          color: me ? AppColors.ink : Colors.white,
          boxShadow: me ? AppShadows.dark : AppShadows.soft,
          borderRadius: BorderRadius.circular(22).copyWith(
            bottomLeft: me ? null : const Radius.circular(6),
            bottomRight: me ? const Radius.circular(6) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg['text']?.toString() ?? '',
              style: TextStyle(
                color: me ? Colors.white : AppColors.ink,
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatChatTime(msg['sent_at'])}${read ? ' • อ่านแล้ว' : ''}',
              style: TextStyle(
                color: me ? Colors.white60 : AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
