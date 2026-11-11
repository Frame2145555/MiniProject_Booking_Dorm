import 'package:flutter/material.dart';

import '../models/dorm_catalog.dart';
import '../services/session.dart';
import '../services/tenant_api_service.dart';
import '../theme/app_theme.dart';
import 'auth_view.dart';

/// การจองห้อง + นัดดูห้องของผู้เช่าที่ login อยู่ (GET /api/tenant/bookings/my-bookings)
class MyBookingsView extends StatefulWidget {
  const MyBookingsView({super.key});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView> {
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _visits = [];
  bool _loading = false;
  String? _error;

  static const _statusLabel = {
    'pending': 'รอเจ้าของหอตอบรับ',
    'confirmed': 'ยืนยันแล้ว',
    'accepted': 'ตอบรับแล้ว',
    'declined': 'ถูกปฏิเสธ',
    'cancelled': 'ยกเลิกแล้ว',
    'completed': 'เสร็จสิ้น',
  };

  @override
  void initState() {
    super.initState();
    Session.loggedIn.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Session.loggedIn.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!Session.isLoggedIn) {
      setState(() {
        _bookings = [];
        _visits = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await TenantApiService.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = data['bookings']!;
        _visits = data['visitRequests']!;
      });
    } on TenantApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> booking) async {
    final id = int.tryParse('${booking['bookingId']}');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยกเลิกคำขอจอง?'),
        content: Text('${booking['dormName']} ห้อง ${booking['roomNumber']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไม่')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('ยกเลิกการจอง')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TenantApiService.cancelBooking(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกคำขอจองแล้ว')),
        );
      }
    } on TenantApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    _load();
  }

  /// '2026-11-20T07:00:00.000Z' -> '20/11/2026 14:00' (เวลาเครื่อง)
  static String _date(Object? raw) {
    final t = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (t == null) return raw?.toString() ?? '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('การจองและนัดดูห้องของฉัน')),
      body: !Session.isLoggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('กรุณาเข้าสู่ระบบเพื่อดูการจองของคุณ'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthView()),
                    ),
                    child: const Text('เข้าสู่ระบบ'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_loading && _bookings.isEmpty && _visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    AppCard(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off_outlined),
                        title: Text(_error!),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _load,
                        ),
                      ),
                    ),
                  _header('คำขอจองห้อง', _bookings.length),
                  if (_bookings.isEmpty && !_loading)
                    _empty('ยังไม่มีคำขอจอง — เลือกห้องที่ว่างในหน้ารายละเอียดหอแล้วกด "จอง"'),
                  ..._bookings.map((b) {
                    final status = b['status']?.toString() ?? '';
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: Text('${b['dormName']} • ห้อง ${b['roomNumber']}'),
                        subtitle: Text(
                          '${DormCatalog.money(b['monthlyPrice'])} บาท/เดือน\n'
                          '${_statusLabel[status] ?? status}',
                        ),
                        isThreeLine: true,
                        trailing: status == 'pending'
                            ? TextButton(
                                onPressed: () => _cancel(b),
                                child: const Text('ยกเลิก'),
                              )
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  _header('นัดดูห้อง', _visits.length),
                  if (_visits.isEmpty && !_loading)
                    _empty('ยังไม่มีนัดดูห้อง — กด "นัดเข้าดูห้องพัก" ในหน้ารายละเอียดหอ'),
                  ..._visits.map((v) {
                    final status = v['status']?.toString() ?? '';
                    final note = v['ownerNote']?.toString() ?? '';
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text('${v['dormName']}'),
                        subtitle: Text(
                          '${_date(v['requestedAt'])} • ${_statusLabel[status] ?? status}'
                          '${note.isEmpty ? '' : '\nเจ้าของหอ: $note'}',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _header(String text, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '$text ($count)',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      );
}
