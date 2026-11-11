// Unit test: DormCatalog (แหล่งข้อมูลของหน้าค้นหา) + การซ่อนหอตามสถานะใน AdminConsoleState
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/admin_console_state.dart';
import '../lib/models/dorm_catalog.dart';

List<String> ids(List<Map<String, dynamic>> dorms) => dorms.map((d) => d['id'].toString()).toList();

/// ส่งคำขอลงหอของเจ้าของแล้วตัดสินผล (approve: true/false/null=ปล่อยให้รอตรวจ)
void addOwnerDorm(
  AdminConsoleState state, {
  required String id,
  required String name,
  int min = 5000,
  int max = 8000,
  List<String> amenities = const ['แอร์'],
  bool? approve,
}) {
  state.submitDormRequest(
    sellerId: 'seller_new',
    sellerName: 'เจ้าของใหม่',
    dormId: id,
    dormName: name,
    phone: '0800000000',
    location: 'ที่ตั้งของ $name',
    latitude: null,
    longitude: null,
    description: 'รายละเอียด',
    priceMin: min,
    priceMax: max,
    amenities: amenities,
    imageUrl: '',
    documents: const <Map<String, String>>[],
  );
  if (approve != null) {
    state.reviewDormRequest(state.dormRequests.first['id'].toString(), approve: approve);
  }
}

void main() {
  group('DormCatalog.baseDorms (ความถูกต้องของข้อมูลตัวอย่าง)', () {
    test('มี 4 หอ id ไม่ซ้ำ และมีคีย์ที่ DormCard/ค้นหาใช้ครบ', () {
      final dorms = DormCatalog.baseDorms;
      expect(dorms.length, 4);
      expect(dorms.map((d) => d['id']).toSet().length, 4);
      for (final d in dorms) {
        for (final key in ['id', 'title', 'price', 'minPrice', 'maxPrice', 'location', 'tags']) {
          expect(d.containsKey(key), isTrue, reason: '${d['id']} ขาด $key');
        }
        expect(d['minPrice'], isA<int>());
        expect(d['maxPrice'], isA<int>());
        expect(d['minPrice'] as int, lessThanOrEqualTo(d['maxPrice'] as int));
      }
    });

    test('ข้อความราคาตรงกับ minPrice/maxPrice (มีเครื่องหมาย ,)', () {
      String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
      for (final d in DormCatalog.baseDorms) {
        expect(d['price'], '${fmt(d['minPrice'] as int)} - ${fmt(d['maxPrice'] as int)}', reason: d['id'].toString());
      }
    });

    test('ทุก tag ของหออยู่ในรายการ amenities ของตัวกรอง (ไม่งั้นกรองไม่เจอ)', () {
      final labels = DormCatalog.amenities.map((a) => a['label']).toSet();
      for (final d in DormCatalog.baseDorms) {
        for (final tag in d['tags'] as List) {
          expect(labels, contains(tag), reason: '${d['id']} มี tag "$tag" ที่ตัวกรองไม่มี');
        }
      }
    });

    test('amenities: label ไม่ซ้ำ และมี icon ทุกรายการ', () {
      final labels = DormCatalog.amenities.map((a) => a['label']).toList();
      expect(labels.toSet().length, labels.length);
      for (final a in DormCatalog.amenities) {
        expect(a['icon'], isNotNull, reason: a['label'].toString());
      }
    });
  });

  group('DormCatalog.visibleDorms', () {
    test('ไม่มี state -> เห็นหอตัวอย่างครบ 4 หอ', () {
      expect(ids(DormCatalog.visibleDorms(null)), ['dorm_1', 'dorm_2', 'dorm_3', 'dorm_4']);
    });

    test('state เริ่มต้น: seller_003 ถูกระงับ -> หอ dorm_3 ถูกซ่อน', () {
      final state = AdminConsoleState();
      expect(ids(DormCatalog.visibleDorms(state)), ['dorm_1', 'dorm_2', 'dorm_4']);
    });

    test('คืนสถานะเจ้าของหอ -> หอกลับมา / ระงับเจ้าของหออื่น -> หอนั้นหาย', () {
      final state = AdminConsoleState();
      state.suspendSeller('seller_003', false);
      expect(ids(DormCatalog.visibleDorms(state)), ['dorm_1', 'dorm_2', 'dorm_3', 'dorm_4']);

      state.suspendSeller('seller_001', true);
      expect(ids(DormCatalog.visibleDorms(state)), ['dorm_2', 'dorm_3', 'dorm_4']);
    });

    test('เจ้าของปิดประกาศชั่วคราว -> ซ่อน และเปิดใหม่ -> กลับมา', () {
      final state = AdminConsoleState()..suspendSeller('seller_003', false);
      state.toggleDormClosed('dorm_2', true);
      expect(ids(DormCatalog.visibleDorms(state)), isNot(contains('dorm_2')));
      state.toggleDormClosed('dorm_2', false);
      expect(ids(DormCatalog.visibleDorms(state)), contains('dorm_2'));
    });

    test('หอของเจ้าของที่ยังรออนุมัติ / ถูกปฏิเสธ ไม่แสดงต่อผู้เช่า', () {
      final state = AdminConsoleState()..suspendSeller('seller_003', false);
      addOwnerDorm(state, id: 'dorm_pending', name: 'หอรอตรวจ');
      addOwnerDorm(state, id: 'dorm_rejected', name: 'หอถูกปฏิเสธ', approve: false);
      expect(ids(DormCatalog.visibleDorms(state)), ['dorm_1', 'dorm_2', 'dorm_3', 'dorm_4']);
    });

    test('หอที่แอดมินอนุมัติ -> ต่อท้ายหอตัวอย่าง และแปลงคีย์ให้ตรงกับ DormCard', () {
      final state = AdminConsoleState()..suspendSeller('seller_003', false);
      addOwnerDorm(
        state,
        id: 'dorm_new',
        name: 'หอใหม่',
        min: 5000,
        max: 8000,
        amenities: ['แอร์', 'Wi-Fi'],
        approve: true,
      );

      final dorms = DormCatalog.visibleDorms(state);
      expect(ids(dorms).last, 'dorm_new');

      final d = dorms.last;
      expect(d['title'], 'หอใหม่');
      expect(d['minPrice'], 5000);
      expect(d['maxPrice'], 8000);
      expect(d['tags'], ['แอร์', 'Wi-Fi']);
      expect(d['location'], 'ที่ตั้งของ หอใหม่');
      // หมายเหตุ: หอของเจ้าของสร้างข้อความราคาแบบไม่มีเครื่องหมาย , (ต่างจากหอตัวอย่าง)
      expect(d['price'], '5000 - 8000');
      expect(d['rating'], isNull);
    });

    test('หอของเจ้าของที่อนุมัติแล้วแต่ปิดประกาศ -> ซ่อน', () {
      final state = AdminConsoleState()..suspendSeller('seller_003', false);
      addOwnerDorm(state, id: 'dorm_new', name: 'หอใหม่', approve: true);
      expect(ids(DormCatalog.visibleDorms(state)), contains('dorm_new'));
      state.toggleDormClosed('dorm_new', true);
      expect(ids(DormCatalog.visibleDorms(state)), isNot(contains('dorm_new')));
    });

    test('หออนุมัติหลายหอ เรียงตามลำดับ approvedDorms (ใหม่สุดมาก่อนตามที่ insert)', () {
      final state = AdminConsoleState();
      addOwnerDorm(state, id: 'dorm_a', name: 'A', approve: true);
      addOwnerDorm(state, id: 'dorm_b', name: 'B', approve: true);
      final baseIds = ids(DormCatalog.baseDorms);
      final owner = ids(DormCatalog.visibleDorms(state)).where((id) => !baseIds.contains(id));
      expect(owner.toList(), ['dorm_b', 'dorm_a']);
    });
  });
}
