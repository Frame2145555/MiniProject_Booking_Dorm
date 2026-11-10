import 'package:flutter/material.dart';

import 'admin_console_state.dart';

/// ข้อมูลหอพักตัวอย่างที่ผู้เช่าเห็น + ตัวช่วยรวมหอที่แอดมินอนุมัติแล้ว
/// (ย้ายมาจาก HomeView เพื่อให้หน้าแรก / ค้นหา / รายการโปรด ใช้ร่วมกัน)
class DormCatalog {
  DormCatalog._();

  static const List<Map<String, dynamic>> baseDorms = [
    {
      'id': 'dorm_1',
      'title': 'หอรวย เธะ',
      'price': '5,000 - 8,500',
      'minPrice': 5000,
      'maxPrice': 8500,
      'rating': '4.7',
      'phone': '081-234-5678',
      'location': 'ซอยรามคำแหง 24 • ใกล้มหาวิทยาลัยรามคำแหง',
      'tags': ['แอร์', 'Wi-Fi', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_2',
      'title': 'หออิสลาม แกรนด์',
      'price': '6,500 - 9,000',
      'minPrice': 6500,
      'maxPrice': 9000,
      'rating': '4.0',
      'phone': '089-876-5432',
      'location': 'ซอยรามคำแหง 24 • ใกล้ Airport Link หัวหมาก',
      'tags': ['แอร์', 'กล้องวงจรปิด', 'ลิฟต์'],
    },
    {
      'id': 'dorm_3',
      'title': 'HU 24 อพาร์ตเมนต์',
      'price': '7,200 - 11,000',
      'minPrice': 7200,
      'maxPrice': 11000,
      'rating': '4.9',
      'phone': '082-333-4455',
      'location': 'รามคำแหง 24 แยก 2 • ใกล้เอแบค ABAC',
      'tags': ['ฟิตเนส', 'สระว่ายน้ำ', 'เลี้ยงสัตว์ได้', 'แอร์', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_4',
      'title': 'กรีนวิลล์ คอนโดเช่า',
      'price': '4,800 - 7,000',
      'minPrice': 4800,
      'maxPrice': 7000,
      'rating': '4.5',
      'phone': '086-555-6677',
      'location': 'ซอยหลังราม • ใกล้สนามราชมังคลาฯ และ MRT',
      'tags': ['เครื่องซักผ้า', 'รปภ. 24ชม.', 'แอร์', 'เลี้ยงสัตว์ได้'],
    },
  ];

  static const List<Map<String, dynamic>> amenities = [
    {'label': 'แอร์', 'icon': Icons.ac_unit},
    {'label': 'เลี้ยงสัตว์ได้', 'icon': Icons.pets},
    {'label': 'ที่จอดรถ', 'icon': Icons.directions_car},
    {'label': 'Wi-Fi', 'icon': Icons.wifi},
    {'label': 'กล้องวงจรปิด', 'icon': Icons.videocam},
    {'label': 'ลิฟต์', 'icon': Icons.elevator},
    {'label': 'ฟิตเนส', 'icon': Icons.fitness_center},
    {'label': 'สระว่ายน้ำ', 'icon': Icons.pool},
    {'label': 'เครื่องซักผ้า', 'icon': Icons.local_laundry_service},
    {'label': 'รปภ. 24ชม.', 'icon': Icons.security},
  ];

  /// หอทั้งหมดที่ผู้เช่าควรเห็น (ตัดหอที่ปิดประกาศ/ยังไม่อนุมัติ/ถูกระงับออก)
  static List<Map<String, dynamic>> visibleDorms(AdminConsoleState? state) {
    final approvedOwnerDorms = (state?.approvedDorms ?? const []).map(
      (request) => <String, dynamic>{
        ...request,
        'id': request['dormId'],
        'title': request['dormName'],
        'price': '${request['priceMin']} - ${request['priceMax']}',
        'minPrice': request['priceMin'],
        'maxPrice': request['priceMax'],
        'tags': request['amenities'] ?? <String>[],
      },
    );
    final dorms = [...baseDorms, ...approvedOwnerDorms];
    return dorms
        .where((dorm) => !(state?.isDormClosed(dorm['id'].toString()) ?? false))
        .toList();
  }
}
