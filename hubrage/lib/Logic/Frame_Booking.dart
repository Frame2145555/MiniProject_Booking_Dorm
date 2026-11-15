import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/session.dart';

// Controller (MVC) ของระบบจองห้องแบบจ่ายเงินผ่านแอดมิน
//   Model      = models/booking_models.dart   (DormRoomPlan, RentPlan, Reservation)
//   Service    = services/booking_service.dart (คุยกับ /api/booking/...)
//   View       = views/room_plan_view.dart, payment_view.dart, my_reservations_view.dart,
//                admin_payments_view.dart, owner_reservations_view.dart
// รับ BookingService ทาง constructor -> ตอน unit test ส่งตัวปลอมเข้ามาแทน server ได้ (แบบเดียวกับแชท)

/// ผัง 2D: โหลดผังห้อง, เลือกห้อง + ระยะเวลาเช่า, กดจอง
class RoomPlanController extends ChangeNotifier {
  RoomPlanController(this.dormId, {BookingService? service, this.initialRoomId})
      : _service = service ?? BookingService.instance;

  final int dormId;

  /// ห้องที่เลือกมาจากหน้ารายละเอียดหอ (ถ้ามี)
  final int? initialRoomId;
  final BookingService _service;

  DormRoomPlan? plan;
  bool loading = true;
  String? error;

  /// ข้อความ error ของการกดจอง (แยกจาก error ตอนโหลด หน้าจอจะได้ไม่หายทั้งหน้า)
  String? actionError;
  bool reserving = false;

  int? selectedRoomId;
  String? selectedPlan;
  bool _disposed = false;

  PlanRoom? get selectedRoom => selectedRoomId == null ? null : plan?.roomById(selectedRoomId!);

  RentPlan? get selectedRentPlan {
    for (final p in plan?.plans ?? const <RentPlan>[]) {
      if (p.plan == selectedPlan) return p;
    }
    return null;
  }

  bool get canReserve => !reserving && selectedRoom?.canBook == true && selectedRentPlan != null;

  Future<void> load() async {
    loading = plan == null;
    error = null;
    _notify();
    try {
      plan = await _service.getRoomPlan(dormId);
      // ห้องที่เลือกไว้ถูกคนอื่นจองไปแล้ว -> ยกเลิกการเลือก
      final keep = selectedRoomId ?? initialRoomId;
      selectedRoomId = keep != null && plan!.roomById(keep)?.canBook == true ? keep : null;
      final codes = plan!.plans.map((p) => p.plan).toList();
      if (!codes.contains(selectedPlan)) {
        selectedPlan = codes.contains('month') ? 'month' : (codes.isEmpty ? null : codes.first);
      }
    } on BookingException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  void selectRoom(PlanRoom room) {
    if (!room.canBook) return;
    selectedRoomId = selectedRoomId == room.id ? null : room.id;
    actionError = null;
    _notify();
  }

  void selectPlan(String code) {
    selectedPlan = code;
    actionError = null;
    _notify();
  }

  /// จอง -> คืน Reservation (สถานะรอชำระเงิน) ให้ view เปิดหน้าจ่ายเงินต่อ / null = ไม่สำเร็จ (ดู actionError)
  Future<Reservation?> reserve({DateTime? startsAt}) async {
    if (!Session.isLoggedIn) {
      actionError = 'กรุณาเข้าสู่ระบบก่อนจองห้อง';
      _notify();
      return null;
    }
    if (Session.role != 'tenant') {
      actionError = 'ต้องเข้าสู่ระบบด้วยบัญชีผู้เช่าจึงจะจองห้องได้';
      _notify();
      return null;
    }
    if (!canReserve) return null;
    reserving = true;
    actionError = null;
    _notify();
    try {
      final reservation = await _service.reserve(
        roomId: selectedRoomId!,
        plan: selectedPlan!,
        startsAt: startsAt,
      );
      selectedRoomId = null;
      return reservation;
    } on BookingException catch (e) {
      actionError = e.message;
      return null;
    } finally {
      reserving = false;
      _notify();
      unawaited(load()); // สถานะห้องเปลี่ยน (ติดจอง) -> โหลดผังใหม่
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// หน้าชำระเงิน (QR mock) + ติดตามสถานะการจอง 1 รายการ
class PaymentController extends ChangeNotifier {
  PaymentController(this.reservationId, {Reservation? initial, BookingService? service})
      : reservation = initial,
        _service = service ?? BookingService.instance;

  final int reservationId;
  final BookingService _service;

  Reservation? reservation;
  bool loading = false;
  bool paying = false;
  String? error;
  bool _disposed = false;

  bool get canPay =>
      !paying &&
      reservation?.status == ReservationStatus.awaitingPayment &&
      reservation!.timeLeft() > Duration.zero;

  bool get canCancel => !paying && reservation?.status == ReservationStatus.awaitingPayment;

  Future<void> load() async {
    loading = reservation == null;
    error = null;
    _notify();
    try {
      reservation = await _service.getReservation(reservationId);
    } on BookingException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// กดจ่ายเงิน -> true = สำเร็จ (สถานะเป็น "รอแอดมินตรวจสอบ")
  Future<bool> pay() async {
    if (!canPay) return false;
    paying = true;
    error = null;
    _notify();
    try {
      reservation = await _service.pay(reservationId);
      return true;
    } on BookingException catch (e) {
      await load(); // อาจหมดเวลาไปแล้ว -> อัปเดตสถานะให้ตรง server
      error = e.message; // ตั้งหลัง load (load ล้าง error) -> หน้าจอโชว์สาเหตุที่จ่ายไม่ได้
      return false;
    } finally {
      paying = false;
      _notify();
    }
  }

  Future<bool> cancel() async {
    if (!canCancel) return false;
    paying = true;
    _notify();
    try {
      reservation = await _service.cancel(reservationId);
      return true;
    } on BookingException catch (e) {
      error = e.message;
      return false;
    } finally {
      paying = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// ใครดูรายการการจอง
enum ReservationViewer { tenant, admin, owner }

/// รายการการจอง: ผู้เช่า (ของฉัน) / แอดมิน (ตรวจเงิน) / เจ้าของหอ (ยืนยันการจอง)
class ReservationListController extends ChangeNotifier {
  ReservationListController(this.viewer, {BookingService? service, String? status})
      : _service = service ?? BookingService.instance,
        status = status ??
            switch (viewer) {
              ReservationViewer.admin => 'paid',
              ReservationViewer.owner => 'approved',
              ReservationViewer.tenant => 'all',
            };

  final ReservationViewer viewer;
  final BookingService _service;

  /// ตัวกรองสถานะ (แอดมิน / เจ้าของหอ)
  String status;
  List<Reservation> items = [];
  bool loading = true;
  String? error;

  /// รายการที่กำลังกดอนุมัติ/ปฏิเสธอยู่ (ปุ่มของรายการนั้นหมุน กันกดซ้ำ)
  final Set<int> busy = {};
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      items = switch (viewer) {
        ReservationViewer.tenant => await _service.myReservations(),
        ReservationViewer.admin => await _service.adminPayments(status: status),
        ReservationViewer.owner => await _service.ownerReservations(status: status),
      };
    } on BookingException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> setStatus(String value) async {
    if (value == status) return;
    status = value;
    await load();
  }

  /// แอดมินตรวจเงิน -> null = สำเร็จ / ข้อความ error
  Future<String?> adminReview(Reservation r, {required bool approve, String? note}) =>
      _act(r, () => _service.adminReview(r.id, approve: approve, note: note));

  /// เจ้าของหอยืนยัน/ปฏิเสธ -> null = สำเร็จ / ข้อความ error
  Future<String?> ownerDecide(Reservation r, {required bool confirm, String? note}) =>
      _act(r, () => _service.ownerDecide(r.id, confirm: confirm, note: note));

  Future<String?> _act(Reservation r, Future<Reservation> Function() call) async {
    if (!busy.add(r.id)) return null;
    _notify();
    try {
      final updated = await call();
      // รายการที่ไม่ตรงตัวกรองแล้ว (เช่น อนุมัติแล้วไม่ใช่ "รอตรวจ") เอาออกจากหน้า
      if (status == 'all' || updated.status.code == status) {
        items = [for (final x in items) x.id == updated.id ? updated : x];
      } else {
        items = items.where((x) => x.id != updated.id).toList();
      }
      return null;
    } on BookingException catch (e) {
      return e.message;
    } finally {
      busy.remove(r.id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// เจ้าของหอตั้งราคาเช่าแต่ละแบบ (1 อาทิตย์ / 1 เดือน / 1 เทอม / 1 ปี)
class OwnerRentPlanController extends ChangeNotifier {
  OwnerRentPlanController(this.dormId, {BookingService? service})
      : _service = service ?? BookingService.instance;

  final int dormId;
  final BookingService _service;

  List<RentPlan> plans = [];
  bool loading = true;
  bool saving = false;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      plans = await _service.ownerPlans(dormId);
    } on BookingException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  void update(String plan, {int? price, bool? active}) {
    plans = [for (final p in plans) p.plan == plan ? p.copyWith(price: price, active: active) : p];
    _notify();
  }

  /// ตรวจก่อนส่ง -> ข้อความ error / null = ใช้ได้
  String? validate() {
    if (!plans.any((p) => p.active)) return 'ต้องเปิดให้เช่าอย่างน้อย 1 แบบ';
    for (final p in plans) {
      if (p.active && p.price <= 0) return 'กรุณาใส่ราคา ${p.label}';
    }
    return null;
  }

  /// null = บันทึกสำเร็จ / ข้อความ error
  Future<String?> save() async {
    final invalid = validate();
    if (invalid != null) return invalid;
    saving = true;
    _notify();
    try {
      await _service.saveOwnerPlans(dormId, plans);
      return null;
    } on BookingException catch (e) {
      return e.message;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
