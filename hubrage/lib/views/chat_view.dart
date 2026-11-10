import 'package:flutter/material.dart';

import '../Logic/Frame_Chat.dart';
import '../services/chat_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import 'auth_view.dart';
import 'chat_room_view.dart';

/// หน้ารายการแชท (View): แสดงว่าคุยกับใครบ้าง กดเข้าไปแล้วค่อยเห็นห้องแชท
/// ข้อมูลจริงมาจาก server ผ่าน ChatListController (Logic/Frame_Chat.dart)
class ChatView extends StatefulWidget {
  /// true = แสดงเป็นแท็บใน NavigationShell (ใช้แถบบนของแอปร่วมกัน ไม่มี AppBar ของตัวเอง)
  final bool embedded;

  /// true = มุมมองเจ้าของหอ (คุยกับผู้เช่า) / false = มุมมองผู้เช่า (คุยกับเจ้าของหอ)
  final bool asSeller;

  /// ไม่ต้องส่ง = ใช้ server จริง (ส่งตัวปลอมตอน widget test)
  final ChatService? service;

  const ChatView({
    super.key,
    this.embedded = false,
    this.asSeller = false,
    this.service,
  });

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

  void _openLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthView()));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.asSeller ? 'แชทผู้เช่า' : 'แชทสนทนา (DM)';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(title),
              leading: Navigator.of(context).canPop()
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Center(
                        child: CircleIconButton(
                          size: 40,
                          tooltip: 'ย้อนกลับ',
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    )
                  : null,
            ),
      body: Column(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          Expanded(
            // controller เปลี่ยน (login/logout, โหลดเสร็จ, มีข้อความใหม่) -> วาดใหม่
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!Session.isLoggedIn) return _loginPrompt();
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final conversations = _controller.conversations;
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: conversations.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 140),
                Icon(
                  Icons.forum_outlined,
                  size: 52,
                  color: AppColors.muted.withOpacity(0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.asSeller
                      ? 'ยังไม่มีผู้เช่าทักมา'
                      : 'ยังไม่มีห้องแชท\nเริ่มแชทได้จากหน้ารายละเอียดหอพัก',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.5),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final conv = conversations[i];
                return _ContactTile(
                  conversation: conv,
                  asSeller: widget.asSeller,
                  onTap: () => _openRoom(conv),
                );
              },
            ),
    );
  }

  Widget _loginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'กรุณาเข้าสู่ระบบก่อนใช้งานแชท',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'เข้าสู่ระบบแล้วจะเห็นห้องแชททั้งหมดของคุณที่นี่',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openLogin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('ไปหน้าเข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// การ์ดห้องแชท 1 ห้องในรายการ
class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final bool asSeller;
  final VoidCallback onTap;
  const _ContactTile({
    required this.conversation,
    required this.asSeller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation['other_name']?.toString() ?? '';
    final dormName = conversation['dorm_name']?.toString() ?? '';
    final subtitle = asSeller ? 'สนใจ $dormName' : dormName;
    final lastMessage =
        conversation['last_message']?.toString() ?? 'ยังไม่มีข้อความ';
    final time = formatChatTime(conversation['last_sent_at']);
    final unread = (conversation['unread'] as num?)?.toInt() ?? 0;
    final hasUnread = unread > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              ChatAvatar(name: name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread ? AppColors.accent : AppColors.muted,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasUnread ? AppColors.ink : AppColors.muted,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
