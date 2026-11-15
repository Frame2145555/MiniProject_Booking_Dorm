// Model (MVC) ของระบบจองห้องแบบจ่ายเงินผ่านแอดมิน + ผังห้อง 2D
// แปลง JSON จาก server (booking_payment_routes.js) เป็น object
//
//   ผังห้อง     GET /api/booking/dorms/:id/plan  -> DormRoomPlan (ชั้น > ห้อง) + RentPlan (ราคาเช่าแต่ละแบบ)
//   การจอง      /api/booking/reservations/...     -> Reservation (สถานะ + เงิน)

import 'package:flutter/material.dart';

int _toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _toIntOrNull(Object? v) => v == null ? null : _toInt(v);

DateTime? _toTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// 5000 -> '5,000'
String formatBaht(num value) => value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

/// 2026-11-20 -> 20/11/2026
String formatThaiDate(String? ymd) {
  final t = DateTime.tryParse(ymd ?? '');
  return t == null ? '-' : '${t.day}/${t.month}/${t.year}';
}

// ───────────────────────── ราคาเช่า ─────────────────────────

/// ระยะเวลาเช่าที่เจ้าของหอเปิดให้เลือก + ราคา
class RentPlan {
  /// week | month | term | year
  final String plan;
  final String label;
  final int price;

  /// เจ้าของหอเปิดให้เช่าแบบนี้ไหม (ใช้ในหน้าตั้งราคาของเจ้าของหอ)
  final bool active;

  const RentPlan({
    required this.plan,
    required this.label,
    required this.price,
    this.active = true,
  });

  factory RentPlan.fromJson(Map<String, dynamic> json) => RentPlan(
        plan: json['plan']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        price: _toInt(json['price']),
        active: json['active'] == null ? true : json['active'] == true,
      );

  RentPlan copyWith({int? price, bool? active}) => RentPlan(
        plan: plan,
        label: label,
        price: price ?? this.price,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {'plan': plan, 'price': price, 'active': active};
}

// ───────────────────────── ผังห้อง 2D ─────────────────────────

/// สถานะห้องในผัง (สีตามที่ออกแบบ: เทา = มีผู้เช่า, เขียว = ว่าง, ฟ้า = ติดจอง, แดง = ปรับปรุง)
enum RoomState {
  available('ว่าง', Color(0xFF2E9E6B), Color(0xFFE6F6EE), Icons.check_rounded),
  occupied('มีผู้เช่า', Color(0xFF8A8F98), Color(0xFFECEDEF), Icons.close_rounded),
  reserved('ติดจอง', Color(0xFF3B82F6), Color(0xFFE8F0FE), Icons.schedule_rounded),
  maintenance('ปรับปรุง', Color(0xFFE5484D), Color(0xFFFDECEC), Icons.build_rounded);

  const RoomState(this.label, this.color, this.background, this.icon);
  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  static RoomState parse(Object? v) => RoomState.values.firstWhere(
        (s) => s.name == v,
        orElse: () => RoomState.occupied, // ไม่รู้จัก = ถือว่าจองไม่ได้ (ปลอดภัยไว้ก่อน)
      );
}

class PlanRoom {
  final int id;
  final String number;
  final String type;
  final int monthlyPrice;
  final int floor;
  final RoomState state;

  /// ห้องนี้ฉันจองไว้เอง (เลขการจอง) / null = ไม่ใช่ของฉัน
  final int? myReservationId;

  const PlanRoom({
    required this.id,
    required this.number,
    required this.type,
    required this.monthlyPrice,
    required this.floor,
    required this.state,
    this.myReservationId,
  });

  factory PlanRoom.fromJson(Map<String, dynamic> json) => PlanRoom(
        id: _toInt(json['id']),
        number: json['number']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        monthlyPrice: _toInt(json['monthlyPrice']),
        floor: _toInt(json['floor']),
        state: RoomState.parse(json['state']),
        myReservationId: _toIntOrNull(json['myReservationId']),
      );

  bool get canBook => state == RoomState.available;
  bool get isMine => myReservationId != null;
}

class FloorPlan {
  final int floor;
  final List<PlanRoom> rooms;
  const FloorPlan({required this.floor, required this.rooms});

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
        floor: _toInt(json['floor']),
        rooms: ((json['rooms'] as List?) ?? const [])
            .whereType<Map>()
            .map((r) => PlanRoom.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
      );
}

/// ผังห้องทั้งหอ (ชั้นบนสุดอยู่ก่อน เหมือนมองตึกจากด้านหน้า)
class DormRoomPlan {
  final int dormId;
  final String dormName;
  final List<RentPlan> plans;
  final List<FloorPlan> floors;
  final int holdMinutes;

  const DormRoomPlan({
    required this.dormId,
    required this.dormName,
    required this.plans,
    required this.floors,
    this.holdMinutes = 30,
  });

  factory DormRoomPlan.fromJson(Map<String, dynamic> json) {
    final dorm = json['dorm'] is Map ? Map<String, dynamic>.from(json['dorm']) : <String, dynamic>{};
    final floors = ((json['floors'] as List?) ?? const [])
        .whereType<Map>()
        .map((f) => FloorPlan.fromJson(Map<String, dynamic>.from(f)))
        .toList()
      ..sort((a, b) => b.floor.compareTo(a.floor));
    return DormRoomPlan(
      dormId: _toInt(dorm['id']),
      dormName: dorm['name']?.toString() ?? '',
      plans: ((json['plans'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => RentPlan.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      floors: floors,
      holdMinutes: json['holdMinutes'] == null ? 30 : _toInt(json['holdMinutes']),
    );
  }

  Iterable<PlanRoom> get allRooms => floors.expand((f) => f.rooms);

  int count(RoomState state) => allRooms.where((r) => r.state == state).length;

  PlanRoom? roomById(int id) {
    for (final r in allRooms) {
      if (r.id == id) return r;
    }
    return null;
  }
}

// ───────────────────────── การจอง + การชำระเงิน ─────────────────────────

enum ReservationStatus {
  awaitingPayment('awaiting_payment', 'รอชำระเงิน', Color(0xFFD98E04), Color(0xFFFFF4DC)),
  paid('paid', 'รอแอดมินตรวจสอบ', Color(0xFF3B82F6), Color(0xFFE8F0FE)),
  approved('approved', 'รอเจ้าของหอยืนยัน', Color(0xFF6B5FB5), Color(0xFFEFEDFA)),
  completed('completed', 'จองสำเร็จ', Color(0xFF2E9E6B), Color(0xFFE6F6EE)),
  rejected('rejected', 'แอดมินไม่อนุมัติ', Color(0xFFE5484D), Color(0xFFFDECEC)),
  ownerRejected('owner_rejected', 'เจ้าของหอปฏิเสธ', Color(0xFFE5484D), Color(0xFFFDECEC)),
  cancelled('cancelled', 'ยกเลิกแล้ว', Color(0xFF8A8F98), Color(0xFFECEDEF)),
  expired('expired', 'หมดเวลาชำระเงิน', Color(0xFF8A8F98), Color(0xFFECEDEF));

  const ReservationStatus(this.code, this.shortLabel, this.color, this.background);
  final String code;
  final String shortLabel;
  final Color color;
  final Color background;

  static ReservationStatus parse(Object? v) => ReservationStatus.values.firstWhere(
        (s) => s.code == v,
        orElse: () => ReservationStatus.cancelled,
      );

  /// ยังถือห้องไว้อยู่ (ยังไม่จบ)
  bool get isActive => this == awaitingPayment || this == paid || this == approved;

  /// ขั้นที่เท่าไหร่ในเส้นทางปกติ (0 จอง, 1 จ่าย, 2 แอดมินตรวจ, 3 เจ้าของยืนยัน) / -1 = จบแบบไม่สำเร็จ
  int get step => switch (this) {
        ReservationStatus.awaitingPayment => 0,
        ReservationStatus.paid => 1,
        ReservationStatus.approved => 2,
        ReservationStatus.completed => 3,
        _ => -1,
      };
}

class Reservation {
  final int id;
  final int bookingId;
  final ReservationStatus status;

  /// ข้อความสถานะเต็มจาก server เช่น "รอแอดมินตรวจสอบการชำระเงิน"
  final String statusLabel;
  final String plan;
  final String planLabel;
  final int amount;
  final int? paidAmount;
  final bool? amountMatches;
  final String? paymentRef;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? startsAt;
  final String? endsAt;
  final int dormId;
  final String dormName;
  final String ownerName;
  final int roomId;
  final String roomNumber;
  final String roomType;
  final int floor;
  final int tenantId;
  final String tenantName;
  final String? tenantPhone;
  final String? adminNote;
  final String? ownerNote;

  const Reservation({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.statusLabel,
    required this.plan,
    required this.planLabel,
    required this.amount,
    this.paidAmount,
    this.amountMatches,
    this.paymentRef,
    this.paidAt,
    this.expiresAt,
    this.createdAt,
    this.startsAt,
    this.endsAt,
    required this.dormId,
    required this.dormName,
    required this.ownerName,
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.floor,
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone,
    this.adminNote,
    this.ownerNote,
  });

  factory Reservation.fromJson(Map<String, dynamic> j) {
    final status = ReservationStatus.parse(j['status']);
    return Reservation(
      id: _toInt(j['id']),
      bookingId: _toInt(j['bookingId']),
      status: status,
      statusLabel: j['statusLabel']?.toString() ?? status.shortLabel,
      plan: j['plan']?.toString() ?? '',
      planLabel: j['planLabel']?.toString() ?? '',
      amount: _toInt(j['amount']),
      paidAmount: _toIntOrNull(j['paidAmount']),
      amountMatches: j['amountMatches'] is bool ? j['amountMatches'] as bool : null,
      paymentRef: j['paymentRef']?.toString(),
      paidAt: _toTime(j['paidAt']),
      expiresAt: _toTime(j['expiresAt']),
      createdAt: _toTime(j['createdAt']),
      startsAt: j['startsAt']?.toString(),
      endsAt: j['endsAt']?.toString(),
      dormId: _toInt(j['dormId']),
      dormName: j['dormName']?.toString() ?? '',
      ownerName: j['ownerName']?.toString() ?? '',
      roomId: _toInt(j['roomId']),
      roomNumber: j['roomNumber']?.toString() ?? '',
      roomType: j['roomType']?.toString() ?? '',
      floor: _toInt(j['floor']),
      tenantId: _toInt(j['tenantId']),
      tenantName: j['tenantName']?.toString() ?? '',
      tenantPhone: j['tenantPhone']?.toString(),
      adminNote: j['adminNote']?.toString(),
      ownerNote: j['ownerNote']?.toString(),
    );
  }

  String get amountText => '${formatBaht(amount)} บาท';
  String get stayText => '${formatThaiDate(startsAt)} - ${formatThaiDate(endsAt)}';

  /// เวลาที่เหลือให้จ่ายเงิน (0 = หมดเวลา / ไม่ต้องจ่ายแล้ว)
  Duration timeLeft([DateTime? now]) {
    if (status != ReservationStatus.awaitingPayment || expiresAt == null) return Duration.zero;
    final left = expiresAt!.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}
