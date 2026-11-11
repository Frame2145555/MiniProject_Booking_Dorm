class KYCRequestModel {
  final String id;
  final String sellerName;
  final String dormName;
  final String phone;
  final String email;
  final String idCardNumber;
  final String submissionDate;
  String status;
  // ข้อมูลเพิ่มเติมสำหรับ
  final String? documentUrl; // URL รูปเอกสาร KYC
  final String? rejectionReason; // เหตุผลที่ปฏิเสธ
  final String? reviewedAt; // วันที่ Admin ตรวจสอบ
  final String? reviewedBy; // ID ของ Admin ที่ตรวจสอบ

  KYCRequestModel({
    required this.id,
    required this.sellerName,
    required this.dormName,
    required this.phone,
    required this.email,
    required this.idCardNumber,
    required this.submissionDate,
    this.status = 'pending',
    this.documentUrl,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  // แปลง JSON จาก Backend เป็น KYCRequestModel
  factory KYCRequestModel.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];

        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }

      return fallback;
    }

    String? readOptionalString(List<String> keys) {
      final value = readString(keys);

      return value.isEmpty ? null : value;
    }

    return KYCRequestModel(
      id: readString(['id', 'kyc_id']),
      sellerName: readString(['sellerName', 'seller_name', 'name']),
      dormName: readString(['dormName', 'dorm_name']),
      phone: readString(['phone', 'phone_number']),
      email: readString(['email']),
      idCardNumber: readString(['idCardNumber', 'id_card_number']),
      submissionDate: readString([
        'submissionDate',
        'submission_date',
        'submitted_at',
      ]),
      status: readString(['status'], fallback: 'pending'),

      documentUrl: readOptionalString([
        'documentUrl',
        'document_url',
        'id_card_image_url',
      ]),
      rejectionReason: readOptionalString([
        'rejectionReason',
        'rejection_reason',
      ]),
      reviewedAt: readOptionalString(['reviewedAt', 'reviewed_at']),
      reviewedBy: readOptionalString(['reviewedBy', 'reviewed_by']),
    );
  }

  // แปลง KYCRequestModel กลับเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_name': sellerName,
      'dorm_name': dormName,
      'phone': phone,
      'email': email,
      'id_card_number': idCardNumber,
      'submission_date': submissionDate,
      'status': status,
      'document_url': documentUrl,
      'rejection_reason': rejectionReason,
      'reviewed_at': reviewedAt,
      'reviewed_by': reviewedBy,
    };
  }
}
