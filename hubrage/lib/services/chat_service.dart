import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_models.dart';
import 'api_config.dart';
import 'session.dart';

/// Service (MVC) ของแชท: คุยกับ server อย่างเดียว (socket + REST) ไม่มี logic
/// ข้อมูลที่ดึงมาแปลงเป็น model (ChatMessage / ChatConversation) ก่อนส่งให้ controller
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  io.Socket? _socket;
  io.Socket? get socket => _socket; // null = ยังไม่ login

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.token}',
        'ngrok-skip-browser-warning': 'true',
      };

  void connect() {
    if (_socket != null || !Session.isLoggedIn) return;
    _socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': Session.token})
          .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
          .enableForceNew() // login ใหม่ด้วยคนอื่น ต้องได้ socket ใหม่ ไม่ใช้ของเก่าที่ cache ไว้
          .disableAutoConnect()
          .build(),
    );
    _socket!.onConnectError((err) => debugPrint('socket connect error: $err'));
    _socket!.connect();
  }

  void disconnect() {   // เรียกตอน logout
    _socket?.dispose();
    _socket = null;
  }

  //------------------- Socket --------------
  /// ฟัง event จาก server คืนฟังก์ชันไว้เรียกตอนเลิกฟัง (ยังไม่ login = ไม่ทำอะไร)
  Function() listen(String event, void Function(dynamic data) handler) {
    final s = _socket;
    if (s == null) return () {};
    return s.on(event, handler);
  }

  void joinConversation(int conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void markRead(int conversationId) {
    _socket?.emit('mark_read', conversationId);
  }

  /// ส่งข้อความ แล้วเรียก done(true/false) เมื่อ server ตอบกลับ (รอได้สูงสุด 10 วินาที)
  void sendMessage(int conversationId, String text, void Function(bool ok) done) {
    final s = _socket;
    if (s == null) {
      done(false);
      return;
    }

    var finished = false;
    final timer = Timer(const Duration(seconds: 10), () {
      if (finished) return;
      finished = true;
      done(false);
    });

    s.emitWithAck(
      'send_message',
      {'conversation_id': conversationId, 'text': text},
      ack: (res) {
        if (finished) return;
        finished = true;
        timer.cancel();
        done(res is Map && res['ok'] == true);
      },
    );
  }

  //------------------- REST --------------
  Future<int?> openConversation(int dormId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/conversations'),
        headers: _headers,
        body: jsonEncode({'dorm_id': dormId}),
      );
      if (res.statusCode != 200) {
        debugPrint('openConversation ${res.statusCode}: ${res.body}');
        return null;
      }
      return jsonDecode(res.body)['id'];
    } catch (e) {
      debugPrint('openConversation error: $e');
      return null;
    }
  }

  /// รายการห้องแชทของเรา (JSON -> ChatConversation)
  Future<List<ChatConversation>> fetchConversations() async {
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/conversations'), headers: _headers);
      if (res.statusCode != 200) return [];
      return _decodeList(res.body).map(ChatConversation.fromJson).toList();
    } catch (e) {
      debugPrint('fetchConversations error: $e');
      return [];
    }
  }

  /// ข้อความเก่า 50 ข้อความล่าสุดของห้อง (JSON -> ChatMessage)
  Future<List<ChatMessage>> fetchMessages(int conversationId) async {
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/conversations/$conversationId/messages'),
          headers: _headers);
      if (res.statusCode != 200) return [];
      return _decodeList(res.body).map(ChatMessage.fromJson).toList();
    } catch (e) {
      debugPrint('fetchMessages error: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _decodeList(String body) {
    final data = jsonDecode(body);
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
