import 'package:flutter/material.dart';

/// Design tokens ของแอป (อ้างอิงดีไซน์: โทนขาว-เทาอ่อน + ปุ่ม/แถบสีดำน้ำเงินเข้ม + มุมโค้งมาก)
class AppColors {
  static const Color ink = Color(0xFF1B1F26); // ปุ่มหลัก / nav / ชิปที่เลือก
  static const Color inkSoft = Color(0xFF2B303A);
  static const Color bg = Color(0xFFF7F7F8); // พื้นหลังหน้า
  static const Color surface = Colors.white;
  static const Color field = Color(0xFFF2F3F5); // พื้นช่องกรอก
  static const Color line = Color(0xFFECEDEF);
  static const Color muted = Color(0xFF8A8F98);
  static const Color accent = Color(0xFF6B5FB5); // ม่วงสำหรับลิงก์/ไอคอนรอง
  static const Color accentSoft = Color(0xFFEFEDFA);
  static const Color accentDeep = Color(0xFF3B3470); // ม่วงเข้ม ใช้ไล่เฉดกับ ink
  static const Color star = Color(0xFFF5B301);
  static const Color success = Color(0xFF2E9E6B);
  static const Color successSoft = Color(0xFFE6F6EE);
  static const Color warning = Color(0xFFD98E04);
  static const Color warningSoft = Color(0xFFFFF4DC);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFE8F0FE);
}

class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> chip = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> dark = [
    BoxShadow(color: Color(0x331B1F26), blurRadius: 20, offset: Offset(0, 10)),
  ];
}

class AppGradients {
  /// การ์ดหลักสีเข้ม (Owner / Admin hero)
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.ink, AppColors.accentDeep],
  );

  /// พื้นหลังการ์ดหอพักเมื่อไม่มีรูป (เลือกตามชื่อหอ ให้แต่ละหอดูต่างกัน)
  static const List<LinearGradient> dormCovers = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF69707E), Color(0xFF2A2F3A)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7B6FC4), Color(0xFF2E2A57)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4F8F86), Color(0xFF1E3A3A)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB07A5A), Color(0xFF4A2F26)],
    ),
  ];

  static LinearGradient coverFor(String seed) =>
      dormCovers[seed.hashCode.abs() % dormCovers.length];
}

class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          surface: Colors.white,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerHigh: Colors.white,
          surfaceContainerHighest: AppColors.field,
          error: AppColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.line, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}

/// สไตล์ช่องกรอกข้อความ (พื้นเทาอ่อน มุมโค้ง ไม่มีเส้นขอบ)
class AppInputs {
  static OutlineInputBorder _border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  static InputDecoration field({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: AppColors.field,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(AppColors.ink, 1.2),
    );
  }
}

/// การ์ดขาว มุมโค้ง เงานุ่ม (ใช้แทน Card เดิม)
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.radius = 24,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: shape,
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: shape,
        clipBehavior: clipBehavior,
        child: Material(
          type: MaterialType.transparency,
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// ปุ่มไอคอนทรงกลม (ขาวมีเงา หรือแบบโปร่งแสงบนรูปภาพ)
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color iconColor;
  final double size;
  final bool glass;
  final bool showDot;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor = AppColors.ink,
    this.size = 44,
    this.glass = false,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: glass ? Colors.black.withOpacity(0.35) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: glass ? null : AppShadows.soft,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: size * 0.5,
                color: glass ? Colors.white : iconColor,
              ),
              if (showDot)
                Positioned(
                  top: size * 0.22,
                  right: size * 0.24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// ป้ายสถานะเล็ก ๆ (pill)
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  const StatusPill(
    this.text, {
    super.key,
    this.color = AppColors.ink,
    this.background = AppColors.field,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// หัวข้อ section (ตัวหนา ชิดซ้าย) + ลิงก์ม่วงด้านขวา (ถ้ามี)
class SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionTitle(this.text, {super.key, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
      ],
    );
  }
}
