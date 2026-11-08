import 'package:flutter/foundation.dart';

/// Shared in-memory state for the role-switching prototype.
/// Replace with API/repository calls when the backend is connected.
class AdminConsoleState extends ChangeNotifier {
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

  final List<Map<String, dynamic>> dormRequests = [];

  final Set<String> temporarilyClosedDorms = {};
  final Map<String, int> dormViews = {
    'dorm_1': 1280,
    'dorm_2': 642,
    'dorm_3': 2094,
  };

  int get totalViews => dormViews.values.fold(0, (sum, value) => sum + value);
  int get pendingDormCount =>
      dormRequests.where((request) => request['status'] == 'pending').length;

  void suspendSeller(String sellerId, bool suspend) {
    final seller = sellers.firstWhere((item) => item['id'] == sellerId);
    seller['status'] = suspend ? 'suspended' : 'active';
    notifyListeners();
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
      'documents': documents,
      'status': 'pending',
      'submittedAt': 'ส่งคำขอเมื่อสักครู่',
    });
    notifyListeners();
  }

  void reviewDormRequest(String requestId, {required bool approve}) {
    final request = dormRequests.firstWhere((item) => item['id'] == requestId);
    request['status'] = approve ? 'approved' : 'rejected';
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

  void recordDormView(String dormId) {
    dormViews[dormId] = (dormViews[dormId] ?? 0) + 1;
    for (final seller in sellers.where((item) => item['dormId'] == dormId)) {
      seller['views'] = dormViews[dormId];
    }
    notifyListeners();
  }
}
