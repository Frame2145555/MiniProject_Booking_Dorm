import 'dart:async';

import 'package:flutter/material.dart';

import '../Logic/Frame_Booking.dart';
import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mock_qr_code.dart';
import '../widgets/reservation_widgets.dart';

/// หน้าชำระเงิน (mock up) + ติดตามสถานะการจอง
///   รอชำระเงิน      -> QR ปลอม + ยอดที่ระบบล็อกไว้ + เวลาที่เหลือ + ปุ่ม "จ่ายเงิน"
///   จ่ายแล้วขึ้นไป   -> ขั้นตอน 4 ขั้น + เลขอ้างอิง + ขั้นต่อไปคืออะไร
class PaymentView extends StatefulWidget {
  const PaymentView({super.key, required this.reservationId, this.initial, this.service});

  final int reservationId;
  final Reservation? initial;
  final BookingService? service;

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  late final PaymentController _controller =
      PaymentController(widget.reservationId, initial: widget.initial, service: widget.service);
  Timer? _ticker;
  bool _reloadedAfterExpiry = false;

  @override
  void initState() {
    super.initState();
    _controller.load();
    // นับถอยหลังเวลาที่เหลือให้จ่ายเงิน
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = _controller.reservation;
      if (!mounted || r?.status != ReservationStatus.awaitingPayment) return;
      if (r!.timeLeft() == Duration.zero) {
        if (!_reloadedAfterExpiry) {
          _reloadedAfterExpiry = true;
          _controller.load(); // หมดเวลา -> ให้ server เปลี่ยนเป็น "หมดเวลาชำระเงิน"
        }
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pay() async {
    final r = _controller.reservation!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยืนยันการชำระเงิน'),
        content: Text('ชำระ ${r.amountText}\nให้ Dorm Master (แอดมิน)\n\n(จำลองการสแกน QR และโอนเงิน)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('จ่ายเงิน')),
        ],
      ),
    );
    if (ok != true) return;
    final paid = await _controller.pay();
    if (!mounted) return;
    _show(paid ? 'ชำระเงินแล้ว รอแอดมินตรวจสอบ' : (_controller.error ?? 'ชำระเงินไม่สำเร็จ'));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยกเลิกการจอง?'),
        content: const Text('ห้องจะถูกปล่อยให้คนอื่นจองได้ทันที'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไม่')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('ยกเลิกการจอง')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _controller.cancel();
    if (mounted) _show(done ? 'ยกเลิกการจองแล้ว' : (_controller.error ?? 'ยกเลิกไม่สำเร็จ'));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final r = _controller.reservation;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Text(r?.status == ReservationStatus.awaitingPayment ? 'ชำระเงิน' : 'สถานะการจอง'),
            actions: [
              IconButton(tooltip: 'อัปเดตสถานะ', icon: const Icon(Icons.refresh), onPressed: _controller.load),
            ],
          ),
          body: r == null
              ? Center(
                  child: _controller.loading
                      ? const CircularProgressIndicator()
                      : Text(_controller.error ?? 'ไม่พบการจองนี้'),
                )
              : RefreshIndicator(
                  onRefresh: _controller.load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: ReservationSteps(r.status),
                      ),
                      _summary(r),
                      if (r.status == ReservationStatus.awaitingPayment) _payBox(r) else _afterPayBox(r),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _summary(Reservation r) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.dormName} • ห้อง ${r.roomNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              ReservationStatusPill(r.status),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow('ห้อง', '${r.roomType} • ชั้น ${r.floor}'),
          InfoRow('ระยะเวลาเช่า', r.planLabel),
          InfoRow('วันเข้าพัก', r.stayText),
          InfoRow('ยอดชำระ', r.amountText, bold: true),
        ],
      ),
    );
  }

  Widget _payBox(Reservation r) {
    final left = r.timeLeft();
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF113566), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'PromptPay (จำลอง)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          MockQrCode(data: 'DM-${r.id}-${r.amount}'),
          const SizedBox(height: 12),
          const Text('ชำระให้: Dorm Master (แอดมิน)', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            r.amountText,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const Text(
            'ยอดเงินถูกกำหนดตามราคาที่เจ้าของหอตั้ง แก้ไขไม่ได้',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          StatusPill(
            'เหลือเวลาชำระ $mm:$ss',
            icon: Icons.timer_outlined,
            color: left.inMinutes < 5 ? AppColors.danger : AppColors.warning,
            background: left.inMinutes < 5 ? AppColors.dangerSoft : AppColors.warningSoft,
          ),
          if (_controller.error != null) ...[
            const SizedBox(height: 8),
            Text(_controller.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _controller.canPay ? _pay : null,
              icon: _controller.paying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.qr_code_scanner),
              label: Text('จ่ายเงิน ${r.amountText}'),
            ),
          ),
          TextButton(
            onPressed: _controller.canCancel ? _cancel : null,
            child: const Text('ยกเลิกการจอง'),
          ),
        ],
      ),
    );
  }

  Widget _afterPayBox(Reservation r) {
    final next = switch (r.status) {
      ReservationStatus.paid =>
        'แอดมินกำลังตรวจสอบยอดเงิน เมื่ออนุมัติแล้วเจ้าของหอจะได้รับแจ้งเตือนในแชท',
      ReservationStatus.approved =>
        'แอดมินตรวจสอบเงินแล้ว รอเจ้าของหอยืนยัน — จะมีแจ้งเตือนในแชทเมื่อยืนยันแล้ว',
      ReservationStatus.completed => 'การจองเสร็จสมบูรณ์ เข้าพักได้ตามวันที่กำหนด',
      ReservationStatus.rejected => 'แอดมินไม่อนุมัติการชำระเงิน การจองถูกยกเลิก',
      ReservationStatus.ownerRejected => 'เจ้าของหอปฏิเสธการจอง แอดมินจะคืนเงินให้',
      ReservationStatus.expired => 'ไม่ได้ชำระเงินภายในเวลาที่กำหนด ห้องถูกปล่อยให้คนอื่นจองแล้ว',
      _ => 'ยกเลิกการจองแล้ว',
    };
    final note = r.ownerNote ?? r.adminNote;
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: r.status.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.statusLabel, style: TextStyle(fontWeight: FontWeight.w800, color: r.status.color)),
          const SizedBox(height: 6),
          Text(next, style: const TextStyle(fontSize: 13)),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('หมายเหตุ: $note', style: const TextStyle(fontSize: 13)),
          ],
          if (r.paymentRef != null) ...[
            const Divider(height: 20),
            InfoRow('เลขอ้างอิง', r.paymentRef!),
            InfoRow('ยอดที่ชำระ', '${formatBaht(r.paidAmount ?? 0)} บาท'),
          ],
        ],
      ),
    );
  }
}
