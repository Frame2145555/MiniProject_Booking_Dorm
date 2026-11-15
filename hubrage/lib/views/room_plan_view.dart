import 'package:flutter/material.dart';

import '../Logic/Frame_Booking.dart';
import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'auth_view.dart';
import 'payment_view.dart';

/// ผังห้อง 2D ของหอ: เลือกห้องว่าง (สีเขียว) + เลือกระยะเวลาเช่า -> จองห้อง -> หน้าชำระเงิน
/// สี: เขียว = ว่าง, เทา = มีผู้เช่า, ฟ้า = ติดจอง, แดง = ปรับปรุง
class RoomPlanView extends StatefulWidget {
  const RoomPlanView({
    super.key,
    required this.dormId,
    this.dormName,
    this.initialRoomId,
    this.service,
  });

  final int dormId;
  final String? dormName;

  /// เลือกห้องนี้ไว้ให้ก่อน (มาจากปุ่ม "จอง" ในหน้ารายละเอียดหอ)
  final int? initialRoomId;
  final BookingService? service;

  @override
  State<RoomPlanView> createState() => _RoomPlanViewState();
}

class _RoomPlanViewState extends State<RoomPlanView> {
  late final RoomPlanController _controller = RoomPlanController(
    widget.dormId,
    service: widget.service,
    initialRoomId: widget.initialRoomId,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onRoomTap(PlanRoom room) {
    if (room.isMine) {
      _openPayment(room.myReservationId!);
      return;
    }
    if (!room.canBook) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('ห้อง ${room.number} ${room.state.label} จองไม่ได้')));
      return;
    }
    _controller.selectRoom(room);
  }

  Future<void> _openPayment(int reservationId, {Reservation? initial}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentView(
          reservationId: reservationId,
          initial: initial,
          service: widget.service,
        ),
      ),
    );
    if (mounted) _controller.load();
  }

  Future<void> _reserve() async {
    final room = _controller.selectedRoom;
    final plan = _controller.selectedRentPlan;
    if (room == null || plan == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยืนยันการจองห้อง'),
        content: Text(
          'ห้อง ${room.number} • ${room.type} • ชั้น ${room.floor}\n'
          'ระยะเวลา ${plan.label}\n'
          'ยอดชำระ ${formatBaht(plan.price)} บาท\n\n'
          'กดจองแล้วต้องชำระเงินภายใน ${_controller.plan?.holdMinutes ?? 30} นาที '
          'ไม่อย่างนั้นห้องจะถูกปล่อยให้คนอื่นจอง',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('จองและไปชำระเงิน')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final reservation = await _controller.reserve();
    if (!mounted) return;
    if (reservation != null) {
      await _openPayment(reservation.id, initial: reservation);
    } else if (!Session.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final plan = _controller.plan;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Text('ผังห้อง • ${plan?.dormName ?? widget.dormName ?? ''}'),
            actions: [
              IconButton(
                tooltip: 'โหลดใหม่',
                icon: const Icon(Icons.refresh),
                onPressed: _controller.load,
              ),
            ],
          ),
          body: _body(plan),
          bottomNavigationBar: plan == null ? null : _bookingBar(),
        );
      },
    );
  }

  Widget _body(DormRoomPlan? plan) {
    if (_controller.loading) return const Center(child: CircularProgressIndicator());
    if (plan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_controller.error ?? 'โหลดผังห้องไม่สำเร็จ', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _legend(plan),
          const SizedBox(height: 18),
          const Text('ระยะเวลาเช่า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (plan.plans.isEmpty)
            const Text(
              'หอนี้ยังไม่ได้ตั้งราคาเช่า — ติดต่อเจ้าของหอผ่านแชท',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.plans.map((p) {
                final selected = _controller.selectedPlan == p.plan;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => _controller.selectPlan(p.plan),
                  label: Text('${p.label}\n${formatBaht(p.price)} บาท', textAlign: TextAlign.center),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                  selectedColor: AppColors.ink,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          const Text('เลือกห้อง (แตะห้องสีเขียว)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final floor in plan.floors) _floorRow(floor),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
                  ),
                  child: const Center(
                    child: Text('ทางเข้าอาคาร', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(DormRoomPlan plan) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RoomState.values.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: s.background, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 14, color: s.color),
              const SizedBox(width: 4),
              Text(
                '${s.label} ${plan.count(s)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _floorRow(FloorPlan floor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                'F${floor.floor}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: floor.rooms.map(_roomTile).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomTile(PlanRoom room) {
    final selected = _controller.selectedRoomId == room.id;
    final s = room.state;
    return Semantics(
      button: true,
      label: 'ห้อง ${room.number} ${s.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onRoomTap(room),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 68,
          height: 62,
          decoration: BoxDecoration(
            color: selected ? s.color : s.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.ink : s.color.withOpacity(0.45),
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.number,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(s.icon, size: 16, color: selected ? Colors.white : s.color),
                  ],
                ),
              ),
              if (room.isMine)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.info, borderRadius: BorderRadius.circular(6)),
                    child: const Text('ของฉัน', style: TextStyle(fontSize: 8, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingBar() {
    final room = _controller.selectedRoom;
    final plan = _controller.selectedRentPlan;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              room == null
                  ? 'ยังไม่ได้เลือกห้อง'
                  : 'ห้อง ${room.number} • ${room.type} • ชั้น ${room.floor}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (plan != null)
              Text(
                '${plan.label} • ${formatBaht(plan.price)} บาท',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            if (_controller.actionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _controller.actionError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _controller.canReserve ? _reserve : null,
              child: _controller.reserving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('จองห้อง'),
            ),
          ],
        ),
      ),
    );
  }
}
