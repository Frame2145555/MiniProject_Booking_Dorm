import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session.dart';

class NotificationException implements Exception {
  final String message;
  const NotificationException(this.message);

  @override
  String toString() => message;
}

/// แจ้งเตือน 1 รายการ (GET /api/notifications ใน notification_routes.js)
class NotificationItem {
  final int id;
  final String type; // เช่น deposit_approved = แอดมินตรวจสอบค่ามัดจำแล้ว
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: int.tryParse('${json['id']}') ?? 0,
      type: '${json['type'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      isRead: json['isRead'] == true || json['isRead'] == 1,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
    );
  }
}

class NotificationList {
  final List<NotificationItem> items;
  final int unread;
  const NotificationList(this.items, this.unread);
}

/// Service ของกระดิ่งแจ้งเตือน: คุยกับ server อย่างเดียว (/api/notifications)
/// unread = จำนวนที่ยังไม่อ่าน ใช้โชว์จุดแดงที่กระดิ่ง (ทุกบทบาทใช้ร่วมกัน)
class NotificationService {
  NotificationService({http.Client? client}) : _client = client;

  static final NotificationService instance = NotificationService();

  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  final http.Client? _client;

  /// อัปเดตจำนวนที่ยังไม่อ่าน (เงียบ ๆ ไม่แจ้ง error เพราะถูกเรียกเป็นระยะ)
  Future<void> refreshUnread() async {
    if (!Session.isLoggedIn) {
      unread.value = 0;
      return;
    }
    try {
      unread.value = (await fetch()).unread;
    } catch (_) {}
  }

  Future<NotificationList> fetch() async {
    final res = await _send('GET', '/api/notifications');
    final raw = res['data'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <NotificationItem>[];
    final count = int.tryParse('${res['unread']}') ?? 0;
    unread.value = count;
    return NotificationList(items, count);
  }

  Future<void> markAllRead() async {
    await _send('POST', '/api/notifications/read-all');
    unread.value = 0;
  }

  Future<Map<String, dynamic>> _send(String method, String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (Session.isLoggedIn) 'Authorization': 'Bearer ${Session.token}',
    };
    final c = _client ?? http.Client();
    http.Response response;
    try {
      final request = switch (method) {
        'GET' => c.get(uri, headers: headers),
        'POST' => c.post(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method'),
      };
      response = await request.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw NotificationException(
        'เชื่อมต่อ ${ApiConfig.baseUrl} ไม่ได้ (เปิด server / ngrok หรือยัง?)',
      );
    } finally {
      if (_client == null) c.close();
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw const NotificationException('กรุณาเข้าสู่ระบบก่อน');
      }
      throw NotificationException(
        (data['message'] ?? data['error'])?.toString() ??
            'โหลดการแจ้งเตือนไม่สำเร็จ (${response.statusCode})',
      );
    }
    return data;
  }
}
