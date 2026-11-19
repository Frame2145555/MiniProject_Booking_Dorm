import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// แถบบนของแอป: เมนู 3 ขีด (ซ้าย) • โลโก้ • แจ้งเตือน + บัญชี (ขวาบน)
/// ใช้ร่วมกันทุกบทบาท โดยผู้เช่าจะมีปุ่มบัญชีอยู่ถัดจากกระดิ่งแจ้งเตือน
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback? onAccount; // null = ไม่แสดงปุ่มบัญชี
  final String? subtitle;
  final bool hasUnread;

  const AppTopBar({
    super.key,
    required this.onMenu,
    required this.onNotifications,
    this.onAccount,
    this.subtitle,
    this.hasUnread = true,
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
                CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'การแจ้งเตือน',
                  showDot: hasUnread,
                  onPressed: onNotifications,
                ),
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

/// แสดงการแจ้งเตือนจริงเมื่อส่งข้อมูลจาก server หรือข้อมูลตัวอย่างในโหมด guest
Future<void> showNotificationsSheet(
  BuildContext context, {
  List<Map<String, dynamic>>? notifications,
}) {
  const demoItems =
      <({
        IconData icon,
        Color color,
        Color background,
        String title,
        String message,
        bool isRead,
      })>[
    (
      icon: Icons.celebration_rounded,
      color: AppColors.accent,
      background: AppColors.accentSoft,
      title: 'ยินดีต้อนรับสู่ Dorm Master',
      message: 'เริ่มค้นหาและบันทึกหอพักที่ถูกใจได้เลย',
      isRead: false,
    ),
    (
      icon: Icons.forum_rounded,
      color: AppColors.info,
      background: AppColors.infoSoft,
      title: 'มีข้อความใหม่ในแชท',
      message: 'เจ้าของหอตอบคำถามเรื่องห้องว่างของคุณแล้ว',
      isRead: false,
    ),
    (
      icon: Icons.favorite_rounded,
      color: AppColors.danger,
      background: AppColors.dangerSoft,
      title: 'หอที่คุณบันทึกไว้อัปเดตข้อมูล',
      message: 'ตรวจสอบราคาและห้องว่างล่าสุดได้ที่หน้ารายการโปรด',
      isRead: false,
    ),
  ];

  final items = notifications == null
      ? demoItems
      : notifications.map((notification) {
        final type = notification['type']?.toString();
        final resolved = type == 'dorm_report_resolved';
        final dismissed = type == 'dorm_report_dismissed';
        // เจ้าของหอ: แอดมินตรวจสอบค่ามัดจำแล้ว รอเจ้าของหอยืนยันการจอง
        final deposit = type == 'deposit_approved';
        return (
          icon: deposit
              ? Icons.payments_rounded
              : resolved
              ? Icons.task_alt_rounded
              : dismissed
              ? Icons.info_outline_rounded
              : Icons.notifications_rounded,
          color: deposit
              ? AppColors.success
              : dismissed
              ? AppColors.warning
              : AppColors.info,
          background: deposit
              ? AppColors.successSoft
              : dismissed
              ? AppColors.warningSoft
              : AppColors.infoSoft,
          title: notification['title']?.toString() ?? 'การแจ้งเตือน',
          message: notification['message']?.toString() ?? '',
          isRead: notification['isRead'] == true,
        );
      }).toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
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
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'ยังไม่มีการแจ้งเตือน',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!item.isRead)
                                    const Icon(
                                      Icons.circle,
                                      color: AppColors.info,
                                      size: 8,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.message,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
