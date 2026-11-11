import 'package:flutter/foundation.dart';

import '../services/session.dart';
import '../services/tenant_api_service.dart';
import 'dorm_catalog.dart';

/// รายการหอพักที่ผู้เช่ากดหัวใจไว้ (แชร์ระหว่างหน้าแรก / ค้นหา / รายการโปรด)
/// อ้างอิงด้วยชื่อหอพักเหมือนเดิม (หน้าเดิมเรียกใช้ได้เหมือนเดิม)
///
/// เชื่อม server แล้ว:
/// - login อยู่ -> กดหัวใจ = บันทึกลงตาราง favorites ใน MySQL (POST /api/tenant/dorms/favorite)
/// - โหลดรายการหอใหม่ (ตอน login / เปิดแอป) -> ดึงหอโปรดของบัญชีนั้นมาแสดง
/// - ยังไม่ login -> จำไว้ในแอปชั่วคราว พอ login แล้วจะส่งขึ้น server ให้
/// - logout -> ล้างหอโปรด (เป็นของบัญชีที่ออกไปแล้ว)
class FavoritesState extends ChangeNotifier {
  FavoritesState({DormStore? store}) : _store = store ?? DormCatalog.live {
    _store.addListener(_syncFromServer);
    Session.loggedIn.addListener(_onSessionChanged);
  }

  final DormStore _store;
  final Set<String> _titles = {};

  /// หัวใจที่กดตอนยังไม่ login (ส่งขึ้น server หลัง login)
  final Set<String> _pendingTitles = {};

  /// หอที่กำลังส่งคำขอ (กันกดรัวๆ แล้วสถานะสลับไปมา)
  final Set<String> _busy = {};

  /// ข้อความ error ล่าสุด (เช่น server ใช้ไม่ได้) ให้หน้าที่สนใจเอาไปโชว์
  String? lastError;

  int get count => _titles.length;

  bool isFavorite(String title) => _titles.contains(title);

  void set(String title, bool value) {
    final changed = value ? _titles.add(title) : _titles.remove(title);
    if (!changed) return;
    notifyListeners();

    final dbId = _store.byTitle(title)?['dbId'] as int?;
    if (dbId == null) return; // หอตัวอย่าง (ไม่ได้มาจาก server) -> จำไว้ในแอปอย่างเดียว
    if (!Session.isLoggedIn) {
      value ? _pendingTitles.add(title) : _pendingTitles.remove(title);
      return;
    }
    _pushToServer(title, dbId, value);
  }

  void toggle(String title) => set(title, !isFavorite(title));

  Future<void> _pushToServer(String title, int dbId, bool value) async {
    if (!_busy.add(title)) return;
    try {
      // server สลับสถานะให้ -> ถ้าผลยังไม่ตรงกับที่ต้องการ (เช่น กดจากอีกเครื่อง) สลับอีกครั้ง
      var now = await TenantApiService.toggleFavorite(dbId);
      if (now != value) now = await TenantApiService.toggleFavorite(dbId);
      lastError = null;
      _apply(title, now);
    } on TenantApiException catch (e) {
      lastError = e.message;
      _apply(title, !value); // บันทึกไม่สำเร็จ -> คืนสถานะเดิม
    } finally {
      _busy.remove(title);
    }
  }

  void _apply(String title, bool value) {
    value ? _titles.add(title) : _titles.remove(title);
    notifyListeners();
  }

  /// รายการหอโหลดใหม่ -> เอาหอโปรดของบัญชีที่ login อยู่มาใช้
  void _syncFromServer() {
    if (!_store.hasServerData || _store.isLoading) return;
    if (!Session.isLoggedIn || _store.loadedForUserId != Session.userId) return;

    final serverTitles = _store.dorms
        .where((d) => d['isFavorite'] == true)
        .map((d) => d['title'].toString())
        .toSet();
    final pending = _pendingTitles.difference(serverTitles).toList();
    _pendingTitles.clear();

    _titles
      ..clear()
      ..addAll(serverTitles)
      ..addAll(pending);
    notifyListeners();

    for (final title in pending) {
      final dbId = _store.byTitle(title)?['dbId'] as int?;
      if (dbId != null) _pushToServer(title, dbId, true);
    }
  }

  void _onSessionChanged() {
    if (Session.isLoggedIn) return; // login -> รอรายการหอโหลดเสร็จแล้วค่อย sync
    _titles.clear();
    _pendingTitles.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _store.removeListener(_syncFromServer);
    Session.loggedIn.removeListener(_onSessionChanged);
    super.dispose();
  }
}
