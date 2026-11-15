// Model (MVC) ของระบบแชท
// หน้าที่: บอกว่าข้อมูลแชท 1 ชิ้นมีอะไรบ้าง + แปลง JSON จาก server ให้เป็น object (fromJson)
// Model ไม่ได้ไปดึงข้อมูลเอง -> ChatService เป็นคนดึง แล้วส่ง JSON มาให้ model แปลง
//
// JSON ที่ server ส่งมา (ดู chat_routes.js / chat_socket.js):
//   ข้อความ  { id, conversation_id, sender_id, text, type, sent_at, read_at }
//            type: 'text' = คนพิมพ์ / 'system' = แจ้งเตือนจากระบบ (เช่น แอดมินอนุมัติการจอง)
//   ห้องแชท  { id, dorm_id, dorm_name, other_name, last_message, last_sent_at, unread, updated_at }

/// แปลงค่าจาก JSON เป็น int (server อาจส่งมาเป็น int / double / String)
int _toInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// แปลงเวลาจาก server (String แบบ ISO หรือ DateTime) เป็นเวลาเครื่อง / null ถ้าไม่มีหรือเพี้ยน
DateTime? _toTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// เวลาแบบสั้นสำหรับแชท: วันนี้ -> 14:05, วันอื่น -> 9/11
/// รับได้ทั้ง DateTime และ String จาก server (ค่าเพี้ยน / null -> '')
String formatChatTime(Object? value) {
  final time = _toTime(value);
  if (time == null) return '';
  final now = DateTime.now();
  if (time.year == now.year && time.month == now.month && time.day == now.day) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
  return '${time.day}/${time.month}';
}

/// ข้อความ 1 ข้อความในห้องแชท (ตาราง messages)
class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String text;
  final DateTime? sentAt;

  /// 'text' = ข้อความที่คนพิมพ์ / 'system' = แจ้งเตือนจากระบบ (แสดงเป็นกล่องกลางจอ)
  final String type;

  /// เวลาที่อีกฝั่งอ่าน (null = ยังไม่อ่าน) เปลี่ยนได้เมื่อ server ส่ง 'messages_read' มา
  DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.sentAt,
    this.readAt,
    this.type = 'text',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _toInt(json['id']),
        conversationId: _toInt(json['conversation_id']),
        senderId: _toInt(json['sender_id']),
        // REST ส่งมาเป็น text / ในตาราง MySQL ชื่อ message_text -> รองรับทั้งคู่
        text: (json['text'] ?? json['message_text'] ?? '').toString(),
        sentAt: _toTime(json['sent_at']),
        readAt: _toTime(json['read_at']),
        type: json['type']?.toString() == 'system' ? 'system' : 'text',
      );

  /// สำหรับ event จาก socket (ข้อมูลเป็น dynamic) -> null ถ้าหน้าตาไม่ใช่ข้อความ
  static ChatMessage? tryParse(Object? data) {
    if (data is! Map || data['id'] == null) return null;
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  bool get isRead => readAt != null;

  /// ข้อความแจ้งเตือนจากระบบ (การจอง / การชำระเงิน)
  bool get isSystem => type == 'system';

  /// ข้อความนี้ส่งโดย user คนนี้ไหม
  bool isSentBy(int userId) => senderId == userId;

  /// เวลาที่แสดงใต้ฟองข้อความ
  String get timeLabel => formatChatTime(sentAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'type': type,
        'sent_at': sentAt?.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
      };
}

/// ห้องแชท 1 ห้องในหน้ารายการแชท (ตาราง conversations + ข้อมูลสรุปจาก server)
class ChatConversation {
  final int id;
  final int dormId;
  final String dormName;

  /// ชื่อคู่สนทนา (เราเป็นผู้เช่า = ชื่อเจ้าของหอ / เราเป็นเจ้าของหอ = ชื่อผู้เช่า)
  final String otherName;
  final String? lastMessage;
  final DateTime? lastSentAt;

  /// จำนวนข้อความจากอีกฝั่งที่เรายังไม่ได้อ่าน
  final int unread;

  const ChatConversation({
    required this.id,
    required this.dormId,
    required this.dormName,
    required this.otherName,
    this.lastMessage,
    this.lastSentAt,
    this.unread = 0,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
        id: _toInt(json['id']),
        dormId: _toInt(json['dorm_id']),
        dormName: (json['dorm_name'] ?? '').toString(),
        otherName: (json['other_name'] ?? '').toString(),
        lastMessage: json['last_message']?.toString(),
        lastSentAt: _toTime(json['last_sent_at']),
        unread: _toInt(json['unread']),
      );

  bool get hasUnread => unread > 0;

  /// ข้อความที่โชว์ในรายการ (ยังไม่เคยคุย -> 'ยังไม่มีข้อความ')
  String get preview =>
      lastMessage?.replaceFirst('[แจ้งเตือนจากระบบ] ', 'แจ้งเตือน: ').replaceAll('\n', ' ') ??
      'ยังไม่มีข้อความ';

  String get timeLabel => formatChatTime(lastSentAt);
}
