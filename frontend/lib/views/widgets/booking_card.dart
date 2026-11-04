import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../models/roommate.dart';
import 'common.dart';

/// การ์ดการจอง 1 รายการ: หัวการ์ด + Lease Details + Matched Roommate + Quick Actions
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.roommates,
  });

  final Booking booking;
  final List<Roommate> roommates;

  @override
  Widget build(BuildContext context) {
    final isCancelled = booking.status == 'cancelled';

    // การจองที่ยกเลิกแล้ว แสดงเฉพาะรายละเอียดสัญญา
    final panels = <Widget>[
      _LeaseDetails(booking: booking),
      if (!isCancelled) _RoommatePanel(roommates: roommates),
      if (!isCancelled) const _QuickActions(),
    ];

    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(booking: booking, showCountdown: !isCancelled),
          const Divider(height: 32, color: kBorder),
          LayoutBuilder(
            builder: (context, constraints) {
              // จอกว้าง: วางเรียงข้างกัน / จอแคบ: วางซ้อนลงมา
              if (constraints.maxWidth >= 720) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < panels.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(child: panels[i]),
                      ],
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < panels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    panels[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking, required this.showCountdown});

  final Booking booking;
  final bool showCountdown;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            bookingStatusChip(booking.status),
            Text(
              'Ref ID: ${booking.referenceCode}',
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          booking.roomTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showCountdown) return info;
        final countdown = _Countdown(booking: booking);
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              countdown,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [info, const SizedBox(height: 12), countdown],
        );
      },
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final days = booking.daysUntilMoveIn;
    final dayText = days >= 0 ? '$days Days' : 'Already started';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Move-In Countdown',
            style: TextStyle(
              color: kPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDate(booking.moveInDate)} ($dayText)',
            style: const TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// กล่องย่อยสีเทาอ่อน มีหัวข้อตัวพิมพ์ใหญ่
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? kInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaseDetails extends StatelessWidget {
  const _LeaseDetails({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final depositPaid = booking.depositPaid > 0;
    return _Panel(
      title: 'LEASE DETAILS',
      child: Column(
        children: [
          _InfoRow(label: 'Term', value: booking.semesterName),
          _InfoRow(label: 'Room type', value: booking.roomType),
          _InfoRow(label: 'Lease', value: '${booking.leaseMonths} months'),
          _InfoRow(
            label: 'Monthly Rent',
            value: '${formatMoney(booking.monthlyRent)}/mo',
            valueColor: kPrimary,
          ),
          _InfoRow(
            label: 'Deposit Paid',
            value: depositPaid
                ? '${formatMoney(booking.depositPaid)} (Secured)'
                : 'Not paid',
            valueColor:
                depositPaid ? const Color(0xFF059669) : const Color(0xFFB45309),
          ),
          _InfoRow(
            label: 'Add-ons',
            value: booking.addons.isEmpty ? 'None' : booking.addons.join(', '),
          ),
        ],
      ),
    );
  }
}

class _RoommatePanel extends StatelessWidget {
  const _RoommatePanel({required this.roommates});

  final List<Roommate> roommates;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'MATCHED ROOMMATE',
      child: roommates.isEmpty
          ? const Text(
              'No roommate assigned yet.',
              style: TextStyle(color: kMuted, fontSize: 13),
            )
          : Column(
              children: [
                for (final r in roommates) _RoommateRow(roommate: r),
              ],
            ),
    );
  }
}

class _RoommateRow extends StatelessWidget {
  const _RoommateRow({required this.roommate});

  final Roommate roommate;

  @override
  Widget build(BuildContext context) {
    final subtitle = roommate.sameSleepHabit
        ? '${roommate.faculty} • Same Sleep Habits'
        : roommate.faculty;
    final percent = roommate.matchPercent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF7C3AED),
            child: Text(
              roommate.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roommate.fullName,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (percent != null) ...[
            const SizedBox(width: 8),
            StatusChip(
              label: '$percent% MATCH',
              background: const Color(0xFFD1FAE5),
              foreground: const Color(0xFF065F46),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label: coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'QUICK ACTIONS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => _comingSoon(context, 'Download Lease Agreement'),
            child: const Text('Download Lease Agreement'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _comingSoon(context, 'Request Move-in Assistance'),
            child: const Text('Request Move-in Assistance'),
          ),
        ],
      ),
    );
  }
}
