class KYCRequestModel {
  final String id;
  final String sellerName;
  final String dormName;
  final String phone;
  final String email;
  final String idCardNumber;
  final String submissionDate;
  String status;

  // ข้อมูลชั่วคราว
  final List<String> checkedItems;
  final List<Map<String, String>> reviewHistory;
  String? rejectionReason;
  String? reviewedAt;
  String? reviewedBy;

  KYCRequestModel({
    required this.id,
    required this.sellerName,
    required this.dormName,
    required this.phone,
    required this.email,
    required this.idCardNumber,
    required this.submissionDate,
    this.status = 'pending',
    List<String>? checkedItems,
    List<Map<String, String>>? reviewHistory,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  })  : checkedItems = checkedItems ?? <String>[],
        reviewHistory = reviewHistory ?? <Map<String, String>>[
          {
            'action': 'ส่งคำขอ KYC',
            'date': submissionDate,
            'detail': 'ผู้ขายส่งคำขอเพื่อยืนยันตัวตน',
          },
        ];
}