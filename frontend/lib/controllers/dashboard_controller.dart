import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/roommate.dart';

/// Controller: เก็บสถานะของหน้า Dashboard และบอกหน้าจอเมื่อข้อมูลเปลี่ยน
/// Sprint 2: โหลดจากข้อมูลจำลอง   Sprint 4: เปลี่ยนเป็นเรียก API จริง
class DashboardController extends ChangeNotifier {
  List<Booking> _bookings = [];
  Map<int, List<Roommate>> _roommates = {};
  List<Payment> _payments = [];
  bool _isLoading = false;
  bool _disposed = false;

  List<Booking> get bookings => _bookings;
  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  List<Roommate> roommatesOf(int bookingId) => _roommates[bookingId] ?? [];

  double get totalPaid => _sumByStatus('paid');
  double get totalRefunded => _sumByStatus('refunded');
  double get totalPending => _sumByStatus('pending');

  double _sumByStatus(String status) {
    return _payments
        .where((p) => p.status == status)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    // จำลองการรอข้อมูลจากเซิร์ฟเวอร์
    await Future.delayed(const Duration(milliseconds: 300));

    _bookings = mockBookings;
    _roommates = mockRoommates;
    _payments = mockPayments;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
