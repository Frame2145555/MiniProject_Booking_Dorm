// Widget test: หน้าค้นหา (SearchView) — ค้นหา / กรอง / เรียงลำดับ
// ตรรกะค้นหาและเรียงอยู่ใน State แบบ private จึงทดสอบผ่านหน้าจอ (ดูรายชื่อ DormCard ที่แสดงตามลำดับ)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/admin_console_state.dart';
import '../lib/models/favorites_state.dart';
import '../lib/theme/app_theme.dart';
import '../lib/views/search_view.dart';
import '../lib/widgets/dorm_card.dart';

// ชื่อหอตัวอย่างใน DormCatalog.baseDorms
const d1 = 'หอรวย เธะ'; // 5,000-8,500  คะแนน 4.7  วิว 1280
const d2 = 'หออิสลาม แกรนด์'; // 6,500-9,000  คะแนน 4.0  วิว 642
const d3 = 'HU 24 อพาร์ตเมนต์'; // 7,200-11,000 คะแนน 4.9  วิว 2094
const d4 = 'กรีนวิลล์ คอนโดเช่า'; // 4,800-7,000  คะแนน 4.5  วิว 0 (ไม่มีใน dormViews)

/// แสดงหน้าค้นหาบนจอสูง (ให้ ListView สร้างการ์ดครบทุกใบ)
/// seller_003 (เจ้าของ HU 24) ถูกระงับในข้อมูลตัวอย่าง -> ค่าเริ่มต้นคืนสถานะให้เพื่อให้เห็น 4 หอ
Future<AdminConsoleState> pumpSearch(
  WidgetTester tester, {
  AdminConsoleState? state,
  bool unsuspendHU = true,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final console = state ?? AdminConsoleState();
  if (unsuspendHU) console.suspendSeller('seller_003', false);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SearchView(consoleState: console, favorites: FavoritesState()),
      ),
    ),
  );
  await tester.pump();
  return console;
}

List<String> shown(WidgetTester tester) => tester
    .widgetList<DormCard>(find.byType(DormCard))
    .map((c) => c.dorm['title'].toString())
    .toList();

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> chooseSort(WidgetTester tester, String label) async {
  await tester.tap(find.text('เรียงตาม').evaluate().isNotEmpty ? find.text('เรียงตาม') : find.byIcon(Icons.swap_vert_rounded));
  await tester.pump();
  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pump();
}

/// เพิ่มหอของเจ้าของที่แอดมินอนุมัติแล้ว (ไม่มีคะแนน ไม่มียอดวิว)
void addApproved(AdminConsoleState console, String id, String name, int min, int max) {
  console.submitDormRequest(
    sellerId: 'seller_new',
    sellerName: 'เจ้าของใหม่',
    dormId: id,
    dormName: name,
    phone: '0800000000',
    location: 'ที่ตั้ง $name',
    latitude: null,
    longitude: null,
    description: 'รายละเอียด',
    priceMin: min,
    priceMax: max,
    amenities: const ['แอร์'],
    imageUrl: '',
    documents: const <Map<String, String>>[],
  );
  console.reviewDormRequest(console.dormRequests.first['id'].toString(), approve: true);
}

void main() {
  group('รายการเริ่มต้น', () {
    testWidgets('แสดงทุกหอตามลำดับแคตตาล็อก', (tester) async {
      await pumpSearch(tester);
      expect(shown(tester), [d1, d2, d3, d4]);
    });

    testWidgets('หอของเจ้าของที่ถูกระงับไม่แสดง (HU 24 ในข้อมูลตัวอย่าง)', (tester) async {
      await pumpSearch(tester, unsuspendHU: false);
      expect(shown(tester), [d1, d2, d4]);
    });

    testWidgets('ระงับ/คืนสถานะเจ้าของหอ -> รายการอัปเดตทันที', (tester) async {
      final console = await pumpSearch(tester);
      console.suspendSeller('seller_001', true);
      await tester.pump();
      expect(shown(tester), [d2, d3, d4]);
      console.suspendSeller('seller_001', false);
      await tester.pump();
      expect(shown(tester), [d1, d2, d3, d4]);
    });
  });

  group('ค้นหาด้วยข้อความ', () {
    testWidgets('ค้นตามชื่อหอ ไม่สนตัวพิมพ์เล็ก/ใหญ่', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'hu');
      expect(shown(tester), [d3]);
      await search(tester, 'HU 24');
      expect(shown(tester), [d3]);
    });

    testWidgets('ค้นตามที่ตั้ง/ขนส่ง (location)', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'airport');
      expect(shown(tester), [d2]);
      await search(tester, 'abac');
      expect(shown(tester), [d3]);
      await search(tester, 'รามคำแหง 24');
      expect(shown(tester), [d1, d2, d3]);
    });

    testWidgets('ตัดช่องว่างหน้า-หลังคำค้น', (tester) async {
      await pumpSearch(tester);
      await search(tester, '   hu   ');
      expect(shown(tester), [d3]);
    });

    testWidgets('ไม่พบ -> แสดงข้อความว่าไม่พบ และไม่มีการ์ด', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'zzzไม่มีหอนี้');
      expect(shown(tester), isEmpty);
      expect(find.text('ไม่พบหอพักที่ตรงกับเงื่อนไขการค้นหา'), findsOneWidget);
    });

    testWidgets('ปุ่มล้างคำค้น (x) -> กลับมาแสดงทั้งหมด', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'hu');
      expect(shown(tester), [d3]);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(shown(tester), [d1, d2, d3, d4]);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('หอที่เจ้าของเพิ่มและแอดมินอนุมัติ ค้นเจอ / หอรออนุมัติค้นไม่เจอ', (tester) async {
      final console = await pumpSearch(tester);
      addApproved(console, 'dorm_new', 'หอใหม่ทดสอบ', 5000, 8000);
      console.submitDormRequest(
        sellerId: 's',
        sellerName: 's',
        dormId: 'dorm_pending',
        dormName: 'หอรอตรวจทดสอบ',
        phone: '0',
        location: 'x',
        latitude: null,
        longitude: null,
        description: 'd',
        priceMin: 1000,
        priceMax: 2000,
        amenities: const [],
        imageUrl: '',
        documents: const <Map<String, String>>[],
      );
      await tester.pump();

      await search(tester, 'ทดสอบ');
      expect(shown(tester), ['หอใหม่ทดสอบ']);
    });
  });

  group('กรองตามสิ่งอำนวยความสะดวก', () {
    Future<void> openAmenities(WidgetTester tester) async {
      await tester.tap(find.byTooltip('สิ่งอำนวยความสะดวก'));
      await tester.pump();
    }

    Future<void> pick(WidgetTester tester, List<String> labels) async {
      await openAmenities(tester);
      for (final l in labels) {
        await tester.tap(find.widgetWithText(FilterChip, l));
        await tester.pump();
      }
      await tester.tap(find.text('ตกลง (${labels.length})'));
      await tester.pump();
    }

    testWidgets('เลือก 1 อย่าง', (tester) async {
      await pumpSearch(tester);
      await pick(tester, ['ฟิตเนส']);
      expect(shown(tester), [d3]);
    });

    testWidgets('เลือกหลายอย่าง = ต้องมีครบทุกอย่าง (AND)', (tester) async {
      await pumpSearch(tester);
      await pick(tester, ['แอร์', 'เลี้ยงสัตว์ได้']);
      expect(shown(tester), [d3, d4]);
    });

    testWidgets('เลือกแล้วไม่มีหอตรงเงื่อนไข -> ว่าง', (tester) async {
      await pumpSearch(tester);
      await pick(tester, ['ลิฟต์', 'ฟิตเนส']);
      expect(shown(tester), isEmpty);
      expect(find.text('ไม่พบหอพักที่ตรงกับเงื่อนไขการค้นหา'), findsOneWidget);
    });

    testWidgets('กดชิปที่เลือกไว้ (x) เพื่อเอาตัวกรองออก', (tester) async {
      await pumpSearch(tester);
      await pick(tester, ['ฟิตเนส']);
      expect(shown(tester), [d3]);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(shown(tester), [d1, d2, d3, d4]);
    });

    testWidgets('ปุ่ม "ล้างทั้งหมด" ในแผงล้างตัวกรอง', (tester) async {
      await pumpSearch(tester);
      await openAmenities(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'แอร์'));
      await tester.pump();
      await tester.tap(find.text('ล้างทั้งหมด'));
      await tester.pump();
      await tester.tap(find.text('ตกลง (0)'));
      await tester.pump();
      expect(shown(tester), [d1, d2, d3, d4]);
    });

    testWidgets('ใช้ร่วมกับคำค้น', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'รามคำแหง 24'); // d1, d2, d3
      await pick(tester, ['ลิฟต์']);
      expect(shown(tester), [d2]);
    });
  });

  group('กรองตามช่วงราคา (ช่วงราคาของหอ "ทับซ้อน" กับช่วงที่เลือก)', () {
    Future<void> applyRange(WidgetTester tester, RangeValues values) async {
      await tester.tap(find.text('ช่วงราคา'));
      await tester.pump();
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(values);
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'ตกลง'));
      await tester.pump();
    }

    testWidgets('3,000-5,000 -> หอที่ราคาต่ำสุด ≤ 5,000 (รวมค่าขอบ)', (tester) async {
      await pumpSearch(tester);
      await applyRange(tester, const RangeValues(3000, 5000));
      expect(shown(tester), [d1, d4]); // d1 เริ่ม 5,000 พอดี / d4 เริ่ม 4,800
      expect(find.text('ราคา: ฿3000-฿5000'), findsOneWidget);
    });

    testWidgets('9,500-15,000 -> เหลือเฉพาะหอที่ราคาสูงสุด ≥ 9,500', (tester) async {
      await pumpSearch(tester);
      await applyRange(tester, const RangeValues(9500, 15000));
      expect(shown(tester), [d3]);
    });

    testWidgets('ช่วงที่ไม่มีหอทับซ้อน -> ว่าง', (tester) async {
      await pumpSearch(tester);
      await applyRange(tester, const RangeValues(13000, 15000));
      expect(shown(tester), isEmpty);
    });

    testWidgets('กด "ล้างค่า" -> เอาตัวกรองราคาออก ป้ายกลับเป็น "ช่วงราคา"', (tester) async {
      await pumpSearch(tester);
      await applyRange(tester, const RangeValues(3000, 5000));
      expect(shown(tester), [d1, d4]);

      await tester.tap(find.text('ราคา: ฿3000-฿5000'));
      await tester.pump();
      await tester.tap(find.text('ล้างค่า'));
      await tester.pump();

      expect(shown(tester), [d1, d2, d3, d4]);
      expect(find.text('ช่วงราคา'), findsOneWidget);
    });

    testWidgets('ปิดแผงโดยไม่กดตกลง -> ไม่ใช้ตัวกรอง', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.text('ช่วงราคา'));
      await tester.pump();
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(const RangeValues(3000, 4000));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(shown(tester), [d1, d2, d3, d4]);
      expect(find.text('ช่วงราคา'), findsOneWidget);
    });

    testWidgets('ใช้ร่วมกับตัวกรองสิ่งอำนวยความสะดวกและคำค้น', (tester) async {
      await pumpSearch(tester);
      await applyRange(tester, const RangeValues(3000, 7000)); // d1, d2, d4 (d3 เริ่ม 7,200)
      expect(shown(tester), [d1, d2, d4]);
      await search(tester, 'ซอยหลังราม');
      expect(shown(tester), [d4]);
    });
  });

  group('เรียงลำดับ', () {
    testWidgets('เปิดแผง "เรียงตาม" แล้วเห็นตัวเลือกครบ 6 แบบ', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.text('เรียงตาม'));
      await tester.pump();
      for (final label in [
        'แนะนำ (ค่าเริ่มต้น)',
        'ราคา: ต่ำ → สูง',
        'ราคา: สูง → ต่ำ',
        'คะแนนสูงสุด',
        'ยอดเข้าชมมากที่สุด',
        'ชื่อหอพัก ก-ฮ / A-Z',
      ]) {
        expect(find.widgetWithText(ListTile, label), findsOneWidget, reason: label);
      }
    });

    testWidgets('ราคา ต่ำ → สูง (เรียงตามราคาต่ำสุด)', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'ราคา: ต่ำ → สูง');
      expect(shown(tester), [d4, d1, d2, d3]); // 4,800 / 5,000 / 6,500 / 7,200
    });

    testWidgets('ราคา สูง → ต่ำ (เรียงตามราคาสูงสุด)', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'ราคา: สูง → ต่ำ');
      expect(shown(tester), [d3, d2, d1, d4]); // 11,000 / 9,000 / 8,500 / 7,000
    });

    testWidgets('คะแนนสูงสุด', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'คะแนนสูงสุด');
      expect(shown(tester), [d3, d1, d4, d2]); // 4.9 / 4.7 / 4.5 / 4.0
    });

    testWidgets('ยอดเข้าชมมากที่สุด (หอที่ไม่มียอดไปท้าย)', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'ยอดเข้าชมมากที่สุด');
      expect(shown(tester), [d3, d1, d2, d4]); // 2094 / 1280 / 642 / 0
    });

    testWidgets('ยอดเข้าชมเปลี่ยน (มีคนเปิดดู) -> ลำดับอัปเดตตาม', (tester) async {
      final console = await pumpSearch(tester);
      await chooseSort(tester, 'ยอดเข้าชมมากที่สุด');
      expect(shown(tester), [d3, d1, d2, d4]);

      console.dormViews['dorm_4'] = 5000;
      console.recordDormView('dorm_4'); // 5001 -> notifyListeners
      await tester.pump();

      expect(shown(tester), [d4, d3, d1, d2]);
    });

    testWidgets('ชื่อหอพัก: อังกฤษก่อน แล้วไทย ก-ฮ (เทียบรหัสตัวอักษร ไม่ใช่พจนานุกรมไทยเป๊ะ)', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'ชื่อหอพัก ก-ฮ / A-Z');
      expect(shown(tester), [d3, d4, d1, d2]); // HU / กรีน / หอรวย / หออิสลาม
    });

    testWidgets('กลับมา "แนะนำ" -> ลำดับเดิมของแคตตาล็อก', (tester) async {
      await pumpSearch(tester);
      await chooseSort(tester, 'ราคา: ต่ำ → สูง');
      expect(shown(tester), [d4, d1, d2, d3]);

      await tester.tap(find.text('ราคา: ต่ำ → สูง')); // ป้ายเรียงเปลี่ยนเป็นชื่อตัวเลือก
      await tester.pump();
      await tester.tap(find.widgetWithText(ListTile, 'แนะนำ (ค่าเริ่มต้น)'));
      await tester.pump();

      expect(shown(tester), [d1, d2, d3, d4]);
      expect(find.text('เรียงตาม'), findsOneWidget);
    });

    testWidgets('ป้ายปุ่มเรียงเปลี่ยนเป็นชื่อตัวเลือกที่เลือก', (tester) async {
      await pumpSearch(tester);
      expect(find.text('เรียงตาม'), findsOneWidget);
      await chooseSort(tester, 'คะแนนสูงสุด');
      expect(find.text('เรียงตาม'), findsNothing);
      expect(find.text('คะแนนสูงสุด'), findsOneWidget);
    });

    testWidgets('เรียง + ค้นหาพร้อมกัน: เรียงเฉพาะผลที่กรองแล้ว', (tester) async {
      await pumpSearch(tester);
      await search(tester, 'รามคำแหง 24'); // d1, d2, d3
      await chooseSort(tester, 'ราคา: สูง → ต่ำ');
      expect(shown(tester), [d3, d2, d1]);
    });

    testWidgets('ค่าเท่ากัน -> คงลำดับเดิม (stable): หอใหม่ราคาเท่า d1 ต้องอยู่หลัง d1', (tester) async {
      final console = await pumpSearch(tester);
      addApproved(console, 'dorm_tie', 'หอราคาเท่า', 5000, 8500);
      await tester.pump();

      await chooseSort(tester, 'ราคา: ต่ำ → สูง');
      expect(shown(tester), [d4, d1, 'หอราคาเท่า', d2, d3]);

      await chooseSort(tester, 'ราคา: สูง → ต่ำ');
      expect(shown(tester), [d3, d2, d1, 'หอราคาเท่า', d4]);
    });

    testWidgets('หอที่ยังไม่มีคะแนนไปท้ายสุดเมื่อเรียงตามคะแนน', (tester) async {
      final console = await pumpSearch(tester);
      addApproved(console, 'dorm_norate', 'หอยังไม่มีคะแนน', 5000, 6000);
      await tester.pump();

      await chooseSort(tester, 'คะแนนสูงสุด');
      expect(shown(tester), [d3, d1, d4, d2, 'หอยังไม่มีคะแนน']);
    });

    testWidgets('หอที่ยังไม่มียอดวิวเท่ากับ 0 และอยู่หลังหอที่มีวิว (เท่ากันคงลำดับเดิม)', (tester) async {
      final console = await pumpSearch(tester);
      addApproved(console, 'dorm_noview', 'หอไม่มีวิว', 5000, 6000);
      await tester.pump();

      await chooseSort(tester, 'ยอดเข้าชมมากที่สุด');
      expect(shown(tester), [d3, d1, d2, d4, 'หอไม่มีวิว']);
    });
  });
}
