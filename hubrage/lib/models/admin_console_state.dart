import 'package:flutter/foundation.dart';

import '../services/admin_api_service.dart';
import '../services/session.dart';
import 'dorm_catalog.dart';

/// Shared state ของหน้าแอดมิน
/// - login ด้วยบัญชี admin -> โหลดเจ้าของหอ / คำขอลงประกาศหอ จาก server (/api/admin)
///   และปุ่มอนุมัติหอ / ระงับบัญชี จะบันทึกลง MySQL จริง ([serverMode] = true)
/// - ยังไม่ได้ login เป็น admin -> ใช้ข้อมูลตัวอย่างในไฟล์นี้เหมือนเดิม
/// (รีวิวยังเป็นข้อมูลตัวอย่าง เพราะฐานข้อมูลยังไม่มีตารางรีวิว)
class AdminConsoleState extends ChangeNotifier {
  AdminConsoleState() {
    _mockSellers = sellers.map((s) => Map<String, dynamic>.from(s)).toList();
    _mockViews = Map<String, int>.from(dormViews);
    Session.loggedIn.addListener(_onSessionChanged);
    if (AdminApiService.isAdmin) loadFromServer();
  }

  late final List<Map<String, dynamic>> _mockSellers;
  late final Map<String, int> _mockViews;

  /// true = ข้อมูลในหน้าแอดมินมาจาก server แล้ว
  bool serverMode = false;
  bool loadingServer = false;
  String? serverError;

  final List<Map<String, dynamic>> sellers = [
    {
      'id': 'seller_001',
      'dormId': 'dorm_1',
      'name': 'นายสมชาย ใจดี',
      'email': 'somchai@email.com',
      'phone': '081-234-5678',
      'dorm': 'หอรวย เธะ (รามคำแหง 24)',
      'kyc': 'verified',
      'status': 'active',
      'joined': '12 ก.ย. 2026',
      'views': 1280,
      'rooms': 24,
      'bookings': 18,
      'reports': 0,
      'lastActive': 'วันนี้ 09:42',
    },
    {
      'id': 'seller_002',
      'dormId': 'dorm_2',
      'name': 'นางสาววิภาวดี รุ่งเรือง',
      'email': 'wipawadee@email.com',
      'phone': '089-876-5432',
      'dorm': 'หออิสลาม แกรนด์',
      'kyc': 'pending',
      'status': 'active',
      'joined': '04 พ.ย. 2026',
      'views': 642,
      'rooms': 18,
      'bookings': 7,
      'reports': 1,
      'lastActive': 'เมื่อวาน 18:20',
    },
    {
      'id': 'seller_003',
      'dormId': 'dorm_3',
      'name': 'นายธนกฤต วัฒนา',
      'email': 'thanakrit@email.com',
      'phone': '092-111-2233',
      'dorm': 'HU 24 อพาร์ตเมนต์',
      'kyc': 'verified',
      'status': 'suspended',
      'joined': '28 ต.ค. 2026',
      'views': 2094,
      'rooms': 32,
      'bookings': 25,
      'reports': 3,
      'lastActive': '06 พ.ย. 2026',
    },
  ];

  /// รีวิวจากผู้เช่า (ข้อมูลตัวอย่าง) — status: visible | hidden
  final List<Map<String, dynamic>> reviews = [
    {
      'id': 'review_001',
      'dormId': 'dorm_1',
      'dormName': 'หอรวย เธะ',
      'author': 'คุณกิตติ',
      'rating': 5,
      'comment': 'ห้องสะอาด เจ้าของใจดี เดินทางสะดวกมากครับ',
      'date': '08 พ.ย. 2026',
      'status': 'visible',
    },
    {
      'id': 'review_002',
      'dormId': 'dorm_1',
      'dormName': 'หอรวย เธะ',
      'author': 'คุณนภา',
      'rating': 2,
      'comment': 'น้ำไหลเบาช่วงเย็น และ Wi-Fi หลุดบ่อย',
      'date': '05 พ.ย. 2026',
      'status': 'visible',
    },
    {
      'id': 'review_003',
      'dormId': 'dorm_2',
      'dormName': 'หออิสลาม แกรนด์',
      'author': 'ผู้ใช้นิรนาม',
      'rating': 1,
      'comment': 'ข้อความไม่เหมาะสม (ตัวอย่างรีวิวที่ถูกรายงาน)',
      'date': '03 พ.ย. 2026',
      'status': 'visible',
    },
    {
      'id': 'review_004',
      'dormId': 'dorm_3',
      'dormName': 'HU 24 อพาร์ตเมนต์',
      'author': 'คุณปรีชา',
      'rating': 4,
      'comment': 'ห้องกว้าง มีลิฟต์ ราคาสมเหตุสมผล',
      'date': '01 พ.ย. 2026',
      'status': 'visible',
    },
  ];

  final List<Map<String, dynamic>> dormRequests = [];

  final Set<String> temporarilyClosedDorms = {};
  final Map<String, int> dormViews = {
    'dorm_1': 1280,
    'dorm_2': 642,
    'dorm_3': 2094,
  };

  // ───────────── เชื่อม server (/api/admin) ─────────────

  void _onSessionChanged() {
    if (AdminApiService.isAdmin) {
      loadFromServer();
    } else if (serverMode || serverError != null) {
      // ออกจากบัญชีแอดมิน -> กลับไปใช้ข้อมูลตัวอย่าง
      serverMode = false;
      serverError = null;
      sellers
        ..clear()
        ..addAll(_mockSellers.map((s) => Map<String, dynamic>.from(s)));
      dormRequests.clear();
      dormViews
        ..clear()
        ..addAll(_mockViews);
      notifyListeners();
    }
  }

  Future<void> loadFromServer() async {
    loadingServer = true;
    serverError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        AdminApiService.getSellers(),
        AdminApiService.getDorms(status: 'all'),
      ]);
      sellers
        ..clear()
        ..addAll(results[0].map(_sellerFromApi));
      dormRequests
        ..clear()
        ..addAll(results[1].map(_dormFromApi));
      dormViews
        ..clear()
        ..addAll({
          for (final d in results[1])
            '${d['id']}': int.tryParse('${d['views']}') ?? 0,
        });
      serverMode = true;
    } on AdminApiException catch (e) {
      serverError = e.message;
    } finally {
      loadingServer = false;
      notifyListeners();
    }
  }

  static String _thaiDate(Object? raw) {
    final t = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (t == null) return '-';
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return '${t.day.toString().padLeft(2, '0')} ${months[t.month - 1]} ${t.year}';
  }

  static int _int(Object? v) => int.tryParse('$v') ?? 0;

  static Map<String, dynamic> _sellerFromApi(Map<String, dynamic> s) => {
        'id': '${s['id']}',
        'dormId': s['dormId'] == null ? '' : '${s['dormId']}',
        'name': s['name']?.toString() ?? '-',
        'email': s['email']?.toString() ?? '-',
        'phone': s['phone']?.toString() ?? '-',
        'dorm': s['dorm']?.toString() ?? 'ยังไม่มีหอพัก',
        'kyc': s['kyc'] == 'approved' ? 'verified' : 'pending',
        'status': s['status']?.toString() ?? 'active',
        'joined': _thaiDate(s['joined']),
        'views': _int(s['views']),
        'rooms': _int(s['rooms']),
        'bookings': _int(s['bookings']),
        'reports': _int(s['reports']),
        'lastActive': '-',
      };

  static Map<String, dynamic> _dormFromApi(Map<String, dynamic> d) => {
        'id': '${d['id']}',
        'sellerId': '${d['sellerId']}',
        'sellerName': d['sellerName']?.toString() ?? '-',
        'dormId': '${d['id']}',
        'dormName': d['dormName']?.toString() ?? '-',
        'phone': d['phone']?.toString() ?? '-',
        'location': d['location']?.toString() ?? '-',
        'latitude': double.tryParse('${d['latitude']}'),
        'longitude': double.tryParse('${d['longitude']}'),
        'description': d['description']?.toString() ?? '',
        'priceMin': _int(d['priceMin']),
        'priceMax': _int(d['priceMax']),
        'amenities': List<String>.from((d['amenities'] as List?) ?? const []),
        'imageUrl': d['imageUrl']?.toString() ?? '',
        'images': const [],
        'documents': ((d['documents'] as List?) ?? const [])
            .whereType<Map>()
            .map((doc) => Map<String, dynamic>.from(doc))
            .toList(),
        'status': d['status']?.toString() ?? 'pending',
        'submittedAt': 'ส่งคำขอเมื่อ ${_thaiDate(d['submittedAt'])}',
      };

  /// เรียก API -> ถ้าไม่สำเร็จ ย้อนค่ากลับ ([undo]) แล้วเก็บข้อความ error ไว้แสดง
  Future<void> _sync(Future<void> Function() call, VoidCallback undo) async {
    try {
      await call();
      serverError = null;
    } on AdminApiException catch (e) {
      undo();
      serverError = e.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    Session.loggedIn.removeListener(_onSessionChanged);
    super.dispose();
  }

  int get totalViews => dormViews.values.fold(0, (sum, value) => sum + value);
  int get pendingDormCount =>
      dormRequests.where((request) => request['status'] == 'pending').length;

  void suspendSeller(String sellerId, bool suspend) {
    final seller = sellers.firstWhere((item) => item['id'] == sellerId);
    final before = seller['status'];
    seller['status'] = suspend ? 'suspended' : 'active';
    notifyListeners();
    final userId = int.tryParse(sellerId);
    if (serverMode && userId != null) {
      _sync(
        () => AdminApiService.setUserSuspended(userId, suspend),
        () => seller['status'] = before,
      );
    }
  }

  void submitDormRequest({
    required String sellerId,
    required String sellerName,
    required String dormId,
    required String dormName,
    required String phone,
    required String location,
    required double? latitude,
    required double? longitude,
    required String description,
    required int priceMin,
    required int priceMax,
    required List<String> amenities,
    required String imageUrl,
    List<dynamic> images = const [], // รูปเพิ่มเติม: String (ลิงก์) หรือ Uint8List
    required List<Map<String, String>> documents,
  }) {
    dormRequests.insert(0, {
      'id': 'dorm-request-${DateTime.now().microsecondsSinceEpoch}',
      'sellerId': sellerId,
      'sellerName': sellerName,
      'dormId': dormId,
      'dormName': dormName,
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'amenities': amenities,
      'imageUrl': imageUrl,
      'images': images,
      'documents': documents,
      'status': 'pending',
      'submittedAt': 'ส่งคำขอเมื่อสักครู่',
    });
    notifyListeners();
  }

  void reviewDormRequest(String requestId, {required bool approve}) {
    final request = dormRequests.firstWhere((item) => item['id'] == requestId);
    final before = request['status'];
    request['status'] = approve ? 'approved' : 'rejected';
    notifyListeners();
    final dormId = int.tryParse(requestId);
    if (serverMode && dormId != null) {
      _sync(
        () async {
          await AdminApiService.setDormApproval(dormId, approve);
          DormCatalog.live.load(); // หอที่อนุมัติแล้วขึ้นในหน้าผู้เช่าทันที
        },
        () => request['status'] = before,
      );
    }
  }

  /// อัปเดตรูปของหอที่ส่งคำขอไว้ (เมื่อเจ้าของแก้ไขประกาศ) เพื่อให้ผู้เช่าเห็นรูปล่าสุด
  void updateDormMedia(
    String dormId, {
    required String imageUrl,
    required List<dynamic> images,
  }) {
    for (final request in dormRequests.where((r) => r['dormId'] == dormId)) {
      request['imageUrl'] = imageUrl;
      request['images'] = images;
    }
    notifyListeners();
  }

  bool isDormApproved(String dormId) =>
      const {'dorm_1', 'dorm_2', 'dorm_3', 'dorm_4'}.contains(dormId) ||
      dormRequests.any(
        (request) =>
            request['dormId'] == dormId && request['status'] == 'approved',
      );

  List<Map<String, dynamic>> get approvedDorms =>
      dormRequests.where((request) => request['status'] == 'approved').toList();

  void toggleDormClosed(String dormId, bool closed) {
    if (closed) {
      temporarilyClosedDorms.add(dormId);
    } else {
      temporarilyClosedDorms.remove(dormId);
    }
    notifyListeners();
  }

  bool isDormClosed(String dormId) =>
      !isDormApproved(dormId) ||
      temporarilyClosedDorms.contains(dormId) ||
      sellers.any(
        (seller) =>
            seller['dormId'] == dormId && seller['status'] == 'suspended',
      );

  bool isSellerSuspended(String sellerId) => sellers.any(
    (seller) => seller['id'] == sellerId && seller['status'] == 'suspended',
  );

  // ───────────── จัดการรีวิว (แอดมิน) ─────────────

  /// รีวิวที่ผู้เช่าเห็นได้ของหอนั้น (ไม่รวมที่ถูกซ่อน)
  /// (หอจาก server ใช้ id เป็นเลข เช่น '1' -> ตรงกับรีวิวตัวอย่างของ 'dorm_1')
  List<Map<String, dynamic>> visibleReviewsFor(String dormId) => reviews
      .where(
        (r) =>
            (r['dormId'] == dormId || r['dormId'] == 'dorm_$dormId') &&
            r['status'] == 'visible',
      )
      .toList();

  int get hiddenReviewCount =>
      reviews.where((r) => r['status'] == 'hidden').length;

  void setReviewHidden(String reviewId, bool hidden) {
    final review = reviews.firstWhere((r) => r['id'] == reviewId);
    review['status'] = hidden ? 'hidden' : 'visible';
    notifyListeners();
  }

  void deleteReview(String reviewId) {
    reviews.removeWhere((r) => r['id'] == reviewId);
    notifyListeners();
  }

  void recordDormView(String dormId) {
    dormViews[dormId] = (dormViews[dormId] ?? 0) + 1;
    for (final seller in sellers.where((item) => item['dormId'] == dormId)) {
      seller['views'] = dormViews[dormId];
    }
    notifyListeners();
  }
}
