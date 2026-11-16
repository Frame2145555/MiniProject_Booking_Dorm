// Unit test ของ Controller แชท (Logic/Frame_Chat.dart)
// ใช้ ChatService ปลอมที่ทำตัวเหมือน server -> ไม่ต้องเปิด node / MySQL / socket จริง
// วิธีรัน: flutter test test/unit/shared_chat_controller_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';

import '../../lib/Logic/Frame_Chat.dart';
import '../../lib/services/session.dart';
import '../support/fake_chat_service.dart';

const me = 1;
const otherUser = 2;
const roomId = 10;

Map<String, dynamic> messageFrom(
  int senderId,
  String text, {
  int id = 1,
  int conv = roomId,
}) => {
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
      expect(controller.messages.single.text, 'สวัสดีครับ');
    });

    test('ส่งข้อความ -> server ได้รับ และข้อความขึ้นในห้อง', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      final ok = await controller.send('  ห้องยังว่างไหมครับ  ');

      expect(ok, isTrue);
      expect(service.sentTexts, ['ห้องยังว่างไหมครับ']); // ตัดช่องว่างก่อนส่ง
      expect(controller.messages.last.text, 'ห้องยังว่างไหมครับ');
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

    test(
      'server ปฏิเสธ -> ได้ false, ปุ่มส่งกลับมาใช้ได้, ไม่มีข้อความเพิ่ม',
      () async {
        service.serverAcceptsMessage = false;
        final controller = ChatRoomController(roomId, service: service);
        await controller.start();

        final ok = await controller.send('ทดสอบ');

        expect(ok, isFalse);
        expect(controller.sending, isFalse);
        expect(controller.messages, isEmpty);
      },
    );

    test(
      'อีกฝั่งส่งข้อความมา -> ขึ้นในห้อง, แจ้งหน้าจอ และ mark read',
      () async {
        final controller = ChatRoomController(roomId, service: service);
        await controller.start();
        service.markedRead.clear();
        var screenUpdated = 0;
        controller.addListener(() => screenUpdated++);

        service.serverEmit(
          'new_message',
          messageFrom(otherUser, 'ว่างครับ', id: 5),
        );

        expect(controller.messages.single.text, 'ว่างครับ');
        expect(controller.isMine(controller.messages.single), isFalse);
        expect(screenUpdated, 1);
        expect(service.markedRead, [roomId]);
      },
    );

    test('ข้อความของห้องอื่น -> ไม่ขึ้นในห้องนี้', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      service.serverEmit(
        'new_message',
        messageFrom(otherUser, 'ห้องอื่น', conv: 99),
      );

      expect(controller.messages, isEmpty);
    });

    test('ข้อความ id ซ้ำ -> ไม่ขึ้นซ้ำ', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();

      service.serverEmit(
        'new_message',
        messageFrom(otherUser, 'ครั้งเดียว', id: 7),
      );
      service.serverEmit(
        'new_message',
        messageFrom(otherUser, 'ครั้งเดียว', id: 7),
      );

      expect(controller.messages.length, 1);
    });

    test('อีกฝั่งอ่านแล้ว -> ข้อความของเราขึ้น "อ่านแล้ว"', () async {
      final controller = ChatRoomController(roomId, service: service);
      await controller.start();
      await controller.send('อ่านหรือยัง');
      expect(controller.messages.last.isRead, isFalse);

      service.serverEmit('messages_read', {
        'conversation_id': roomId,
        'reader_id': otherUser,
      });

      expect(controller.messages.last.isRead, isTrue);
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

  group('ประวัติแชทหลัง logout แล้ว login ใหม่', () {
    // FakeChatService เก็บข้อความที่ส่งไว้ใน history (เหมือนตาราง messages ใน MySQL)
    // ตัว server จริง + DB จริง ทดสอบซ้ำอีกชั้นใน node test_chat.js
    void logout() => Session.clear();
    void loginAgain() {
      Session.token = 'new-token';
      Session.userId = me;
      Session.loggedIn.value = true;
    }

    test(
      'ส่งข้อความ -> อีกฝั่งอ่าน -> logout -> login ใหม่ -> ข้อความยังอยู่และยังขึ้น "อ่านแล้ว"',
      () async {
        service.history = [messageFrom(otherUser, 'สวัสดีครับ', id: 1)];

        // --- รอบแรก: เปิดห้อง ส่งข้อความ ---
        final first = ChatRoomController(roomId, service: service);
        await first.start();
        await first.send('ห้องยังว่างไหมครับ');
        service.otherSideReads(roomId, otherUser); // เจ้าของหอเปิดอ่าน
        expect(first.messages.last.isRead, isTrue);

        // --- logout: ปิดห้อง ---
        first.dispose();
        logout();

        // --- login ใหม่ แล้วเปิดห้องเดิม ---
        loginAgain();
        final second = ChatRoomController(roomId, service: service);
        addTearDown(second.dispose);
        await second.start();

        expect(second.loading, isFalse);
        expect(second.messages.map((m) => m.text), [
          'สวัสดีครับ',
          'ห้องยังว่างไหมครับ',
        ]);
        final mine = second.messages.last;
        expect(
          second.isMine(mine),
          isTrue,
          reason: 'ข้อความที่เราส่งต้องยังเป็นของเรา (ฝั่งขวา)',
        );
        expect(mine.isRead, isTrue, reason: 'สถานะอ่านแล้วต้องยังอยู่');
        expect(second.isMine(second.messages.first), isFalse);
      },
    );

    test(
      'login ใหม่ด้วยบัญชีอื่น -> ข้อความเดิมไม่ใช่ของเรา (แยกฝั่งถูก)',
      () async {
        final first = ChatRoomController(roomId, service: service);
        await first.start();
        await first.send('จากผู้เช่า');
        first.dispose();
        logout();

        // เจ้าของหอ login เข้ามาเปิดห้องเดียวกัน
        Session.token = 'owner-token';
        Session.userId = otherUser;
        Session.loggedIn.value = true;
        final ownerRoom = ChatRoomController(roomId, service: service);
        addTearDown(ownerRoom.dispose);
        await ownerRoom.start();

        expect(ownerRoom.messages.single.text, 'จากผู้เช่า');
        expect(ownerRoom.isMine(ownerRoom.messages.single), isFalse);
      },
    );

    test(
      'ส่งไม่สำเร็จ -> login ใหม่แล้วไม่มีข้อความนั้น (ไม่ได้บันทึก)',
      () async {
        service.serverAcceptsMessage = false;
        final first = ChatRoomController(roomId, service: service);
        await first.start();
        expect(await first.send('ส่งไม่ออก'), isFalse);
        first.dispose();
        logout();

        loginAgain();
        final second = ChatRoomController(roomId, service: service);
        addTearDown(second.dispose);
        await second.start();

        expect(second.messages, isEmpty);
      },
    );
  });

  group('ChatListController', () {
    test('ยังไม่ login -> ไม่โหลดรายการ', () {
      Session.clear();
      final controller = ChatListController(service: service);
      addTearDown(controller.dispose);

      controller.start();

      expect(service.fetchConversationsCount, 0);
    });

    test('login แล้ว -> โหลดรายการห้องแชท', () async {
      service.conversationList = [
        {
          'id': roomId,
          'other_name': 'เจ้าของหอทดสอบ',
          'dorm_name': 'หอรวย เธะ',
          'unread': 2,
        },
      ];
      final controller = ChatListController(service: service);
      addTearDown(controller.dispose);

      controller.start();
      await flush();

      expect(controller.loading, isFalse);
      expect(controller.conversations.single.unread, 2);
    });

    test('สร้างหน้าก่อน login แล้วค่อย login -> โหลดรายการเอง', () async {
      // NavigationShell สร้างหน้าแชทไว้ตั้งแต่เปิดแอป (ก่อน login)
      Session.clear();
      service.conversationList = [
        {
          'id': roomId,
          'other_name': 'เจ้าของหอทดสอบ',
          'dorm_name': 'หอรวย เธะ',
          'unread': 0,
        },
      ];
      final controller = ChatListController(service: service);
      addTearDown(controller.dispose);
      controller.start();
      expect(service.fetchConversationsCount, 0);

      Session.token = 'fake-token';
      Session.userId = me;
      Session.loggedIn.value = true; // เหมือนที่ AuthService.login ทำ
      await flush();

      expect(service.fetchConversationsCount, 1);
      expect(controller.conversations.length, 1);
    });

    test('logout -> ล้างรายการ และเลิกฟังข้อความใหม่', () async {
      Session.loggedIn.value = true;
      service.conversationList = [
        {
          'id': roomId,
          'other_name': 'เจ้าของหอทดสอบ',
          'dorm_name': 'หอรวย เธะ',
          'unread': 0,
        },
      ];
      final controller = ChatListController(service: service);
      addTearDown(controller.dispose);
      controller.start();
      await flush();
      expect(controller.conversations, isNotEmpty);

      Session.clear();

      expect(controller.conversations, isEmpty);
      expect(service.handlers.containsKey('conversation_updated'), isFalse);
    });

    test('มีข้อความใหม่ (conversation_updated) -> โหลดรายการใหม่เอง', () async {
      final controller = ChatListController(service: service);
      addTearDown(controller.dispose);
      controller.start();
      await flush();
      expect(service.fetchConversationsCount, 1);

      service.serverEmit('conversation_updated', {'conversation_id': roomId});
      await flush();

      expect(service.fetchConversationsCount, 2);
    });
  });
}
