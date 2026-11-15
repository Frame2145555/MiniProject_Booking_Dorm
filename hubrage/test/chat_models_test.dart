// Unit test ของ Model แชท (lib/models/chat_models.dart) — ไม่ต้องมี server
// วิธีรัน: flutter test test/chat_models_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/chat_models.dart';

void main() {
  group('ChatMessage.fromJson', () {
    test('แปลง JSON ข้อความจาก server ได้ครบทุกช่อง', () {
      final msg = ChatMessage.fromJson({
        'id': 7,
        'conversation_id': 10,
        'sender_id': 2,
        'text': 'ห้องว่างไหมครับ',
        'sent_at': '2026-11-09T08:00:00.000Z',
        'read_at': null,
      });

      expect(msg.id, 7);
      expect(msg.conversationId, 10);
      expect(msg.senderId, 2);
      expect(msg.text, 'ห้องว่างไหมครับ');
      expect(msg.sentAt, DateTime.utc(2026, 11, 9, 8).toLocal()); // แปลงเป็นเวลาเครื่อง
      expect(msg.isRead, isFalse);
    });

    test('รองรับชื่อช่อง message_text (ชื่อคอลัมน์ใน MySQL) และ id ที่เป็น String', () {
      final msg = ChatMessage.fromJson({
        'id': '7',
        'conversation_id': '10',
        'sender_id': '2',
        'message_text': 'สวัสดี',
        'sent_at': '2026-11-09T08:00:00.000Z',
        'read_at': '2026-11-09T08:05:00.000Z',
      });
      expect(msg.id, 7);
      expect(msg.text, 'สวัสดี');
      expect(msg.isRead, isTrue);
    });

    test('ข้อมูลขาด/เพี้ยน ไม่ crash', () {
      final msg = ChatMessage.fromJson({'id': 1, 'sent_at': 'not-a-date'});
      expect(msg.text, '');
      expect(msg.sentAt, isNull);
      expect(msg.timeLabel, '');
    });

    test('tryParse: event ที่ไม่ใช่ข้อความ -> null', () {
      expect(ChatMessage.tryParse(null), isNull);
      expect(ChatMessage.tryParse('hello'), isNull);
      expect(ChatMessage.tryParse({'text': 'ไม่มี id'}), isNull);
      expect(ChatMessage.tryParse({'id': 1, 'conversation_id': 10})?.id, 1);
    });

    test('isSentBy: บอกได้ว่าใครเป็นคนส่ง', () {
      final msg = ChatMessage.fromJson({'id': 1, 'sender_id': 5});
      expect(msg.isSentBy(5), isTrue);
      expect(msg.isSentBy(6), isFalse);
    });

    test('toJson -> fromJson ได้ข้อมูลเดิม', () {
      final original = ChatMessage(
        id: 3,
        conversationId: 10,
        senderId: 1,
        text: 'ทดสอบ',
        sentAt: DateTime(2026, 11, 9, 15, 30),
      );
      final copy = ChatMessage.fromJson(original.toJson());
      expect(copy.id, 3);
      expect(copy.text, 'ทดสอบ');
      expect(copy.sentAt, original.sentAt);
      expect(copy.isRead, isFalse);
    });
  });

  group('ChatConversation.fromJson', () {
    test('แปลง JSON รายการห้องแชทจาก server', () {
      final conv = ChatConversation.fromJson({
        'id': 10,
        'dorm_id': 1,
        'dorm_name': 'หอรวย เธะ',
        'other_name': 'สมชาย',
        'last_message': 'ว่างครับ',
        'last_sent_at': '2020-01-15T03:30:00.000Z',
        'unread': 2,
      });
      expect(conv.id, 10);
      expect(conv.dormName, 'หอรวย เธะ');
      expect(conv.otherName, 'สมชาย');
      expect(conv.preview, 'ว่างครับ');
      expect(conv.hasUnread, isTrue);
      expect(conv.timeLabel, '15/1');
    });

    test('ห้องที่ยังไม่มีข้อความ', () {
      final conv = ChatConversation.fromJson({'id': 11, 'dorm_name': 'หอ', 'other_name': 'A', 'unread': 0});
      expect(conv.preview, 'ยังไม่มีข้อความ');
      expect(conv.hasUnread, isFalse);
      expect(conv.timeLabel, '');
    });
  });
}
