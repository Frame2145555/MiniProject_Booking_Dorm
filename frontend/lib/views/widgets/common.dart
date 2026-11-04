import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFF4F46E5);
const Color kBorder = Color(0xFFE2E8F0);
const Color kMuted = Color(0xFF64748B);
const Color kInk = Color(0xFF0F172A);

/// กล่องสีขาวขอบมน ใช้ห่อเนื้อหาแต่ละส่วน
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

/// ป้ายสถานะเล็กๆ เช่น CONFIRMED / PAID
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

StatusChip bookingStatusChip(String status) {
  switch (status) {
    case 'reserved':
      return const StatusChip(
          label: 'CONFIRMED',
          background: Color(0xFFD1FAE5),
          foreground: Color(0xFF065F46));
    case 'pending':
      return const StatusChip(
          label: 'PENDING PAYMENT',
          background: Color(0xFFFEF3C7),
          foreground: Color(0xFF92400E));
    case 'checked_in':
      return const StatusChip(
          label: 'CHECKED IN',
          background: Color(0xFFDBEAFE),
          foreground: Color(0xFF1E40AF));
    case 'completed':
      return const StatusChip(
          label: 'COMPLETED',
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155));
    case 'cancelled':
      return const StatusChip(
          label: 'CANCELLED',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFF991B1B));
    default:
      return StatusChip(
          label: status.toUpperCase(),
          background: const Color(0xFFE2E8F0),
          foreground: const Color(0xFF334155));
  }
}

StatusChip paymentStatusChip(String status) {
  switch (status) {
    case 'paid':
      return const StatusChip(
          label: 'PAID',
          background: Color(0xFFD1FAE5),
          foreground: Color(0xFF065F46));
    case 'pending':
      return const StatusChip(
          label: 'PENDING',
          background: Color(0xFFFEF3C7),
          foreground: Color(0xFF92400E));
    case 'refunded':
      return const StatusChip(
          label: 'REFUNDED',
          background: Color(0xFFDBEAFE),
          foreground: Color(0xFF1E40AF));
    case 'failed':
      return const StatusChip(
          label: 'FAILED',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFF991B1B));
    default:
      return StatusChip(
          label: status.toUpperCase(),
          background: const Color(0xFFE2E8F0),
          foreground: const Color(0xFF334155));
  }
}

String formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String formatMoney(double value) => '\$${value.toStringAsFixed(2)}';
