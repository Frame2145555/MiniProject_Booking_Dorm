import 'package:flutter/material.dart';

import '../Logic/Frame_Booking.dart';
import '../services/booking_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/reservation_widgets.dart';
import 'auth_view.dart';
import 'payment_view.dart';

/// การจองห้อง (แบบชำระเงิน) ของผู้เช่า — แตะรายการเพื่อจ่ายเงิน / ดูสถานะ
class MyReservationsView extends StatefulWidget {
  const MyReservationsView({super.key, this.service});

  final BookingService? service;

  @override
  State<MyReservationsView> createState() => _MyReservationsViewState();
}

class _MyReservationsViewState extends State<MyReservationsView> {
  late final ReservationListController _controller =
      ReservationListController(ReservationViewer.tenant, service: widget.service);

  @override
  void initState() {
    super.initState();
    if (Session.isLoggedIn) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('การจองห้องของฉัน')),
      body: !Session.isLoggedIn
          ? Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthView())),
                child: const Text('เข้าสู่ระบบเพื่อดูการจอง'),
              ),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.loading && _controller.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  onRefresh: _controller.load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_controller.error != null)
                        Text(_controller.error!, style: const TextStyle(color: AppColors.danger)),
                      if (_controller.items.isEmpty && _controller.error == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              'ยังไม่มีการจอง\nเลือกห้องจากผังห้องในหน้ารายละเอียดหอ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ),
                      for (final r in _controller.items)
                        ReservationCard(
                          reservation: r,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentView(reservationId: r.id, initial: r, service: widget.service),
                              ),
                            );
                            _controller.load();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
