// Unit test ของ Controller แชท (Logic/Frame_Chat.dart)
// ใช้ ChatService ปลอมที่ทำตัวเหมือน server -> ไม่ต้องเปิด node / MySQL / socket จริง
// วิธีรัน: flutter test test/chat_controller_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';

import '../lib/Logic/Frame_Chat.dart';
import '../lib/services/session.dart';
import 'fake_chat_service.dart';

const me = 1;
const otherUser = 2;
const roomId = 10;

Map<String, dynamic> messageFrom(int senderId, String text, {int id = 1, int conv = roomId}) => {
      'id': id,
      'conversation_id': conv,
      'sender_id': senderId,
      'text': text,
      'sent_at': '2026-11-09T08:00:00.000Z',
      'read_at': null,
    };

/// รอให้งาน async ที่ค้างอยู่ (เช่น โหลดรายการ) ทำเสร็จก่อน
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    Session.token = 'fake-token';
    Session.userId = me;
    service = FakeChatService();
  });

  group('ChatRoomController', () {
    test('เปิดห้อง: join ห้อง, mark read และโหลดประวัติแชท', () async {
      service.history = [messageFrom(otherUser, 'สวัสดีครับ')];
      final controller = ChatRoomController(roomId, service: service);

      expect(controller.loading, isTrue);
      await controller.start();

      expect(service.joined, [roomId]);
      expect(service.markedRead, contains(roomId));
      expect(controller.loading, isFalse);
      expect(controller.messages.single['text'], 'สวัสดีครับ');
    });

    test('ส่งข้อความ -> server ได้รับ และข้อความขึ้นในห้อง', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      final ok = await controller.send('  ห้องยังว่างไหมครับ  ');

      expect(ok, isTrue);
      expect(service.sentTexts, ['ห้องยังว่างไหมครับ']); // ตัดช่องว่างก่อนส่ง
      expect(controller.messages.last['text'], 'ห้องยังว่างไหมครับ');
      expect(controller.isMine(controller.messages.last), isTrue);
      expect(controller.sending, isFalse);
    });

    test('ข้อความว่าง -> ไม่ส่ง', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      final ok = await controller.send('    ');

      expect(ok, isNull);
      expect(service.sentTexts, isEmpty);
      expect(controller.messages, isEmpty);
    });

    test('server ปฏิเสธ -> ได้ false, ปุ่มส่งกลับมาใช้ได้, ไม่มีข้อความเพิ่ม', () async {
      service.serverAcceptsMessage = false;
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      final ok = await controller.send('ทดสอบ');

      expect(ok, isFalse);
      expect(controller.sending, isFalse);
      expect(controller.messages, isEmpty);
    });

    test('อีกฝั่งส่งข้อความมา -> ขึ้นในห้อง, แจ้งหน้าจอ และ mark read', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();
      service.markedRead.clear();
      var screenUpdated = 0;
      controller.addListener(() => screenUpdated++);

      service.serverEmit('new_message', messageFrom(otherUser, 'ว่างครับ', id: 5));

      expect(controller.messages.single['text'], 'ว่างครับ');
      expect(controller.isMine(controller.messages.single), isFalse);
      expect(screenUpdated, 1);
      expect(service.markedRead, [roomId]);
    });

    test('ข้อความของห้องอื่น -> ไม่ขึ้นในห้องนี้', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      service.serverEmit('new_message', messageFrom(otherUser, 'ห้องอื่น', conv: 99));

      expect(controller.messages, isEmpty);
    });

    test('ข้อความ id ซ้ำ -> ไม่ขึ้นซ้ำ', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      service.serverEmit('new_message', messageFrom(otherUser, 'ครั้งเดียว', id: 7));
      service.serverEmit('new_message', messageFrom(otherUser, 'ครั้งเดียว', id: 7));

      expect(controller.messages.length, 1);
    });

    test('อีกฝั่งอ่านแล้ว -> ข้อความของเราขึ้น "อ่านแล้ว"', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();
      await controller.send('อ่านหรือยัง');
      expect(controller.messages.last['read_at'], isNull);

      service.serverEmit('messages_read', {'conversation_id': roomId, 'reader_id': otherUser});

      expect(controller.messages.last['read_at'], isNotNull);
    });

    test('เน็ตหลุดแล้วต่อใหม่ -> join ห้องซ้ำอัตโนมัติ', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();
      service.joined.clear();

      service.serverEmit('connect', null);

      expect(service.joined, [roomId]);
    });

    test('ปิดห้อง (dispose) -> เลิกฟัง event ทั้งหมด', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();
      expect(service.handlers, isNotEmpty);

      controller.dispose();

      expect(service.handlers, isEmpty);
    });
  });

  group('ChatListController', () {
    test('ยังไม่ login -> ไม่โหลดรายการ', () {
      Session.clear();
      final controller = ChatListController(service: service);

      controller.start();

      expect(service.fetchConversationsCount, 0);
    });

    test('login แล้ว -> โหลดรายการห้องแชท', () async {
      service.conversationList = [
        {'id': roomId, 'other_name': 'เจ้าของหอทดสอบ', 'dorm_name': 'หอรวย เธะ', 'unread': 2},
      ];
      final controller = ChatListController(service: service);

      controller.start();
      await flush();

      expect(controller.loading, isFalse);
      expect(controller.conversations.single['unread'], 2);
    });

    test('มีข้อความใหม่ (conversation_updated) -> โหลดรายการใหม่เอง', () async {
      final controller = ChatListController(service: service);
      controller.start();
      await flush();
      expect(service.fetchConversationsCount, 1);

      service.serverEmit('conversation_updated', {'conversation_id': roomId});
      await flush();

      expect(service.fetchConversationsCount, 2);
    });
  });
}