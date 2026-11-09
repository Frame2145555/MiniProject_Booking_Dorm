// Unit test ฟังก์ชันล้วนๆ (ไม่ต้องมี server)  วิธีรัน: flutter test
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/api_config.dart';
import '../lib/services/chat_service.dart';
import '../lib/services/session.dart';

void main() {
  group('formatChatTime', () {
    test('ไม่มีค่า / ค่าเพี้ยน ได้ข้อความว่าง', () {
      expect(formatChatTime(null), '');
      expect(formatChatTime('not-a-date'), '');
    });

    test('ข้อความวันนี้ แสดงเป็น ชั่วโมง:นาที', () {
      final now = DateTime.now();
      final todayAt0905 = DateTime(now.year, now.month, now.day, 9, 5);
      // server ส่งเวลาแบบ UTC มา (…Z) ฟังก์ชันต้องแปลงกลับเป็นเวลาเครื่อง
      expect(formatChatTime(todayAt0905.toUtc().toIso8601String()), '09:05');
    });

    test('ข้อความวันอื่น แสดงเป็น วัน/เดือน', () {
      final oldDay = DateTime(2020, 1, 15, 10, 30);
      expect(formatChatTime(oldDay.toUtc().toIso8601String()), '15/1');
    });
  });

  test('ApiConfig.baseUrl ต้องไม่มี / ท้าย (ไม่งั้นได้ //api/login แล้ว 404)', () {
    expect(ApiConfig.baseUrl.endsWith('/'), isFalse);
  });

  test('Session.clear ล้างข้อมูลผู้ใช้ทั้งหมด', () {
    Session.token = 'abc';
    Session.userId = 5;
    Session.role = 'seller';
    Session.fullName = 'ทดสอบ';
    expect(Session.isLoggedIn, isTrue);

    Session.clear();
    expect(Session.isLoggedIn, isFalse);
    expect(Session.userId, 0);
    expect(Session.role, '');
    expect(Session.fullName, '');
  });
}
