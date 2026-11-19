// BookingService ปลอม ใช้ใน widget test ของระบบจอง/ชำระเงิน (ผู้เช่า / เจ้าของหอ)
// ทำตัวเหมือน server: เก็บรายการจองไว้ในหน่วยความจำ จำว่าถูกเรียกอะไร และสั่งให้ "server" ตอบ error ได้
import '../../lib/models/booking_models.dart';
import '../../lib/services/booking_service.dart';

const bookingTestReservationId = 34;

/// รายการจอง 1 รายการ (ค่าเริ่มต้น = รอชำระเงิน เหลือเวลา 15 นาที)
Reservation bookingTestReservation({
  int id = bookingTestReservationId,
  ReservationStatus status = ReservationStatus.awaitingPayment,
  DateTime? expiresAt,
  int amount = 4000,
  int? paidAmount,
  String? paymentRef,
  String roomNumber = 'A08',
  String tenantName = 'ผู้เช่าทดสอบ',
  String? ownerNote,
}) => Reservation(
  id: id,
  bookingId: 17,
  status: status,
  statusLabel: status.shortLabel,
  plan: 'month',
  planLabel: '1 เดือน',
  amount: amount,
  paidAmount: paidAmount,
  amountMatches: paidAmount == null ? null : paidAmount == amount,
  paymentRef: paymentRef,
  paidAt: paidAmount == null ? null : DateTime(2026, 11, 18, 10, 30),
  expiresAt:
      expiresAt ??
      (status == ReservationStatus.awaitingPayment
          ? DateTime.now().add(const Duration(minutes: 15))
          : null),
  startsAt: '2026-12-01',
  endsAt: '2026-12-31',
  dormId: 2,
  dormName: 'หอทดสอบ',
  ownerName: 'เจ้าของหอทดสอบ',
  roomId: 8,
  roomNumber: roomNumber,
  roomType: 'ห้องแอร์',
  floor: 2,
  tenantId: 9,
  tenantName: tenantName,
  tenantPhone: '0812345678',
  ownerNote: ownerNote,
);

/// เปลี่ยนสถานะ (และข้อมูลที่ server เติมให้ตอนจ่ายเงิน) ของรายการจองเดิม
Reservation bookingTestWithStatus(
  Reservation r,
  ReservationStatus status, {
  String? ownerNote,
}) {
  final paid = status != ReservationStatus.awaitingPayment &&
      status != ReservationStatus.cancelled &&
      status != ReservationStatus.expired;
  return bookingTestReservation(
    id: r.id,
    status: status,
    expiresAt: r.expiresAt,
    amount: r.amount,
    paidAmount: paid ? (r.paidAmount ?? r.amount) : null,
    paymentRef: paid ? (r.paymentRef ?? 'PAY-${r.id}-TEST') : null,
    roomNumber: r.roomNumber,
    tenantName: r.tenantName,
    ownerNote: ownerNote ?? r.ownerNote,
  );
}

class FakeBookingService extends BookingService {
  /// "ฐานข้อมูล" การจองทั้งหมด (id -> รายการล่าสุด)
  final Map<int, Reservation> reservations = {};

  int myReservationsCalls = 0;
  final List<int> payCalls = [];
  final List<int> cancelCalls = [];
  final List<String> ownerStatusRequests = [];
  final List<Map<String, Object?>> ownerDecisions = [];
  final List<List<RentPlan>> savedPlans = [];

  /// ตั้งค่าเป็นข้อความ = ให้ "server" ตอบ error นั้น
  String? payError;
  String? listError;
  String? decideError;

  /// สถานะที่ getReservation จะคืนครั้งถัดไป (จำลอง server เปลี่ยนสถานะเอง เช่น หมดเวลาชำระ)
  ReservationStatus? nextLoadStatus;

  List<RentPlan> plans = const [
    RentPlan(plan: 'week', label: '1 อาทิตย์', price: 0, active: false),
    RentPlan(plan: 'month', label: '1 เดือน', price: 4000),
    RentPlan(plan: 'term', label: '1 เทอม', price: 18000),
    RentPlan(plan: 'year', label: '1 ปี', price: 0, active: false),
  ];

  void add(Reservation r) => reservations[r.id] = r;

  Reservation _get(int id) =>
      reservations[id] ?? (throw const BookingException('ไม่พบการจองนี้'));

  // ───────────── ผู้เช่า ─────────────

  @override
  Future<Reservation> getReservation(int reservationId) async {
    final next = nextLoadStatus;
    if (next != null) {
      nextLoadStatus = null;
      reservations[reservationId] = bookingTestWithStatus(
        _get(reservationId),
        next,
      );
    }
    return _get(reservationId);
  }

  @override
  Future<Reservation> pay(int reservationId) async {
    payCalls.add(reservationId);
    if (payError != null) throw BookingException(payError!);
    return reservations[reservationId] = bookingTestWithStatus(
      _get(reservationId),
      ReservationStatus.paid,
    );
  }

  @override
  Future<Reservation> cancel(int reservationId) async {
    cancelCalls.add(reservationId);
    return reservations[reservationId] = bookingTestWithStatus(
      _get(reservationId),
      ReservationStatus.cancelled,
    );
  }

  @override
  Future<List<Reservation>> myReservations() async {
    myReservationsCalls++;
    if (listError != null) throw BookingException(listError!);
    return reservations.values.toList();
  }

  // ───────────── เจ้าของหอ ─────────────

  @override
  Future<List<Reservation>> ownerReservations({String status = 'approved'}) async {
    ownerStatusRequests.add(status);
    if (listError != null) throw BookingException(listError!);
    return reservations.values
        .where((r) => status == 'all' || r.status.code == status)
        .toList();
  }

  @override
  Future<Reservation> ownerDecide(
    int reservationId, {
    required bool confirm,
    String? note,
  }) async {
    ownerDecisions.add({'id': reservationId, 'confirm': confirm, 'note': note});
    if (decideError != null) throw BookingException(decideError!);
    return reservations[reservationId] = bookingTestWithStatus(
      _get(reservationId),
      confirm ? ReservationStatus.completed : ReservationStatus.ownerRejected,
      ownerNote: note,
    );
  }

  @override
  Future<List<RentPlan>> ownerPlans(int dormId) async => plans;

  @override
  Future<void> saveOwnerPlans(int dormId, List<RentPlan> plans) async {
    savedPlans.add(plans);
    this.plans = plans;
  }
}
