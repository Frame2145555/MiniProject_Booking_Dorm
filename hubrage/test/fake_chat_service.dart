// ChatService ปลอม ใช้ร่วมกันใน unit test และ widget test
// ทำตัวเหมือน server: จำว่าถูกเรียกอะไร และจำลอง event จาก server ได้ (serverEmit)
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/chat_service.dart';

/// ChatService ปลอม: จำว่าถูกเรียกอะไรบ้าง และจำลอง event จาก server ได้
class FakeChatService extends Fake implements ChatService {
  final int myId; // id ของคนที่ login อยู่ (ใช้เป็นผู้ส่งตอน sendMessage)
  FakeChatService({this.myId = 1});

  final Map<String, void Function(dynamic)> handlers = {};
  final List<int> joined = [];
  final List<int> markedRead = [];
  final List<String> sentTexts = [];
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> conversationList = [];
  int fetchConversationsCount = 0;
  bool serverAcceptsMessage = true;
  int _nextId = 100;

  /// จำลองว่า server ส่ง event นี้มา
  void serverEmit(String event, dynamic data) => handlers[event]?.call(data);

  @override
  Function() listen(String event, void Function(dynamic data) handler) {
    handlers[event] = handler;
    return () => handlers.remove(event);
  }

  @override
  void joinConversation(int conversationId) => joined.add(conversationId);

  @override
  void markRead(int conversationId) => markedRead.add(conversationId);

  @override
  void sendMessage(int conversationId, String text, void Function(bool ok) done) {
    sentTexts.add(text);
    if (!serverAcceptsMessage) {
      done(false);
      return;
    }
    done(true);
    // เหมือน server จริง: ส่ง new_message กลับมาให้ทุกคนในห้อง รวมถึงคนส่ง
    serverEmit('new_message', {
      'id': _nextId++,
      'conversation_id': conversationId,
      'sender_id': myId,
      'text': text,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'read_at': null,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMessages(int conversationId) async => history;

  @override
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    fetchConversationsCount++;
    return conversationList;
  }
}