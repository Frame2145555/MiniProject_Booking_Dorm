/// Model: ข้อมูลการจอง 1 รายการ (ตรงกับข้อมูลที่ API /api/dashboard/bookings ส่งมา)
class Booking {
  final int id;
  final String referenceCode;
  final String status; // pending, reserved, checked_in, completed, cancelled
  final String semesterName;
  final int leaseMonths;
  final DateTime moveInDate;
  final DateTime moveOutDate;
  final double monthlyRent;
  final double totalAmount;
  final double depositAmount;
  final double depositPaid;
  final String roomNumber;
  final String roomType;
  final String buildingCode;
  final String buildingName;
  final List<String> addons;

  const Booking({
    required this.id,
    required this.referenceCode,
    required this.status,
    required this.semesterName,
    required this.leaseMonths,
    required this.moveInDate,
    required this.moveOutDate,
    required this.monthlyRent,
    required this.totalAmount,
    required this.depositAmount,
    required this.depositPaid,
    required this.roomNumber,
    required this.roomType,
    required this.buildingCode,
    required this.buildingName,
    required this.addons,
  });

  /// ข้อความหัวการ์ด เช่น "Room 102 · North Hall (Block A)"
  String get roomTitle => 'Room $roomNumber · $buildingName (Block $buildingCode)';

  /// จำนวนวันที่เหลือก่อนวันเข้าพัก (นับเป็นวันเต็ม ไม่สนเวลา)
  int get daysUntilMoveIn {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final moveIn = DateTime.utc(moveInDate.year, moveInDate.month, moveInDate.day);
    return moveIn.difference(today).inDays;
  }
}
