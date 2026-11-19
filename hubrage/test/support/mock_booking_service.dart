// BookingService ปลอมด้วย mocktail ใช้ใน widget test ของระบบจอง/ชำระเงิน (ผู้เช่า / แอดมิน / เจ้าของหอ)
//
//   final server = BookingTestServer()..add(bookingTestReservation());
//   PaymentView(reservationId: 34, service: server.service);
//   verify(() => server.service.pay(34)).called(1);
//   when(() => server.service.pay(any())).thenThrow(const BookingException('...')); // ให้ server ตอบ error
//
// stub ที่ตั้งทีหลังชนะ -> เทสต์ไหนอยากให้ server ตอบแบบอื่น ก็ when(...) ทับได้เลย
import 'package:mocktail/mocktail.dart';

import '../../lib/models/booking_models.dart';
import '../../lib/services/booking_service.dart';

class MockBookingService extends Mock implements BookingService {}

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

/// รายการจองเดิมในสถานะใหม่ (เติมยอดที่จ่าย + เลขอ้างอิงให้ เหมือนที่ server ทำตอนจ่ายเงิน)
Reservation bookingTestWithStatus(
  Reservation r,
  ReservationStatus status, {
  String? ownerNote,
}) {
  final paid =
      status != ReservationStatus.awaitingPayment &&
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

/// ราคาเช่าเริ่มต้นของหอทดสอบ
const bookingTestPlans = [
  RentPlan(plan: 'week', label: '1 อาทิตย์', price: 0, active: false),
  RentPlan(plan: 'month', label: '1 เดือน', price: 4000),
  RentPlan(plan: 'term', label: '1 เทอม', price: 18000),
  RentPlan(plan: 'year', label: '1 ปี', price: 0, active: false),
];

/// ตัวแทน server ระบบจอง: เก็บรายการจองในหน่วยความจำ แล้วตั้ง stub ของ MockBookingService ให้ตอบจากข้อมูลนี้
class BookingTestServer {
  BookingTestServer() {
    // any() กับ List<RentPlan> ต้องมีค่าสำรองให้ mocktail
    registerFallbackValue(<RentPlan>[]);
    _stubLikeRealServer();
  }

  final MockBookingService service = MockBookingService();

  /// "ตาราง booking_payments" (id -> รายการล่าสุด)
  final Map<int, Reservation> reservations = {};

  List<RentPlan> plans = List.of(bookingTestPlans);

  void add(Reservation r) => reservations[r.id] = r;

  Reservation _get(int id) =>
      reservations[id] ?? (throw const BookingException('ไม่พบการจองนี้'));

  Reservation _update(int id, ReservationStatus status, {String? note}) =>
      reservations[id] = bookingTestWithStatus(_get(id), status, ownerNote: note);

  List<Reservation> _withStatus(String status) => reservations.values
      .where((r) => status == 'all' || r.status.code == status)
      .toList();

  void _stubLikeRealServer() {
    // ---------- ผู้เช่า ----------
    when(
      () => service.getReservation(any()),
    ).thenAnswer((i) async => _get(i.positionalArguments.first as int));
    when(() => service.pay(any())).thenAnswer(
      (i) async =>
          _update(i.positionalArguments.first as int, ReservationStatus.paid),
    );
    when(() => service.cancel(any())).thenAnswer(
      (i) async => _update(
        i.positionalArguments.first as int,
        ReservationStatus.cancelled,
      ),
    );
    when(
      () => service.myReservations(),
    ).thenAnswer((_) async => reservations.values.toList());

    // ---------- แอดมิน ----------
    when(
      () => service.adminPayments(status: any(named: 'status')),
    ).thenAnswer((i) async => _withStatus(i.namedArguments[#status] as String));
    when(
      () => service.adminReview(
        any(),
        approve: any(named: 'approve'),
        note: any(named: 'note'),
      ),
    ).thenAnswer(
      (i) async => _update(
        i.positionalArguments.first as int,
        i.namedArguments[#approve] as bool
            ? ReservationStatus.approved
            : ReservationStatus.rejected,
        note: i.namedArguments[#note] as String?,
      ),
    );

    // ---------- เจ้าของหอ ----------
    when(
      () => service.ownerReservations(status: any(named: 'status')),
    ).thenAnswer((i) async => _withStatus(i.namedArguments[#status] as String));
    when(
      () => service.ownerDecide(
        any(),
        confirm: any(named: 'confirm'),
        note: any(named: 'note'),
      ),
    ).thenAnswer(
      (i) async => _update(
        i.positionalArguments.first as int,
        i.namedArguments[#confirm] as bool
            ? ReservationStatus.completed
            : ReservationStatus.ownerRejected,
        note: i.namedArguments[#note] as String?,
      ),
    );
    when(() => service.ownerPlans(any())).thenAnswer((_) async => plans);
    when(() => service.saveOwnerPlans(any(), any())).thenAnswer((i) async {
      plans = i.positionalArguments[1] as List<RentPlan>;
    });
  }
}
