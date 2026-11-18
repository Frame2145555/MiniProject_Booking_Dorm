import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

/// แถบบนของแอป: เมนู 3 ขีด (ซ้าย) • โลโก้ • แจ้งเตือน + บัญชี (ขวาบน)
/// ใช้ร่วมกันทุกบทบาท โดยผู้เช่าจะมีปุ่มบัญชีอยู่ถัดจากกระดิ่งแจ้งเตือน
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback? onAccount; // null = ไม่แสดงปุ่มบัญชี
  final String? subtitle;

  const AppTopBar({
    super.key,
    required this.onMenu,
    required this.onNotifications,
    this.onAccount,
    this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'เมนู',
                  onPressed: onMenu,
                ),
                const SizedBox(width: 12),
                Expanded(child: _Brand(subtitle: subtitle)),
                _NotificationBell(onPressed: onNotifications),
                if (onAccount != null) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'บัญชีของฉัน',
                    child: GestureDetector(
                      onTap: onAccount,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.dark,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final String? subtitle;
  const _Brand({this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: AppGradients.hero,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dorm Master',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// กระดิ่งแจ้งเตือน: จุดแดงขึ้นเมื่อมีรายการที่ยังไม่อ่านจริงจาก server
/// (เช็กทุก 30 วินาที และเช็กใหม่ทุกครั้งที่ login / logout)
class _NotificationBell extends StatefulWidget {
  final VoidCallback onPressed;
  const _NotificationBell({required this.onPressed});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  Timer? _timer;

  void _refresh() => NotificationService.instance.refreshUnread();

  @override
  void initState() {
    super.initState();
    Session.loggedIn.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Session.loggedIn.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unread,
      builder: (context, unread, _) => CircleIconButton(
        icon: unread > 0
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded,
        tooltip: 'การแจ้งเตือน',
        showDot: unread > 0,
        onPressed: widget.onPressed,
      ),
    );
  }
}

/// แผงการแจ้งเตือน (ข้อมูลจริงจาก GET /api/notifications)
/// เปิดแผงแล้วระบบทำเครื่องหมาย "อ่านแล้ว" ให้ทั้งหมด (รายการใหม่ยังไฮไลต์อยู่ในแผงนี้)
void showNotificationsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Session.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await NotificationService.instance.fetch();
      if (!mounted) return;
      setState(() => _items = result.items);
      if (result.unread > 0) {
        await NotificationService.instance.markAllRead();
      }
    } on NotificationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (IconData, Color, Color) _style(String type) {
    switch (type) {
      case 'deposit_approved':
        return (Icons.payments_rounded, AppColors.success, AppColors.successSoft);
      default:
        return (Icons.notifications_rounded, AppColors.accent, AppColors.accentSoft);
    }
  }

  String _when(DateTime t) =>
      '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _message(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _tile(NotificationItem item) {
    final (icon, color, soft) = _style(item.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.transparent : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (item.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _when(item.createdAt!),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!Session.isLoggedIn) {
      content = _message(
        Icons.lock_outline_rounded,
        'เข้าสู่ระบบเพื่อดูการแจ้งเตือน',
      );
    } else if (_loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      content = Column(
        children: [
          _message(Icons.error_outline_rounded, _error!),
          TextButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      );
    } else if (_items.isEmpty) {
      content = _message(
        Icons.notifications_none_rounded,
        'ยังไม่มีการแจ้งเตือน',
      );
    } else {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [for (final item in _items) _tile(item)],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การแจ้งเตือน',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            content,
          ],
        ),
      ),
    );
  }
}
