import 'package:flutter/material.dart';

/// QR ปลอม (mock up) สำหรับหน้าชำระเงิน — หน้าตาเหมือน QR จริง แต่สแกนไม่ได้
/// ลายเปลี่ยนตาม [data] (เช่น เลขการจอง + ยอดเงิน) แต่ละรายการจะได้ลายไม่ซ้ำกัน
class MockQrCode extends StatelessWidget {
  const MockQrCode({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEDEF)),
      ),
      child: CustomPaint(painter: _MockQrPainter(data)),
    );
  }
}

class _MockQrPainter extends CustomPainter {
  _MockQrPainter(this.data);

  final String data;
  static const _cells = 25;

  /// สุ่มแบบกำหนดผลได้จากข้อความ (ข้อความเดิม = ลายเดิมทุกครั้ง)
  bool _bit(int x, int y) {
    var h = 0x811C9DC5;
    for (final c in '$data:$x:$y'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h % 100 < 47;
  }

  bool _inFinder(int x, int y) {
    bool box(int ox, int oy) => x >= ox && x < ox + 7 && y >= oy && y < oy + 7;
    return box(0, 0) || box(_cells - 7, 0) || box(0, _cells - 7);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _cells;
    final ink = Paint()..color = const Color(0xFF1B1F26);
    for (var y = 0; y < _cells; y++) {
      for (var x = 0; x < _cells; x++) {
        if (_inFinder(x, y) || (x == 7 || y == 7) && (x < 8 && y < 8)) continue;
        if (_bit(x, y)) canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), ink);
      }
    }
    // มุมสี่เหลี่ยม 3 มุม (finder pattern) แบบ QR จริง
    void finder(double ox, double oy) {
      canvas.drawRect(Rect.fromLTWH(ox, oy, cell * 7, cell * 7), ink);
      canvas.drawRect(Rect.fromLTWH(ox + cell, oy + cell, cell * 5, cell * 5), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(ox + cell * 2, oy + cell * 2, cell * 3, cell * 3), ink);
    }

    finder(0, 0);
    finder((_cells - 7) * cell, 0);
    finder(0, (_cells - 7) * cell);
  }

  @override
  bool shouldRepaint(_MockQrPainter old) => old.data != data;
}
