class KYCRequestModel {
  final String id;
  final String sellerName;
  final String dormName;
  final String phone;
  final String email;
  final String idCardNumber;
  final String? idCardImage;
  final String? selfieImage;
  final String watermarkText;
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
    this.idCardImage,
    this.selfieImage,
    this.watermarkText = 'ใช้สำหรับตรวจสอบสิทธิ์ DORM MASTER เท่านั้น',
    this.status = 'pending',
    List<String>? checkedItems,
    List<Map<String, String>>? reviewHistory,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  }) : checkedItems = checkedItems ?? <String>[],
       reviewHistory =
           reviewHistory ??
           <Map<String, String>>[
             {
               'action': 'ส่งคำขอ KYC',
               'date': submissionDate,
               'detail': 'ผู้ขายส่งคำขอเพื่อยืนยันตัวตน',
             },
           ];

  factory KYCRequestModel.fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] as List? ?? const []).whereType<Map>().map(
      (e) => Map<String, dynamic>.from(e),
    );
    final idCard = docs
        .where((d) => d['documentType'] == 'id_card')
        .firstOrNull;
    final selfie = docs
        .where((d) => d['documentType'] == 'selfie_with_id')
        .firstOrNull;
    return KYCRequestModel(
      id: '${json['id']}',
      sellerName: '${json['sellerName'] ?? '-'}',
      dormName: '${json['dormName'] ?? '-'}',
      phone: '${json['sellerPhone'] ?? '-'}',
      email: '${json['sellerEmail'] ?? '-'}',
      idCardNumber: '${json['idCardNumber'] ?? '-'}',
      submissionDate: '${json['submittedAt'] ?? '-'}',
      status: '${json['status'] ?? 'pending'}',
      rejectionReason: json['rejectionReason']?.toString(),
      idCardImage: idCard?['fileData']?.toString(),
      selfieImage: selfie?['fileData']?.toString(),
      watermarkText:
          (idCard?['watermarkText'] ??
                  json['watermarkText'] ??
                  'ใช้สำหรับตรวจสอบสิทธิ์ DORM MASTER เท่านั้น')
              .toString(),
    );
  }
}
