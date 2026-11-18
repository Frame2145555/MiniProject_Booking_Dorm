import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/owner_api_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

class OwnerKycView extends StatefulWidget {
  const OwnerKycView({super.key});
  @override
  State<OwnerKycView> createState() => _OwnerKycViewState();
}

class _OwnerKycViewState extends State<OwnerKycView> {
  // แยกชื่อ / นามสกุล ให้ตรงกับหน้าสมัครสมาชิก (ตอนส่งจะต่อกันเป็น full_name แบบเดียวกับตอนสมัคร)
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final idCard = TextEditingController();
  String? idImage, selfieImage;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    // เติมข้อมูลที่สมัครไว้ให้ก่อน: full_name = "ชื่อจริง นามสกุล" (คำแรก = ชื่อ, ที่เหลือ = นามสกุล)
    final parts = Session.fullName.trim().split(RegExp(r'\s+'));
    if (parts.first.isNotEmpty) {
      firstName.text = parts.first;
      lastName.text = parts.skip(1).join(' ');
    }
    phone.text = Session.phone;
    email.text = Session.email;
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    idCard.dispose();
    super.dispose();
  }

  Future<void> pick(bool selfie) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final picked = result.first;
    final bytes = await picked.readAsBytes();
    final file =
        'data:image/${picked.extension ?? 'jpeg'};base64,${base64Encode(bytes)}';
    setState(() => selfie ? selfieImage = file : idImage = file);
  }

  /// ตรวจทีละช่องก่อนส่ง (กฎเดียวกับ POST /api/owner/kyc) -> คืนข้อความผิดพลาด หรือ null ถ้าผ่าน
  String? _validate() {
    final phoneDigits = phone.text.replaceAll(RegExp(r'[-\s()]'), '');
    final idDigits = idCard.text.replaceAll(RegExp(r'[- ]'), '');
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
      return 'กรุณากรอกชื่อจริงและนามสกุล';
    }
    if (!RegExp(r'^0\d{8,9}$').hasMatch(phoneDigits)) {
      return 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 0 และมี 9-10 หลัก เช่น 0812345678';
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.text.trim())) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }
    if (!RegExp(r'^\d{13}$').hasMatch(idDigits)) {
      return 'เลขประจำตัวประชาชนต้องเป็นตัวเลข 13 หลัก';
    }
    if (idImage == null) return 'กรุณาอัปโหลดรูปถ่ายบัตรประชาชน';
    return null;
  }

  Future<void> submit() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => saving = true);
    try {
      await OwnerApiService.submitKyc(
        fullName: '${firstName.text.trim()} ${lastName.text.trim()}',
        phone: phone.text,
        email: email.text,
        idCardNumber: idCard.text,
        idCardImage: idImage!,
        selfieImage: selfieImage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำขอ KYC แล้ว รอแอดมินตรวจสอบ')),
        );
        Navigator.pop(context);
      }
    } on OwnerApiException catch (e) {
      debugPrint('[KYC UI ERROR] ${e.message}');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ยืนยันตัวตนเจ้าของหอพัก')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ข้อมูลสำหรับตรวจสอบสิทธิ์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: firstName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'ชื่อจริง *'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: lastName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'นามสกุล *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'เบอร์โทรศัพท์ *',
            hintText: 'เช่น 0812345678',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'อีเมล *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: idCard,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'เลขประจำตัวประชาชน (13 หลัก)',
          ),
        ),
        const SizedBox(height: 20),
        _upload('รูปถ่ายบัตรประชาชน *', idImage, false),
        const SizedBox(height: 12),
        _upload('รูปเซลฟี่คู่บัตรประชาชน (แนะนำ)', selfieImage, true),
        const SizedBox(height: 16),
        const Text(
          'ระบบจะใส่ลายน้ำ “ใช้สำหรับตรวจสอบสิทธิ์ DORM MASTER เท่านั้น” ให้อัตโนมัติ',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: saving ? null : submit,
            child: saving
                ? const CircularProgressIndicator()
                : const Text('ส่งคำขอ KYC'),
          ),
        ),
      ],
    ),
  );

  Widget _upload(String label, String? image, bool selfie) =>
      OutlinedButton.icon(
        onPressed: () => pick(selfie),
        icon: Icon(
          image == null ? Icons.upload_file : Icons.check_circle,
          color: image == null ? AppColors.ink : AppColors.success,
        ),
        label: Text(image == null ? label : '$label: เลือกแล้ว'),
      );
}
