import 'package:flutter/material.dart';

import '../services/admin_api_service.dart';
import '../theme/app_theme.dart';

/// Admin user management. User records are loaded from the authenticated API.
class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  late Future<List<Map<String, dynamic>>> _future;
  String _role = 'all';

  @override
  void initState() {
    super.initState();
    _future = AdminApiService.getUsers();
  }

  void _reload() => setState(() => _future = AdminApiService.getUsers());

  Future<void> _setStatus(Map<String, dynamic> user) async {
    final suspended = user['status'] == 'suspended';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspended ? 'คืนสถานะบัญชี' : 'ระงับบัญชี'),
        content: Text(suspended
            ? 'เปิดใช้งานบัญชี ${user['name']} อีกครั้งหรือไม่?'
            : 'ระงับบัญชี ${user['name']} หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminApiService.setUserSuspended(
        int.parse('${user['id']}'), !suspended,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(suspended ? 'เปิดใช้งานบัญชีแล้ว' : 'ระงับบัญชีแล้ว')),
      );
      _reload();
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะบัญชีได้')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return _message('โหลดข้อมูลผู้ใช้ไม่สำเร็จ\n${snapshot.error}', retry: _reload);
      }
      final all = snapshot.data ?? [];
      final users = all.where((u) => _role == 'all' || u['role'] == _role).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('จัดการผู้ใช้งาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'โหลดใหม่'),
        ]),
        Text('ผู้ใช้งานทั้งหมด ${all.length} บัญชี', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _filter('ทั้งหมด', 'all'), _filter('ผู้เช่า', 'tenant'), _filter('เจ้าของหอ', 'seller'),
        ]),
        const SizedBox(height: 12),
        if (users.isEmpty) _message('ไม่พบผู้ใช้งาน'),
        ...users.map((u) {
          final suspended = u['status'] == 'suspended';
          final role = u['role'] == 'seller' ? 'เจ้าของหอพัก' : 'ผู้เช่า';
          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.field, child: Icon(u['role'] == 'seller' ? Icons.store_outlined : Icons.person_outline)),
              title: Text('${u['name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${u['email'] ?? '-'}\n${u['phone'] ?? '-'} • $role\nสถานะ: ${suspended ? 'ถูกระงับ' : 'ใช้งาน'}')),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (_) => _setStatus(u),
                itemBuilder: (_) => [PopupMenuItem(value: 'status', child: Text(suspended ? 'คืนสถานะ' : 'ระงับบัญชี'))],
              ),
            ),
          );
        }),
      ]);
    },
  );

  Widget _filter(String label, String value) => ChoiceChip(
    label: Text(label), selected: _role == value,
    onSelected: (_) => setState(() => _role = value),
  );

  Widget _message(String text, {VoidCallback? retry}) => AppCard(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const Icon(Icons.info_outline, size: 34, color: AppColors.muted),
      const SizedBox(height: 8), Text(text, textAlign: TextAlign.center),
      if (retry != null) TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('ลองอีกครั้ง')),
    ]),
  );
}
