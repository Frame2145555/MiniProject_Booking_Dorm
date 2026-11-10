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

/// แผงการแจ้งเตือน (ข้อมูลตัวอย่างสำหรับต้นแบบ)
void showNotificationsSheet(BuildContext context) {
  const items = [
    (
      Icons.celebration_rounded,
      AppColors.accent,
      AppColors.accentSoft,
      'ยินดีต้อนรับสู่ Dorm Master',
      'เริ่มค้นหาและบันทึกหอพักที่ถูกใจได้เลย',
    ),
    (
      Icons.forum_rounded,
      AppColors.info,
      AppColors.infoSoft,
      'มีข้อความใหม่ในแชท',
      'เจ้าของหอตอบคำถามเรื่องห้องว่างของคุณแล้ว',
    ),
    (
      Icons.favorite_rounded,
      AppColors.danger,
      AppColors.dangerSoft,
      'หอที่คุณบันทึกไว้อัปเดตข้อมูล',
      'ตรวจสอบราคาและห้องว่างล่าสุดได้ที่หน้ารายการโปรด',
    ),
  ];

  showModalBottomSheet<void>(
    context: context,
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
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.$3,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.$1, color: item.$2, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$4,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$5,
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
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
