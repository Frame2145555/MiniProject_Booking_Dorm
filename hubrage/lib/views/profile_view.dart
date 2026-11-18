import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import 'auth_view.dart';

class ProfileView extends StatefulWidget {
  final bool embedded;
  const ProfileView({super.key, this.embedded = false});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _saving = false;

  String _roleName(String role) => switch (role) {
    'seller' => 'เจ้าของหอพัก',
    'admin' => 'ผู้ดูแลระบบ',
    _ => 'ผู้เช่า',
  };

  Future<void> _editProfile() async {
    final nameParts = Session.fullName.trim().split(RegExp(r'\s+'));
    final firstName = TextEditingController(
      text: nameParts.isEmpty ? '' : nameParts.first,
    );
    final lastName = TextEditingController(
      text: nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
    );
    final email = TextEditingController(text: Session.email);
    final phone = TextEditingController(text: Session.phone);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('แก้ไขโปรไฟล์'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: firstName, decoration: const InputDecoration(labelText: 'ชื่อ'),
                validator: (value) => value == null || value.trim().isEmpty ? 'กรุณากรอกชื่อ' : null),
              TextFormField(controller: lastName, decoration: const InputDecoration(labelText: 'นามสกุล'),
                validator: (value) => value == null || value.trim().isEmpty ? 'กรุณากรอกนามสกุล' : null),
              TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'อีเมล'),
                validator: (value) => value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? 'กรุณากรอกอีเมลให้ถูกต้อง' : null),
              TextFormField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
          }, child: const Text('บันทึก')),
        ],
      ),
    );
    if (result != true || !mounted) {
      firstName.dispose();
      lastName.dispose();
      email.dispose();
      phone.dispose();
      return;
    }
    setState(() => _saving = true);
    final error = await AuthService.updateProfile(
      fullName: '${firstName.text.trim()} ${lastName.text.trim()}',
      email: email.text,
      phone: phone.text,
    );
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'บันทึกโปรไฟล์แล้ว')));
  }

  Widget _profile() => ValueListenableBuilder<bool>(
    valueListenable: Session.loggedIn,
    builder: (context, _, __) {
      if (!Session.isLoggedIn) return const AuthView(embedded: true);
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 10),
        Center(child: ChatAvatar(name: Session.fullName, size: 92)),
        const SizedBox(height: 14),
        Center(child: Text(Session.fullName, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink))),
        const SizedBox(height: 6),
        Center(child: Text(_roleName(Session.role), style: const TextStyle(color: AppColors.muted))),
        const SizedBox(height: 28),
        _infoTile(Icons.email_outlined, 'อีเมล', Session.email),
        _infoTile(Icons.phone_outlined, 'เบอร์โทรศัพท์', Session.phone.isEmpty ? 'ยังไม่ได้ระบุ' : Session.phone),
        if (Session.role == 'seller' && Session.verifiedOwner)
          _infoTile(Icons.verified_outlined, 'สถานะ', 'ยืนยันเจ้าของหอแล้ว'),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _saving ? null : _editProfile,
          icon: const Icon(Icons.edit_outlined), label: Text(_saving ? 'กำลังบันทึก...' : 'แก้ไขโปรไฟล์')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () {
          AuthService.logout();
          setState(() {});
        }, icon: const Icon(Icons.logout_rounded), label: const Text('ออกจากระบบ'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger)),
      ]);
    },
  );

  Widget _infoTile(IconData icon, String label, String value) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(leading: Icon(icon, color: AppColors.ink), title: Text(label),
      subtitle: Text(value.isEmpty ? 'ยังไม่ได้ระบุ' : value)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: widget.embedded ? null : AppBar(title: const Text('โปรไฟล์')),
    body: SafeArea(child: _profile()),
  );
}
