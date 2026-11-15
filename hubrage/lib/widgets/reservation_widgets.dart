import 'package:flutter/material.dart';

import '../models/booking_models.dart';
import '../theme/app_theme.dart';

/// ป้ายสถานะการจอง (สีตามสถานะ)
class ReservationStatusPill extends StatelessWidget {
  const ReservationStatusPill(this.status, {super.key});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusPill(status.shortLabel, color: status.color, background: status.background);
}

/// แถว "หัวข้อ : ค่า" ในการ์ด
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? AppColors.ink,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ขั้นตอนการจอง 4 ขั้น: จองห้อง -> ชำระเงิน -> แอดมินตรวจสอบ -> เจ้าของหอยืนยัน
class ReservationSteps extends StatelessWidget {
  const ReservationSteps(this.status, {super.key});

  final ReservationStatus status;

  static const _labels = ['จองห้อง', 'ชำระเงิน', 'แอดมินตรวจ', 'เจ้าของยืนยัน'];

  @override
  Widget build(BuildContext context) {
    // step = ขั้นล่าสุดที่ "กำลังรอ" -> ขั้นก่อนหน้านั้นทำเสร็จแล้ว (completed = เสร็จครบ 4 ขั้น)
    final current = status == ReservationStatus.completed ? 4 : status.step;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: current < 0
                      ? AppColors.field
                      : i < current
                          ? AppColors.success
                          : i == current
                              ? AppColors.accent
                              : AppColors.field,
                  child: i < current && current >= 0
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: i == current ? Colors.white : AppColors.muted,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= current ? AppColors.ink : AppColors.muted,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (i < _labels.length - 1)
            Container(
              width: 14,
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: i < current ? AppColors.success : AppColors.line,
            ),
        ],
      ],
    );
  }
}

/// การ์ดการจอง 1 รายการ (ใช้ทั้งหน้าผู้เช่า / แอดมิน / เจ้าของหอ)
/// [showTenant] = แสดงข้อมูลผู้เช่า (แอดมิน/เจ้าของหอ), [showPayment] = แสดงยอดที่ได้รับ + ตรงไหม (แอดมิน)
class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    this.showTenant = false,
    this.showPayment = false,
    this.actions = const [],
    this.onTap,
  });

  final Reservation reservation;
  final bool showTenant;
  final bool showPayment;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final matches = r.amountMatches;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.dormName} • ห้อง ${r.roomNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  ReservationStatusPill(r.status),
                ],
              ),
              const SizedBox(height: 6),
              if (showTenant)
                InfoRow('ผู้เช่า', '${r.tenantName}${r.tenantPhone == null ? '' : ' • ${r.tenantPhone}'}'),
              InfoRow('ระยะเวลา', '${r.planLabel} (${r.stayText})'),
              InfoRow('ยอดที่ต้องชำระ', r.amountText, bold: true),
              if (showPayment && r.paidAmount != null) ...[
                InfoRow(
                  'ยอดที่ได้รับ',
                  '${formatBaht(r.paidAmount!)} บาท ${matches == true ? '✓ ตรงกัน' : '✗ ไม่ตรง'}',
                  valueColor: matches == true ? AppColors.success : AppColors.danger,
                  bold: true,
                ),
                if (r.paymentRef != null) InfoRow('เลขอ้างอิง', r.paymentRef!),
                if (r.paidAt != null) InfoRow('ชำระเมื่อ', _time(r.paidAt!)),
              ],
              if ((r.ownerNote ?? r.adminNote) != null)
                InfoRow('หมายเหตุ', (r.ownerNote ?? r.adminNote)!),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// กล่องถามเหตุผล (ตอนกดไม่อนุมัติ/ปฏิเสธ) -> null = กดยกเลิก
Future<String?> askReason(BuildContext context, {required String title, String hint = 'เหตุผล (ไม่บังคับ)'}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: 200,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('ยืนยัน')),
      ],
    ),
  );
}
