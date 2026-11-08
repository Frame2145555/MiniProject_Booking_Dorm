import 'package:flutter/material.dart';
import '../models/kyc_request_model.dart';

class AdminKYCDetailView extends StatelessWidget {
  final KYCRequestModel kycItem;

  const AdminKYCDetailView({super.key, required this.kycItem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดคำขอ KYC'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kycItem.status == 'pending' ? Colors.amber.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kycItem.status == 'pending' ? Colors.amber.shade200 : Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    kycItem.status == 'pending' ? Icons.info_outline : Icons.verified,
                    color: kycItem.status == 'pending' ? Colors.amber.shade900 : Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    kycItem.status == 'pending' ? 'สถานะ: รอการตรวจสอบเอกสาร' : 'สถานะ: อนุมัติการยืนยันตัวตนแล้ว',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kycItem.status == 'pending' ? Colors.amber.shade900 : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('ข้อมูลผู้ยื่นคำขอ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow('ชื่อ-นามสกุล:', kycItem.sellerName),
                    const Divider(height: 16),
                    _buildDetailRow('ชื่อหอพักที่ลงทะเบียน:', kycItem.dormName),
                    const Divider(height: 16),
                    _buildDetailRow('เลขประจำตัวประชาชน:', kycItem.idCardNumber),
                    const Divider(height: 16),
                    _buildDetailRow('เบอร์โทรศัพท์:', kycItem.phone),
                    const Divider(height: 16),
                    _buildDetailRow('อีเมล:', kycItem.email),
                    const Divider(height: 16),
                    _buildDetailRow('วันที่ยื่นเอกสาร:', kycItem.submissionDate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('รูปถ่ายบัตรประชาชน (พร้อม Watermark)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.badge_outlined, size: 60, color: Colors.grey),
                      const SizedBox(height: 6),
                      Text('รูปถ่ายบัตรประชาชน: ${kycItem.sellerName}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ใช้สำหรับตรวจสอบสิทธิ์ DORM MASTER เท่านั้น',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (kycItem.status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, 'rejected');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ปฏิเสธเอกสาร'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, 'approved');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('อนุมัติเอกสาร (Approve)'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ย้อนกลับ'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
