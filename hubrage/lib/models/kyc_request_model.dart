class KYCRequestModel {
  final String id;
  final String sellerName;
  final String dormName;
  final String phone;
  final String email;
  final String idCardNumber;
  final String submissionDate;
  String status;

  KYCRequestModel({
    required this.id,
    required this.sellerName,
    required this.dormName,
    required this.phone,
    required this.email,
    required this.idCardNumber,
    required this.submissionDate,
    this.status = 'pending',
  });
}
