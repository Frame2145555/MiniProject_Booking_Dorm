// ChatService ปลอมด้วย mocktail ใช้ร่วมกันใน unit test และ widget test ของระบบแชท
//
//   final server = ChatTestServer();          // MockChatService + stub ที่ทำตัวเหมือน server
//   ChatRoomController(roomId, service: server.service);
//   server.serverEmit('new_message', {...});  // จำลอง event จาก socket
//   verify(() => server.service.joinConversation(roomId)).called(1);
//
// อยากให้ server ตอบแบบอื่นในเทสต์ไหน ก็ when(...) ทับได้เลย (stub ที่ตั้งทีหลังชนะ)
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../lib/models/chat_models.dart';
import '../../lib/services/chat_service.dart';

class MockChatService extends Mock implements ChatService {}

/// any() กับพารามิเตอร์ที่เป็นฟังก์ชันต้องมีค่าสำรองให้ mocktail
/// (mocktail เลือกค่าสำรองจากชนิดของค่าที่ส่งเข้าไปเอง ไม่ต้องใส่ <type>)
void registerChatFallbackValues() {
  registerFallbackValue((dynamic _) {}); // handler ของ listen(event, handler)
  registerFallbackValue((bool _) {}); // callback ของ sendMessage(..., done)
}

/// ตัวแทน server แชท: เก็บข้อมูลในหน่วยความจำ แล้วตั้ง stub ของ MockChatService ให้ตอบจากข้อมูลนี้
class ChatTestServer {
  ChatTestServer({this.myId = 1}) {
    registerChatFallbackValues();
    _stubLikeRealServer();
  }

  final MockChatService service = MockChatService();

  /// id ของคนที่ login อยู่ (ใช้เป็นผู้ส่งตอน sendMessage)
  int myId;

  /// event ที่หน้าจอ/controller ฟังอยู่ (ชื่อ event -> handler)
  final Map<String, void Function(dynamic)> handlers = {};

  /// "ตาราง messages" ในรูป JSON เหมือนที่ server ส่งมา
  List<Map<String, dynamic>> history = [];

  /// รายการห้องแชทที่ GET /api/chat/conversations จะคืน
  List<Map<String, dynamic>> conversationList = [];

  int _nextId = 100;

  void _stubLikeRealServer() {
    when(() => service.listen(any(), any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments[0] as String;
      handlers[event] =
          invocation.positionalArguments[1] as void Function(dynamic);
      return () => handlers.remove(event);
    });
    when(() => service.joinConversation(any())).thenReturn(null);
    when(() => service.markRead(any())).thenReturn(null);
    when(() => service.fetchMessages(any())).thenAnswer(
      (_) async => history.map(ChatMessage.fromJson).toList(),
    );
    when(() => service.fetchConversations()).thenAnswer(
      (_) async => conversationList.map(ChatConversation.fromJson).toList(),
    );
    when(() => service.sendMessage(any(), any(), any())).thenAnswer((
      invocation,
    ) {
      final conversationId = invocation.positionalArguments[0] as int;
      final text = invocation.positionalArguments[1] as String;
      final done = invocation.positionalArguments[2] as void Function(bool);
      final saved = {
        'id': _nextId++,
        'conversation_id': conversationId,
        'sender_id': myId,
        'text': text,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'read_at': null,
      };
      // เหมือน server จริง: บันทึกลง DB แล้วส่ง new_message กลับมาให้ทุกคนในห้อง รวมถึงคนส่ง
      history.add(saved);
      done(true);
      serverEmit('new_message', Map<String, dynamic>.from(saved));
    });
  }

  /// ให้ server ปฏิเสธข้อความ (ack = false และไม่บันทึก)
  void rejectMessages() {
    when(() => service.sendMessage(any(), any(), any())).thenAnswer((
      invocation,
    ) {
      (invocation.positionalArguments[2] as void Function(bool))(false);
    });
  }

  /// จำลองว่า server ส่ง event นี้มาทาง socket
  void serverEmit(String event, dynamic data) => handlers[event]?.call(data);

  /// จำลอง: อีกฝั่ง (readerId) เปิดห้องอ่านข้อความ
  /// -> ใส่ read_at ใน "DB" ให้ข้อความที่คนอื่นส่ง + ส่ง messages_read มา (เหมือน chat_socket.js)
  void otherSideReads(int conversationId, int readerId) {
    for (final m in history) {
      if (m['conversation_id'] == conversationId &&
          m['sender_id'] != readerId &&
          m['read_at'] == null) {
        m['read_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    serverEmit('messages_read', {
      'conversation_id': conversationId,
      'reader_id': readerId,
    });
  }
}
