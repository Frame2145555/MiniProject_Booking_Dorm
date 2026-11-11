import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';

class AuthView extends StatefulWidget {
  /// true = แสดงเป็นแท็บใน NavigationShell (ไม่มี AppBar ของตัวเอง ใช้แถบบนร่วมกัน)
  /// false = เปิดจากปุ่มบัญชีขวาบน (มี AppBar + ปุ่มย้อนกลับ)
  final bool embedded;

  const AuthView({super.key, this.embedded = false});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  // ฟอร์มสมัครสมาชิก
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _regRole = 'tenant'; // 'tenant' | 'seller'
  bool _registering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }
    setState(() => _loading = true);
    final error = await AuthService.login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _toast(error);
      return;
    }
    _passwordController.clear();
    _toast('เข้าสู่ระบบสำเร็จ');
    // เปิดมาจากปุ่มบัญชี / ปุ่ม "ไปหน้าเข้าสู่ระบบ" -> กลับไปหน้าเดิม
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _logout() {
    AuthService.logout();
    setState(() {});
    _toast('ออกจากระบบแล้ว');
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'seller':
        return 'เจ้าของหอ';
      case 'admin':
        return 'แอดมิน';
      default:
        return 'ผู้เช่า';
    }
  }

  InputDecoration _decoration(String label, {IconData? icon}) =>
      AppInputs.field(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.muted),
      );

  Widget _primaryButton(String label, {VoidCallback? onPressed, bool loading = false}) =>
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      );

  /// แถบสลับ เข้าสู่ระบบ / สมัครสมาชิก
  Widget _tabPill() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.soft,
          ),
          child: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.dark,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.ink,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [Tab(text: 'เข้าสู่ระบบ'), Tab(text: 'สมัครสมาชิก')],
          ),
        ),
      );

  Widget _loginForm() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.soft,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 52,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration('อีเมล', icon: Icons.email_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _login(),
            decoration: _decoration('รหัสผ่าน (Password)', icon: Icons.lock_outline),
          ),
          const SizedBox(height: 24),
          _primaryButton('เข้าสู่ระบบ', onPressed: _login, loading: _loading),
        ],
      );

  Widget _loggedInCard() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChatAvatar(name: Session.fullName, size: 96),
          const SizedBox(height: 16),
          Text(
            Session.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          StatusPill(
            'เข้าสู่ระบบเป็น ${_roleLabel(Session.role)}',
            icon: Icons.verified_user_rounded,
            color: AppColors.success,
            background: AppColors.successSoft,
          ),
          const SizedBox(height: 6),
          Text(
            'user id ${Session.userId}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ออกจากระบบ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      );

  Future<void> _register(TabController? tabs) async {
    final fullName = [_firstNameController.text, _lastNameController.text]
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join(' ');
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _toast('กรุณากรอกชื่อ อีเมล และรหัสผ่าน');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      _toast('รูปแบบอีเมลไม่ถูกต้อง');
      return;
    }
    if (password.length < 8) {
      _toast('รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร');
      return;
    }
    setState(() => _registering = true);
    final error = await AuthService.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: _phoneController.text,
      role: _regRole,
    );
    if (!mounted) return;
    setState(() => _registering = false);
    if (error != null) {
      _toast(error);
      return;
    }
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _regEmailController.clear();
    _regPasswordController.clear();
    _toast('สมัครสมาชิกสำเร็จ');
    tabs?.animateTo(0); // กลับไปแท็บแรก (จะเห็นการ์ดผู้ใช้ที่ login แล้ว)
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _regRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _regRole = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected ? AppShadows.dark : AppShadows.chip,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registerForm() => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Builder(
            // Builder: เพื่อเข้าถึง TabController ของ DefaultTabController ที่อยู่ด้านบน
            builder: (tabContext) => Column(
              children: [
                Row(
                  children: [
                    _roleChip('tenant', 'ผู้เช่า', Icons.person_search_rounded),
                    const SizedBox(width: 10),
                    _roleChip('seller', 'เจ้าของหอ', Icons.storefront_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('ชื่อจริง (First Name)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('นามสกุล (Last Name)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('เบอร์โทรศัพท์ (Phone) — ไม่บังคับ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('อีเมล (E-mail)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regPasswordController,
                  obscureText: true,
                  onSubmitted: (_) =>
                      _register(DefaultTabController.maybeOf(tabContext)),
                  decoration: _decoration('รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)'),
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  'ยืนยันสมัครสมาชิก',
                  loading: _registering,
                  onPressed: () =>
                      _register(DefaultTabController.maybeOf(tabContext)),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _tabViews() => TabBarView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            // login/logout จากหน้าไหนก็ตาม -> แท็บนี้เปลี่ยนตามเอง
            child: ValueListenableBuilder<bool>(
              valueListenable: Session.loggedIn,
              builder: (context, _, __) =>
                  Session.isLoggedIn ? _loggedInCard() : _loginForm(),
            ),
          ),
          _registerForm(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'บัญชีผู้ใช้งาน',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              _tabPill(),
              Expanded(child: _tabViews()),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('บัญชีผู้ใช้งาน'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _tabPill(),
          ),
        ),
        body: _tabViews(),
      ),
    );
  }
}
