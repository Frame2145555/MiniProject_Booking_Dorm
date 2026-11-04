/// Model: รายการชำระเงิน 1 รายการ (ตรงกับ API /api/dashboard/payments)
class Payment {
  final int id;
  final String? receiptNo; // null = ยังไม่ได้จ่าย จึงยังไม่มีใบเสร็จ
  final double amount;
  final String paymentType; // deposit, rent
  final String method;
  final String status; // pending, paid, failed, refunded
  final DateTime? paidAt;
  final String referenceCode;
  final String roomNumber;
  final String buildingName;

  const Payment({
    required this.id,
    required this.receiptNo,
    required this.amount,
    required this.paymentType,
    required this.method,
    required this.status,
    required this.paidAt,
    required this.referenceCode,
    required this.roomNumber,
    required this.buildingName,
  });
}
