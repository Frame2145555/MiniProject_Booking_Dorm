import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/owner_api_service.dart';
import '../theme/app_theme.dart';

class OwnerKycView extends StatefulWidget {
  const OwnerKycView({super.key});
  @override
  State<OwnerKycView> createState() => _OwnerKycViewState();
}

class _OwnerKycViewState extends State<OwnerKycView> {
  final fullName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final idCard = TextEditingController();
  String? idImage, selfieImage;
  bool saving = false;

  @override
  void dispose() {
    fullName.dispose();
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

  Future<void> submit() async {
    if (idCard.text.replaceAll(RegExp(r'[- ]'), '').length != 13 ||
        idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกเลขบัตร 13 หลักและอัปโหลดรูปบัตร'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await OwnerApiService.submitKyc(
        fullName: fullName.text,
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
        TextField(
          controller: fullName,
          decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์ *'),
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
