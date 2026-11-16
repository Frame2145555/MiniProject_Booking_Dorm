import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/admin_console_state.dart';
import '../../lib/models/favorites_state.dart';
import '../../lib/theme/app_theme.dart';
import '../../lib/views/search_view.dart';
import '../../lib/widgets/dorm_card.dart';

const _d1 = 'หอรวย เธะ';
const _d2 = 'หออิสลาม แกรนด์';
const _d3 = 'HU 24 อพาร์ตเมนต์';
const _d4 = 'กรีนวิลล์ คอนโดเช่า';

Future<AdminConsoleState> _pumpSearch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AdminConsoleState()..suspendSeller('seller_003', false);
  addTearDown(state.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SearchView(consoleState: state, favorites: FavoritesState()),
      ),
    ),
  );
  await tester.pump();
  return state;
}

List<String> _visibleDorms(WidgetTester tester) => tester
    .widgetList<DormCard>(find.byType(DormCard))
    .map((card) => card.dorm['title'].toString())
    .toList();

void _submitDorm(
  AdminConsoleState state, {
  required String id,
  required String name,
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
    priceMin: 5000,
    priceMax: 8000,
    amenities: const ['แอร์'],
    imageUrl: '',
    documents: const <Map<String, String>>[],
  );
}

void main() {
  testWidgets(
    'admin suspension and reactivation updates tenant search results',
    (tester) async {
      final state = await _pumpSearch(tester);
      expect(_visibleDorms(tester), [_d1, _d2, _d3, _d4]);

      state.suspendSeller('seller_001', true);
      await tester.pump();
      expect(_visibleDorms(tester), [_d2, _d3, _d4]);

      state.suspendSeller('seller_001', false);
      await tester.pump();
      expect(_visibleDorms(tester), [_d1, _d2, _d3, _d4]);
    },
  );

  testWidgets(
    'tenant search shows an owner dorm after approval, not while pending',
    (tester) async {
      final state = await _pumpSearch(tester);
      _submitDorm(state, id: 'dorm_approved', name: 'หออนุมัติแล้ว');
      _submitDorm(state, id: 'dorm_pending', name: 'หอรอตรวจ');
      state.reviewDormRequest(
        state.dormRequests
            .firstWhere((request) => request['dormId'] == 'dorm_approved')['id']
            .toString(),
        approve: true,
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'อนุมัติ');
      await tester.pump();

      expect(_visibleDorms(tester), ['หออนุมัติแล้ว']);
    },
  );
}
