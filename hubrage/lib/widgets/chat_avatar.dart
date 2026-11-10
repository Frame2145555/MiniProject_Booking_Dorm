import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// รูปโปรไฟล์วงกลมในแชท: ตัวอักษรแรกของชื่อ บนพื้นไล่เฉดของแอป
/// (ใช้ร่วมกันในหน้ารายการแชทและหน้าห้องแชท)
class ChatAvatar extends StatelessWidget {
  final String name;
  final double size;
  const ChatAvatar({super.key, required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    // ตัดคำนำหน้า "คุณ" ออก แล้วใช้ตัวอักษรแรกของชื่อ
    final clean = name.replaceFirst('คุณ', '').trim();
    final initial = clean.isEmpty ? '?' : clean.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
