import '../models/booking.dart';
import '../models/payment.dart';
import '../models/roommate.dart';

// ข้อมูลจำลอง: ตรงกับ seed.sql ของ Alex Morgan (user_id = 1)
// Sprint 2 ยังไม่ต่อ backend จึงใช้ข้อมูลชุดนี้ไปก่อน

final List<Booking> mockBookings = [
  Booking(
    id: 1,
    referenceCode: 'DS-000001',
    status: 'reserved',
    semesterName: 'Fall 2027',
    leaseMonths: 9,
    moveInDate: DateTime(2027, 8, 20),
    moveOutDate: DateTime(2028, 5, 20),
    monthlyRent: 480,
    totalAmount: 4545,
    depositAmount: 200,
    depositPaid: 200,
    roomNumber: '102',
    roomType: 'Double Suite',
    buildingCode: 'A',
    buildingName: 'North Hall',
    addons: ['Micro-Fridge Rental'],
  ),
  Booking(
    id: 4,
    referenceCode: 'DS-000004',
    status: 'cancelled',
    semesterName: 'Spring 2028',
    leaseMonths: 9,
    moveInDate: DateTime(2028, 1, 10),
    moveOutDate: DateTime(2028, 10, 10),
    monthlyRent: 620,
    totalAmount: 5580,
    depositAmount: 200,
    depositPaid: 0,
    roomNumber: '101',
    roomType: 'Single Studio',
    buildingCode: 'B',
    buildingName: 'South Residence',
    addons: [],
  ),
];

/// key = booking id
final Map<int, List<Roommate>> mockRoommates = {
  1: [
    const Roommate(
      fullName: 'Jordan Lee',
      faculty: 'Engineering',
      matchPercent: 85,
      sameSleepHabit: true,
    ),
  ],
  4: [],
};

final List<Payment> mockPayments = [
  Payment(
    id: 1,
    receiptNo: 'RC-000001',
    amount: 200,
    paymentType: 'deposit',
    method: 'mock',
    status: 'paid',
    paidAt: DateTime(2026, 10, 20, 10, 30),
    referenceCode: 'DS-000001',
    roomNumber: '102',
    buildingName: 'North Hall',
  ),
  Payment(
    id: 4,
    receiptNo: 'RC-000003',
    amount: 200,
    paymentType: 'deposit',
    method: 'mock',
    status: 'refunded',
    paidAt: DateTime(2026, 9, 15, 9, 0),
    referenceCode: 'DS-000004',
    roomNumber: '101',
    buildingName: 'South Residence',
  ),
];
