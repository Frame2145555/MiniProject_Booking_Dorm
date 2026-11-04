import 'package:flutter/material.dart';

import '../../models/payment.dart';
import 'common.dart';

/// ส่วนประวัติการชำระเงิน: การ์ดสรุปยอด 3 ใบ + รายการชำระเงินเรียงล่าสุดก่อน
class PaymentHistory extends StatelessWidget {
  const PaymentHistory({
    super.key,
    required this.payments,
    required this.totalPaid,
    required this.totalRefunded,
    required this.totalPending,
  });

  final List<Payment> payments;
  final double totalPaid;
  final double totalRefunded;
  final double totalPending;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Deposits and rent payments for your bookings',
            style: TextStyle(color: kMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryTile(
                label: 'Paid',
                amount: totalPaid,
                background: const Color(0xFFD1FAE5),
                foreground: const Color(0xFF065F46),
              ),
              _SummaryTile(
                label: 'Refunded',
                amount: totalRefunded,
                background: const Color(0xFFDBEAFE),
                foreground: const Color(0xFF1E40AF),
              ),
              _SummaryTile(
                label: 'Pending',
                amount: totalPending,
                background: const Color(0xFFFEF3C7),
                foreground: const Color(0xFF92400E),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No payments yet.', style: TextStyle(color: kMuted)),
            )
          else
            for (final p in payments) _PaymentRow(payment: p),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.background,
    required this.foreground,
  });

  final String label;
  final double amount;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount),
            style: TextStyle(
              color: foreground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final typeLabel = p.paymentType == 'deposit' ? 'Deposit' : 'Rent';
    final receiptLine =
        '${p.receiptNo ?? 'No receipt yet'} • ${p.referenceCode}';
    final paidAt = p.paidAt;
    final dateLine = paidAt != null
        ? 'Paid on ${formatDate(paidAt)} • Room ${p.roomNumber}, ${p.buildingName}'
        : 'Awaiting payment • Room ${p.roomNumber}, ${p.buildingName}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  receiptLine,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
                Text(
                  dateLine,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(p.amount),
                style: const TextStyle(
                  color: kInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              paymentStatusChip(p.status),
            ],
          ),
        ],
      ),
    );
  }
}
