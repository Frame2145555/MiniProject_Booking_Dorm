import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';
import '../services/session.dart';

// Controller (MVC) ของระบบแชท
// View แค่แสดงผล + ส่งการกดของผู้ใช้มาที่นี่ / คุยกับ server ผ่าน ChatService
// รับ ChatService เข้ามาทาง constructor เพื่อให้ตอน unit test ส่งตัวปลอมเข้ามาแทนได้

//=================== หน้าห้องแชท 1 ห้อง =======================
class ChatRoomController extends ChangeNotifier {
  final int conversationId;
  final ChatService _service;

  ChatRoomController(this.conversationId, {ChatService? service})
      : _service = service ?? ChatService.instance;

  final List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool sending = false;

  final List<Function()> _removeListeners = [];
  bool _disposed = false;

  bool isMine(Map<String, dynamic> msg) => msg['sender_id'] == Session.userId;

  /// เรียกครั้งเดียวตอนเปิดห้อง
  Future<void> start() async {
    _removeListeners.add(_service.listen('new_message', onNewMessage));
    _removeListeners.add(_service.listen('messages_read', onMessagesRead));
    // ถ้าเน็ตหลุดแล้วต่อใหม่ server จะลืมว่าเราอยู่ห้องไหน ต้อง join ซ้ำ
    _removeListeners.add(_service.listen('connect', (_) => _join()));
    _join();
    await loadHistory();
  }

  void _join() {
    _service.joinConversation(conversationId);
    _service.markRead(conversationId);
  }

  Future<void> loadHistory() async {
    final history = await _service.fetchMessages(conversationId);
    if (_disposed) return;
    // ข้อความที่เข้ามาทาง socket ระหว่างรอโหลด ให้เก็บไว้ต่อท้าย (ไม่ให้ซ้ำ)
    final historyIds = history.map((m) => m['id']).toSet();
    final arrivedMeanwhile =
        messages.where((m) => !historyIds.contains(m['id'])).toList();
    messages
      ..clear()
      ..addAll(history)
      ..addAll(arrivedMeanwhile);
    loading = false;
    _notify();
    _service.markRead(conversationId);
  }

  /// server ส่ง 'new_message' มา
  void onNewMessage(dynamic data) {
    if (data is! Map || _disposed) return;
    final msg = Map<String, dynamic>.from(data);
    if (msg['conversation_id'] != conversationId) return;
    if (messages.any((m) => m['id'] == msg['id'])) return;

    messages.add(msg);
    _notify();
    // อีกฝั่งส่งมาตอนเราเปิดห้องอยู่ = อ่านแล้ว
    if (!isMine(msg)) _service.markRead(conversationId);
  }

  /// server ส่ง 'messages_read' มา (อีกฝั่งอ่านข้อความเราแล้ว)
  void onMessagesRead(dynamic data) {
    if (data is! Map || _disposed) return;
    if (data['conversation_id'] != conversationId) return;
    if (data['reader_id'] == Session.userId) return;
    for (final m in messages) {
      if (isMine(m) && m['read_at'] == null) {
        m['read_at'] = DateTime.now().toIso8601String();
      }
    }
    _notify();
  }

  /// ส่งข้อความ: true = ส่งสำเร็จ, false = ส่งไม่สำเร็จ, null = ไม่ได้ส่ง (ข้อความว่าง / กำลังส่งอยู่)
  /// ข้อความจะเด้งเข้า messages เองทาง 'new_message' (server ส่งให้ทุกคนในห้อง รวมถึงเรา)
  Future<bool?> send(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty || sending) return Future.value(null);

    sending = true;
    _notify();
    final result = Completer<bool>();
    _service.sendMessage(conversationId, text, (ok) {
      sending = false;
      _notify();
      result.complete(ok);
    });
    return result.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final remove in _removeListeners) {
      remove();
    }
    super.dispose();
  }
}

//=================== หน้ารายการห้องแชท =======================
class ChatListController extends ChangeNotifier {
  final ChatService _service;

  ChatListController({ChatService? service})
      : _service = service ?? ChatService.instance;

  List<Map<String, dynamic>> conversations = [];
  bool loading = true;

  Function()? _removeListener;
  bool _disposed = false;

  /// เรียกครั้งเดียวตอนสร้างหน้า (หน้าอาจถูกสร้างตั้งแต่ก่อน login)
  void start() {
    Session.loggedIn.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  /// login / logout -> เริ่มฟังห้องแชทของคนใหม่ หรือล้างรายการ
  void _onSessionChanged() {
    if (_disposed) return;
    _removeListener?.call();
    _removeListener = null;
    conversations = [];
    loading = true;
    if (!Session.isLoggedIn) {
      notifyListeners();
      return;
    }
    // มีข้อความใหม่ในห้องไหนก็ตาม server จะส่ง 'conversation_updated' มา -> โหลดรายการใหม่
    _removeListener = _service.listen('conversation_updated', (_) => load());
    notifyListeners();
    load();
  }

  Future<void> load() async {
    if (!Session.isLoggedIn) return;
    final list = await _service.fetchConversations();
    if (_disposed || !Session.isLoggedIn) return; // logout ระหว่างรอ = ทิ้งผลลัพธ์
    conversations = list;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    Session.loggedIn.removeListener(_onSessionChanged);
    _removeListener?.call();
    super.dispose();
  }
}
