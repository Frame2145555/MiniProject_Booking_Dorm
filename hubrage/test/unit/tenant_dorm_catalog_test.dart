import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/admin_console_state.dart';
import '../../lib/models/dorm_catalog.dart';
import '../support/admin_console_test_helpers.dart';

void main() {
  group('tenant dorm catalog data', () {
    test('has four unique dorms with valid prices and required fields', () {
      final dorms = DormCatalog.baseDorms;
      expect(dorms, hasLength(4));
      expect(dorms.map((dorm) => dorm['id']).toSet(), hasLength(4));

      for (final dorm in dorms) {
        for (final key in [
          'id',
          'title',
          'price',
          'minPrice',
          'maxPrice',
          'location',
          'tags',
        ]) {
          expect(
            dorm.containsKey(key),
            isTrue,
            reason: '${dorm['id']} lacks $key',
          );
        }
        expect(dorm['minPrice'], isA<int>());
        expect(dorm['maxPrice'], isA<int>());
        expect(
          dorm['minPrice'] as int,
          lessThanOrEqualTo(dorm['maxPrice'] as int),
        );
      }
    });

    test('formats displayed prices from each dorm price range', () {
      String format(int value) => value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

      for (final dorm in DormCatalog.baseDorms) {
        expect(
          dorm['price'],
          '${format(dorm['minPrice'] as int)} - ${format(dorm['maxPrice'] as int)}',
          reason: dorm['id'].toString(),
        );
      }
    });

    test('all dorm tags have a corresponding amenity filter', () {
      final amenityLabels = DormCatalog.amenities
          .map((amenity) => amenity['label'])
          .toSet();
      for (final dorm in DormCatalog.baseDorms) {
        for (final tag in dorm['tags'] as List) {
          expect(
            amenityLabels,
            contains(tag),
            reason: '${dorm['id']} has unknown tag $tag',
          );
        }
      }
    });

    test('amenity labels are unique and have icons', () {
      final labels = DormCatalog.amenities
          .map((amenity) => amenity['label'])
          .toList();
      expect(labels.toSet(), hasLength(labels.length));
      for (final amenity in DormCatalog.amenities) {
        expect(amenity['icon'], isNotNull, reason: amenity['label'].toString());
      }
    });
  });

  group('dorms visible to tenants', () {
    test('shows all sample dorms when no admin state is supplied', () {
      expect(dormIds(DormCatalog.visibleDorms(null)), [
        'dorm_1',
        'dorm_2',
        'dorm_3',
        'dorm_4',
      ]);
    });

    test('hides a dorm whose seller account is suspended', () {
      final state = AdminConsoleState();
      addTearDown(state.dispose);

      expect(dormIds(DormCatalog.visibleDorms(state)), [
        'dorm_1',
        'dorm_2',
        'dorm_4',
      ]);
    });

    test('does not show owner listings until admin approval', () {
      final state = AdminConsoleState()..suspendSeller('seller_003', false);
      addTearDown(state.dispose);
      submitOwnerDorm(state, id: 'dorm_pending', name: 'หอรอตรวจ');
      submitOwnerDorm(state, id: 'dorm_rejected', name: 'หอถูกปฏิเสธ');
      state.reviewDormRequest(
        state.dormRequests.first['id'].toString(),
        approve: false,
      );

      expect(dormIds(DormCatalog.visibleDorms(state)), [
        'dorm_1',
        'dorm_2',
        'dorm_3',
        'dorm_4',
      ]);
    });

    test(
      'shows an owner listing after admin approval with tenant card fields',
      () {
        final state = AdminConsoleState()..suspendSeller('seller_003', false);
        addTearDown(state.dispose);
        submitOwnerDorm(
          state,
          id: 'dorm_new',
          name: 'หอใหม่',
          min: 5000,
          max: 8000,
          amenities: ['แอร์', 'Wi-Fi'],
        );
        state.reviewDormRequest(
          state.dormRequests.first['id'].toString(),
          approve: true,
        );

        final dorms = DormCatalog.visibleDorms(state);
        expect(dormIds(dorms).last, 'dorm_new');
        expect(dorms.last, containsPair('title', 'หอใหม่'));
        expect(dorms.last, containsPair('minPrice', 5000));
        expect(dorms.last, containsPair('maxPrice', 8000));
        expect(dorms.last, containsPair('tags', ['แอร์', 'Wi-Fi']));
        expect(dorms.last, containsPair('location', 'ที่ตั้งของ หอใหม่'));
        expect(dorms.last['price'], '5000 - 8000');
        expect(dorms.last['rating'], isNull);
      },
    );
  });
}
