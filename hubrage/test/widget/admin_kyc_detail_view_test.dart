import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/kyc_request_model.dart';
import '../../lib/views/admin_kyc_detail_view.dart';

void main() {
  final request = KYCRequestModel(
    id: 'KYC-TEST',
    sellerName: 'ผู้ยื่นทดสอบ',
    dormName: 'หอทดสอบ',
    phone: '0800000000',
    email: 'seller@test.com',
    idCardNumber: '1-2345-67890-12-3',
    submissionDate: '16 พ.ย. 2026',
  );

  testWidgets('shows applicant details and review actions for pending KYC', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminKYCDetailView(kycItem: request),
                ),
              ),
              child: const Text('เปิดรายละเอียด'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดรายละเอียด'));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ยื่นทดสอบ'), findsOneWidget);
    expect(find.text('หอทดสอบ'), findsOneWidget);
    expect(find.text('1-2345-67890-12-3'), findsOneWidget);
    expect(find.text('seller@test.com'), findsOneWidget);
    expect(find.text('ปฏิเสธเอกสาร'), findsOneWidget);
    expect(find.text('อนุมัติเอกสาร (Approve)'), findsOneWidget);
  });

  testWidgets('approved request shows status and back action only', (
    tester,
  ) async {
    final approved = KYCRequestModel(
      id: 'KYC-APPROVED',
      sellerName: 'ผู้ยื่นที่ผ่านแล้ว',
      dormName: 'หอที่ผ่านแล้ว',
      phone: '0800000000',
      email: 'approved@test.com',
      idCardNumber: '1-2345-67890-12-3',
      submissionDate: '16 พ.ย. 2026',
      status: 'approved',
    );

    await tester.pumpWidget(
      MaterialApp(home: AdminKYCDetailView(kycItem: approved)),
    );
    await tester.pumpAndSettle();

    expect(find.text('สถานะ: อนุมัติการยืนยันตัวตนแล้ว'), findsOneWidget);
    expect(find.text('ย้อนกลับ'), findsOneWidget);
    expect(find.text('ปฏิเสธเอกสาร'), findsNothing);
    expect(find.text('อนุมัติเอกสาร (Approve)'), findsNothing);
  });
}
