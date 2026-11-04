import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import 'widgets/booking_card.dart';
import 'widgets/common.dart';
import 'widgets/payment_history.dart';

/// View: หน้า Student Housing Dashboard (My Bookings)
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'DormSpace',
          style: TextStyle(fontWeight: FontWeight.w800, color: kPrimary),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('Alex Morgan')),
          ),
        ],
      ),
      // ListenableBuilder วาดหน้าจอใหม่ทุกครั้งที่ controller แจ้งว่าข้อมูลเปลี่ยน
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              if (_controller.bookings.isEmpty)
                const SectionCard(
                  child: Text(
                    'You have no bookings yet.',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              for (final b in _controller.bookings) ...[
                BookingCard(
                  booking: b,
                  roommates: _controller.roommatesOf(b.id),
                ),
                const SizedBox(height: 20),
              ],
              PaymentHistory(
                payments: _controller.payments,
                totalPaid: _controller.totalPaid,
                totalRefunded: _controller.totalRefunded,
                totalPending: _controller.totalPending,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Housing Dashboard',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage active reservations, review roommate matches, and track move-in schedules.',
              style: TextStyle(color: kMuted),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking flow: coming soon')),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Book Additional Room'),
        ),
      ],
    );
  }
}
