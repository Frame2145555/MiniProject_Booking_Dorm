import 'package:flutter/material.dart';

import '../services/session.dart';
import '../services/tenant_api_service.dart';
import 'admin_console_state.dart';

/// ข้อมูลหอพักตัวอย่างที่ผู้เช่าเห็น + ตัวช่วยรวมหอที่แอดมินอนุมัติแล้ว
/// (ย้ายมาจาก HomeView เพื่อให้หน้าแรก / ค้นหา / รายการโปรด ใช้ร่วมกัน)
class DormCatalog {
  DormCatalog._();

  static const List<Map<String, dynamic>> baseDorms = [
    {
      'id': 'dorm_1',
      'title': 'หอรวย เธะ',
      'price': '5,000 - 8,500',
      'minPrice': 5000,
      'maxPrice': 8500,
      'rating': '4.7',
      'phone': '081-234-5678',
      'location': 'ซอยรามคำแหง 24 • ใกล้มหาวิทยาลัยรามคำแหง',
      'tags': ['แอร์', 'Wi-Fi', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_2',
      'title': 'หออิสลาม แกรนด์',
      'price': '6,500 - 9,000',
      'minPrice': 6500,
      'maxPrice': 9000,
      'rating': '4.0',
      'phone': '089-876-5432',
      'location': 'ซอยรามคำแหง 24 • ใกล้ Airport Link หัวหมาก',
      'tags': ['แอร์', 'กล้องวงจรปิด', 'ลิฟต์'],
    },
    {
      'id': 'dorm_3',
      'title': 'HU 24 อพาร์ตเมนต์',
      'price': '7,200 - 11,000',
      'minPrice': 7200,
      'maxPrice': 11000,
      'rating': '4.9',
      'phone': '082-333-4455',
      'location': 'รามคำแหง 24 แยก 2 • ใกล้เอแบค ABAC',
      'tags': ['ฟิตเนส', 'สระว่ายน้ำ', 'เลี้ยงสัตว์ได้', 'แอร์', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_4',
      'title': 'กรีนวิลล์ คอนโดเช่า',
      'price': '4,800 - 7,000',
      'minPrice': 4800,
      'maxPrice': 7000,
      'rating': '4.5',
      'phone': '086-555-6677',
      'location': 'ซอยหลังราม • ใกล้สนามราชมังคลาฯ และ MRT',
      'tags': ['เครื่องซักผ้า', 'รปภ. 24ชม.', 'แอร์', 'เลี้ยงสัตว์ได้'],
    },
  ];

  static const List<Map<String, dynamic>> amenities = [
    {'label': 'แอร์', 'icon': Icons.ac_unit},
    {'label': 'เลี้ยงสัตว์ได้', 'icon': Icons.pets},
    {'label': 'ที่จอดรถ', 'icon': Icons.directions_car},
    {'label': 'Wi-Fi', 'icon': Icons.wifi},
    {'label': 'กล้องวงจรปิด', 'icon': Icons.videocam},
    {'label': 'ลิฟต์', 'icon': Icons.elevator},
    {'label': 'ฟิตเนส', 'icon': Icons.fitness_center},
    {'label': 'สระว่ายน้ำ', 'icon': Icons.pool},
    {'label': 'เครื่องซักผ้า', 'icon': Icons.local_laundry_service},
    {'label': 'รปภ. 24ชม.', 'icon': Icons.security},
  ];

  /// รายการหอจริงจาก MySQL (GET /api/tenant/dorms) -> หน้าแรก / ค้นหา / รายการโปรด ฟังตัวนี้
  static final DormStore live = DormStore();

  /// หอทั้งหมดที่ผู้เช่าควรเห็น
  /// - โหลดจาก server ได้แล้ว -> ใช้ข้อมูลจริง (server กรองหอที่ยังไม่อนุมัติ/ปิดประกาศให้แล้ว)
  /// - ยังไม่เคยโหลดได้ (ไม่มี server) -> ใช้หอตัวอย่างเดิม ([useMockWhenOffline] = true)
  static List<Map<String, dynamic>> visibleDorms(AdminConsoleState? state) {
    if (live.hasServerData || !live.useMockWhenOffline) return live.dorms;

    final approvedOwnerDorms = (state?.approvedDorms ?? const []).map(
      (request) => <String, dynamic>{
        ...request,
        'id': request['dormId'],
        'title': request['dormName'],
        'price': '${request['priceMin']} - ${request['priceMax']}',
        'minPrice': request['priceMin'],
        'maxPrice': request['priceMax'],
        'tags': request['amenities'] ?? <String>[],
      },
    );
    final dorms = [...baseDorms, ...approvedOwnerDorms];
    return dorms
        .where((dorm) => !(state?.isDormClosed(dorm['id'].toString()) ?? false))
        .toList();
  }

  /// 5000 -> '5,000'
  static String money(Object? value) {
    final n = num.tryParse(value?.toString() ?? '')?.round() ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  /// แปลงหอจาก API ให้เป็นรูปแบบเดียวกับหอตัวอย่าง (หน้าเดิมใช้ต่อได้โดยไม่ต้องแก้)
  static Map<String, dynamic> fromApi(Map<String, dynamic> d) {
    final min = num.tryParse('${d['priceMin']}')?.round() ?? 0;
    final max = num.tryParse('${d['priceMax']}')?.round() ?? min;
    return {
      ...d,
      'id': '${d['id']}', // ใช้เป็น key ในแอป (หน้ารายละเอียดแปลงกลับเป็นเลขเอง)
      'dbId': int.tryParse('${d['id']}'),
      'title': d['title']?.toString() ?? '',
      'location': d['location']?.toString() ?? '',
      'phone': d['phone']?.toString() ?? '',
      'price': '${money(min)} - ${money(max)}',
      'minPrice': min,
      'maxPrice': max,
      'rating': '${d['rating'] ?? '-'}',
      'imageUrl': d['imageUrl']?.toString() ?? '',
      'tags': List<String>.from((d['tags'] as List?) ?? const []),
      'isFavorite': d['isFavorite'] == 1 || d['isFavorite'] == true,
    };
  }
}

/// เก็บรายการหอที่โหลดจาก server (ChangeNotifier -> หน้าที่ฟังอยู่ rebuild เอง)
/// โหลดใหม่อัตโนมัติเมื่อ login / logout (เพื่อให้รู้ว่าหอไหนเป็นหอโปรดของคนที่ login)
class DormStore extends ChangeNotifier {
  DormStore() {
    Session.loggedIn.addListener(load);
  }

  /// true = server ใช้ไม่ได้ให้โชว์หอตัวอย่างแทน (ไว้เดโมตอนไม่ได้เปิด server)
  bool useMockWhenOffline = true;

  List<Map<String, dynamic>> _dorms = [];
  List<Map<String, dynamic>> get dorms => _dorms;

  bool hasServerData = false;
  bool isLoading = false;
  String? error;

  /// ผลโหลดล่าสุดเป็นของ user id ไหน (0 = ไม่ได้ login)
  int loadedForUserId = -1;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    final userId = Session.isLoggedIn ? Session.userId : 0;
    try {
      final rows = await TenantApiService.getDorms();
      _dorms = rows.map(DormCatalog.fromApi).toList();
      hasServerData = true;
      loadedForUserId = userId;
    } on TenantApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    Session.loggedIn.removeListener(load);
    super.dispose();
  }

  Map<String, dynamic>? byTitle(String title) {
    for (final d in _dorms) {
      if (d['title'] == title) return d;
    }
    return null;
  }
}
