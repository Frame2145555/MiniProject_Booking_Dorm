import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_config.dart';
import 'session.dart';

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

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/conversations'), headers: _headers);
      if (res.statusCode != 200) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } catch (e) {
      debugPrint('fetchConversations error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int conversationId) async {
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/conversations/$conversationId/messages'),
          headers: _headers);
      if (res.statusCode != 200) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } catch (e) {
      debugPrint('fetchMessages error: $e');
      return [];
    }
  }
}

/// แปลงเวลาจาก server เป็นข้อความสั้นๆ: วันนี้ -> 14:05, วันอื่น -> 9/11
String formatChatTime(dynamic value) {
  if (value == null) return '';
  final time = DateTime.tryParse(value.toString())?.toLocal();
  if (time == null) return '';
  final now = DateTime.now();
  final hhmm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (time.year == now.year && time.month == now.month && time.day == now.day) {
    return hhmm;
  }
  return '${time.day}/${time.month}';
}