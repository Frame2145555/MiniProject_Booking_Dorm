import 'package:flutter/material.dart';

import '../Logic/Frame_Booking.dart';
import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/reservation_widgets.dart';

/// แอดมินตรวจการชำระเงินค่าจองห้อง: ดูยอดที่ต้องจ่าย vs ยอดที่ได้รับ -> อนุมัติ / ไม่อนุมัติ
/// อนุมัติแล้ว ระบบส่งแจ้งเตือนเข้าแชทของเจ้าของหอให้เอง
class AdminPaymentsView extends StatefulWidget {
  const AdminPaymentsView({super.key, this.service});

  final BookingService? service;

  @override
  State<AdminPaymentsView> createState() => _AdminPaymentsViewState();
}

class _AdminPaymentsViewState extends State<AdminPaymentsView> {
  late final ReservationListController _controller =
      ReservationListController(ReservationViewer.admin, service: widget.service);

  static const _filters = {
    'paid': 'รอตรวจสอบ',
    'approved': 'อนุมัติแล้ว',
    'rejected': 'ไม่อนุมัติ',
    'all': 'ทั้งหมด',
  };

  bool get _isAdmin => Session.isLoggedIn && Session.role == 'admin';

  @override
  void initState() {
    super.initState();
    if (_isAdmin) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _review(Reservation r, bool approve) async {
    String? note;
    if (approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('อนุมัติการชำระเงิน?'),
          content: Text(
            '${r.tenantName} ชำระ ${formatBaht(r.paidAmount ?? 0)} บาท\n'
            'ยอดที่ต้องชำระ ${r.amountText}\n\n'
            'ระบบจะแจ้งเตือนเจ้าของหอในแชทให้ยืนยันการจอง',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('อนุมัติ')),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      note = await askReason(context, title: 'ไม่อนุมัติการชำระเงิน', hint: 'เช่น ยอดเงินไม่ตรง');
      if (note == null) return;
    }
    final err = await _controller.adminReview(r, approve: approve, note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? (approve ? 'อนุมัติแล้ว แจ้งเตือนเจ้าของหอในแชทแล้ว' : 'ไม่อนุมัติ การจองถูกยกเลิก')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('ตรวจสอบการชำระเงิน')),
      body: !_isAdmin
          ? const Center(child: Text('เข้าสู่ระบบด้วยบัญชีแอดมิน (admin@test.com) เพื่อตรวจการชำระเงิน'))
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => RefreshIndicator(
                onRefresh: _controller.load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: _filters.entries.map((f) {
                        return ChoiceChip(
                          label: Text(f.value),
                          selected: _controller.status == f.key,
                          onSelected: (_) => _controller.setStatus(f.key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    if (_controller.loading) const LinearProgressIndicator(),
                    if (_controller.error != null)
                      Text(_controller.error!, style: const TextStyle(color: AppColors.danger)),
                    if (!_controller.loading && _controller.items.isEmpty && _controller.error == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: Text('ไม่มีรายการ', style: TextStyle(color: AppColors.muted))),
                      ),
                    for (final r in _controller.items)
                      ReservationCard(
                        reservation: r,
                        showTenant: true,
                        showPayment: true,
                        actions: r.status != ReservationStatus.paid
                            ? const []
                            : _controller.busy.contains(r.id)
                                ? const [CircularProgressIndicator()]
                                : [
                                    TextButton(
                                      onPressed: () => _review(r, false),
                                      child: const Text('ไม่อนุมัติ', style: TextStyle(color: AppColors.danger)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(onPressed: () => _review(r, true), child: const Text('อนุมัติ')),
                                  ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
