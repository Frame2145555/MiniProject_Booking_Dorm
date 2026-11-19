import 'dart:convert';

import 'package:http/http.dart' as http;

http.Response ownerJson(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// หอพักตัวอย่างในรูปแบบเดียวกับที่ GET /api/owner/dorms ส่งมา
Map<String, dynamic> ownerDormJson({
  int id = 1,
  String title = 'หอทดสอบ',
  String approvalStatus = 'approved',
  String listingStatus = 'active',
}) => {
  'id': id,
  'sellerId': 3,
  'title': title,
  'location': 'ซอยทดสอบ 1',
  'phone': '0812345678',
  'description': 'หอพักสำหรับทดสอบ',
  'priceMin': 4000,
  'priceMax': 6000,
  'imageUrl': '', // ว่าง = ไม่โหลดรูปจากเน็ตตอนเทสต์
  'amenities': ['แอร์', 'Wi-Fi'],
  'approvalStatus': approvalStatus,
  'listingStatus': listingStatus,
  'viewCount': 12,
  'images': [],
  'roomsList': [
    {
      'id': id * 10 + 1,
      'roomNumber': '101',
      'roomType': 'เตียง 5 ฟุต',
      'price': 4500,
      'floor': 1,
      'status': 'available',
    },
    {
      'id': id * 10 + 2,
      'roomNumber': '102',
      'roomType': 'เตียง 5 ฟุต',
      'price': 4500,
      'floor': 1,
      'status': 'occupied',
    },
  ],
};

/// server จำลองของระบบเจ้าของหอ ใช้คู่กับ MockClient(api.handle) -> OwnerApiService.client
/// จด request ทุกครั้งไว้ใน [requests] เพื่อตรวจว่าหน้าเรียก API ถูกเส้นทาง/แนบ token
class FakeOwnerApi {
  final List<http.Request> requests = [];

  Map<String, dynamic> stats = {
    'account_status': 'active',
    'verified_owner': false,
  };
  List<Map<String, dynamic>> dorms = [];
  List<Map<String, dynamic>> visitRequests = [];
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> reviews = [];
  /// รูปแบบเดียวกับ GET /api/owner/revenue (owner_revenue_routes.js)
  Map<String, dynamic> revenue = {
    'year': 2026,
    'years': [2026],
    'yearRevenue': 0,
    'yearCount': 0,
    'totalRevenue': 0,
    'completedCount': 0,
    'pendingAmount': 0,
    'pendingCount': 0,
    'byMonth': [],
    'byDorm': [],
    'recent': [],
  };

  /// ไม่ null = สถิติแดชบอร์ดตอบ 500 พร้อมข้อความนี้
  String? statsError;

  /// true = ทุกเส้นทางตอบ 401 (token หมดอายุ)
  bool unauthorized = false;

  List<http.Request> to(String path) =>
      requests.where((request) => request.url.path == path).toList();

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (unauthorized) return ownerJson({'message': 'โทเคนหมดอายุ'}, 401);
    switch (request.url.path) {
      case '/api/owner/dashboard/stats':
        if (statsError != null) return ownerJson({'message': statsError}, 500);
        return ownerJson({'data': stats});
      case '/api/owner/dorms':
        return ownerJson({'data': dorms});
      case '/api/owner/visit-requests':
        return ownerJson({'data': visitRequests});
      case '/api/owner/bookings':
        return ownerJson({'data': bookings});
      case '/api/booking/owner/reviews':
        return ownerJson({'data': reviews});
      case '/api/owner/revenue':
        return ownerJson({'data': revenue});
    }
    return ownerJson({'message': 'ไม่พบ ${request.url.path}'}, 404);
  }
}
