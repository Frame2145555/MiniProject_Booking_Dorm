import 'package:flutter/material.dart';

import '../Logic/Frame_Booking.dart';
import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/owner_api_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/reservation_widgets.dart';

/// เจ้าของหอ: คำขอจองที่ผู้เช่าจ่ายเงินแล้ว + แอดมินตรวจแล้ว -> ยืนยัน (ห้องเป็น "มีผู้เช่า") / ปฏิเสธ
/// + ปุ่มตั้งราคาเช่า (1 อาทิตย์ / 1 เดือน / 1 เทอม / 1 ปี)
class OwnerReservationsView extends StatefulWidget {
  const OwnerReservationsView({super.key, this.service});

  final BookingService? service;

  @override
  State<OwnerReservationsView> createState() => _OwnerReservationsViewState();
}

class _OwnerReservationsViewState extends State<OwnerReservationsView> {
  late final ReservationListController _controller =
      ReservationListController(ReservationViewer.owner, service: widget.service);

  static const _filters = {
    'approved': 'รอยืนยัน',
    'completed': 'จองสำเร็จ',
    'owner_rejected': 'ปฏิเสธแล้ว',
    'all': 'ทั้งหมด',
  };

  bool get _isOwner => Session.isLoggedIn && Session.role == 'seller';

  @override
  void initState() {
    super.initState();
    if (_isOwner) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decide(Reservation r, bool confirm) async {
    String? note;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('ยืนยันการจอง?'),
          content: Text(
            '${r.tenantName} • ห้อง ${r.roomNumber}\n${r.planLabel} (${r.stayText})\n\n'
            'ห้องจะเปลี่ยนเป็น "มีผู้เช่า" และผู้เช่าได้รับแจ้งเตือนในแชท',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('ยืนยันการจอง')),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      note = await askReason(context, title: 'ปฏิเสธการจอง', hint: 'เช่น ห้องต้องซ่อม');
      if (note == null) return;
    }
    final err = await _controller.ownerDecide(r, confirm: confirm, note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? (confirm ? 'จองสำเร็จ แจ้งเตือนผู้เช่าในแชทแล้ว' : 'ปฏิเสธแล้ว แอดมินจะคืนเงินผู้เช่า')),
    ));
  }

  Future<void> _openPlanSettings() async {
    List<Map<String, dynamic>> dorms;
    try {
      dorms = await OwnerApiService.getDorms();
    } on OwnerApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    if (dorms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่มีหอพัก')));
      return;
    }
    final dorm = dorms.length == 1
        ? dorms.first
        : await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (c) => SimpleDialog(
              title: const Text('เลือกหอที่จะตั้งราคา'),
              children: [
                for (final d in dorms)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, d),
                    child: Text(d['title']?.toString() ?? 'หอ ${d['id']}'),
                  ),
              ],
            ),
          );
    if (dorm == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerRentPlanView(
          dormId: int.parse('${dorm['id']}'),
          dormName: dorm['title']?.toString() ?? '',
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('คำขอจอง (ชำระเงินแล้ว)'),
        actions: [
          if (_isOwner)
            TextButton.icon(
              onPressed: _openPlanSettings,
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('ตั้งราคาเช่า'),
            ),
        ],
      ),
      body: !_isOwner
          ? const Center(child: Text('เข้าสู่ระบบด้วยบัญชีเจ้าของหอเพื่อดูคำขอจอง'))
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
                        child: Center(
                          child: Text(
                            'ไม่มีรายการ\n(คำขอจะมาที่นี่หลังแอดมินตรวจเงินแล้ว)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
                    for (final r in _controller.items)
                      ReservationCard(
                        reservation: r,
                        showTenant: true,
                        showDeposit: true,
                        actions: r.status != ReservationStatus.approved
                            ? const []
                            : _controller.busy.contains(r.id)
                                ? const [CircularProgressIndicator()]
                                : [
                                    TextButton(
                                      onPressed: () => _decide(r, false),
                                      child: const Text('ปฏิเสธ', style: TextStyle(color: AppColors.danger)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _decide(r, true),
                                      child: const Text('ยืนยันการจอง'),
                                    ),
                                  ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// เจ้าของหอตั้งว่าหอนี้เช่าได้แบบไหน และราคาเท่าไหร่
class OwnerRentPlanView extends StatefulWidget {
  const OwnerRentPlanView({super.key, required this.dormId, required this.dormName, this.service});

  final int dormId;
  final String dormName;
  final BookingService? service;

  @override
  State<OwnerRentPlanView> createState() => _OwnerRentPlanViewState();
}

class _OwnerRentPlanViewState extends State<OwnerRentPlanView> {
  late final OwnerRentPlanController _controller =
      OwnerRentPlanController(widget.dormId, service: widget.service);

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

  Future<void> _save() async {
    final err = await _controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'บันทึกราคาเช่าแล้ว')));
    if (err == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('ราคาเช่า • ${widget.dormName}')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading) return const Center(child: CircularProgressIndicator());
          if (_controller.error != null) return Center(child: Text(_controller.error!));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'เปิดเฉพาะแบบที่หอให้เช่าได้ และใส่ราคาที่ผู้เช่าต้องชำระตอนจอง',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final p in _controller.plans)
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Switch(
                        value: p.active,
                        onChanged: (v) => _controller.update(p.plan, active: v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          key: ValueKey('price-${p.plan}'),
                          initialValue: p.price > 0 ? '${p.price}' : '',
                          enabled: p.active,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(suffixText: 'บาท', isDense: true),
                          onChanged: (v) => _controller.update(p.plan, price: int.tryParse(v.trim()) ?? 0),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _controller.saving ? null : _save,
                child: Text(_controller.saving ? 'กำลังบันทึก...' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }
}
