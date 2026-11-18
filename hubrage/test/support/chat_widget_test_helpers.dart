import 'package:flutter/material.dart';

import '../../lib/services/session.dart';
import '../../lib/theme/app_theme.dart';

import 'fake_chat_service.dart';

const chatTestMe = 1;
const chatTestOtherUser = 2;
const chatTestRoomId = 10;

Widget chatTestApp(Widget page) =>
    MaterialApp(theme: AppTheme.light(), home: page);

/// ข้อความแจ้งเตือนจากระบบ (เช่น แอดมินอนุมัติค่ามัดจำ) -> แสดงเป็นกล่องกลางจอ
Map<String, dynamic> chatTestSystemMessage(int id, String text) => {
  ...chatTestMessage(id, chatTestOtherUser, '[แจ้งเตือนจากระบบ] $text'),
  'type': 'system',
};

Map<String, dynamic> chatTestMessage(int id, int senderId, String text) => {
  'id': id,
  'conversation_id': chatTestRoomId,
  'sender_id': senderId,
  'text': text,
  'sent_at': '2026-11-09T08:00:00.000Z',
  'read_at': null,
};

Map<String, dynamic> chatTestConversation({
  String lastMessage = 'ว่างครับ',
  int unread = 0,
  String otherName = 'เจ้าของหอทดสอบ', // ฝั่งเจ้าของหอส่ง 'ผู้เช่าทดสอบ' แทน
  String dormName = 'หอรวย เธะ',
}) => {
  'id': chatTestRoomId,
  'other_name': otherName,
  'dorm_name': dormName,
  'last_message': lastMessage,
  'unread': unread,
};

void loginChatTestUser({int userId = chatTestMe, String role = 'tenant'}) {
  Session.token = 'fake-token';
  Session.userId = userId;
  Session.role = role;
  Session.fullName = role == 'seller' ? 'เจ้าของหอทดสอบ' : 'ผู้เช่าทดสอบ';
  Session.loggedIn.value = true;
}

FakeChatService createChatTestService() => FakeChatService(myId: chatTestMe);
