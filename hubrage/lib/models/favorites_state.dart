import 'package:flutter/foundation.dart';

/// รายการหอพักที่ผู้เช่ากดหัวใจไว้ (แชร์ระหว่างหน้าแรก / ค้นหา / รายการโปรด)
/// อ้างอิงด้วยชื่อหอพักเหมือนเดิม
class FavoritesState extends ChangeNotifier {
  final Set<String> _titles = {};

  int get count => _titles.length;

  bool isFavorite(String title) => _titles.contains(title);

  void set(String title, bool value) {
    final changed = value ? _titles.add(title) : _titles.remove(title);
    if (changed) notifyListeners();
  }

  void toggle(String title) => set(title, !isFavorite(title));
}
