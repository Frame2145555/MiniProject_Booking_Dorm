import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/admin_console_state.dart';
import '../../lib/models/dorm_catalog.dart';
import '../support/admin_console_test_helpers.dart';

void main() {
  group('admin seller and listing controls', () {
    test('suspending and reactivating a seller updates tenant visibility', () {
      final state = AdminConsoleState();
      addTearDown(state.dispose);
      expect(
        dormIds(DormCatalog.visibleDorms(state)),
        isNot(contains('dorm_3')),
      );

      state.suspendSeller('seller_003', false);
      expect(dormIds(DormCatalog.visibleDorms(state)), contains('dorm_3'));
      state.suspendSeller('seller_001', true);
      expect(
        dormIds(DormCatalog.visibleDorms(state)),
        isNot(contains('dorm_1')),
      );
    });

    test(
      'closing and reopening an approved dorm updates tenant visibility',
      () {
        final state = AdminConsoleState()..suspendSeller('seller_003', false);
        addTearDown(state.dispose);

        state.toggleDormClosed('dorm_2', true);
        expect(
          dormIds(DormCatalog.visibleDorms(state)),
          isNot(contains('dorm_2')),
        );
        state.toggleDormClosed('dorm_2', false);
        expect(dormIds(DormCatalog.visibleDorms(state)), contains('dorm_2'));
      },
    );

    test('approved owner listings appear newest first', () {
      final state = AdminConsoleState();
      addTearDown(state.dispose);
      submitOwnerDorm(state, id: 'dorm_a', name: 'A');
      state.reviewDormRequest(
        state.dormRequests.first['id'].toString(),
        approve: true,
      );
      submitOwnerDorm(state, id: 'dorm_b', name: 'B');
      state.reviewDormRequest(
        state.dormRequests.first['id'].toString(),
        approve: true,
      );

      final sampleIds = DormCatalog.baseDorms.map((dorm) => dorm['id']).toSet();
      final ownerIds = dormIds(
        DormCatalog.visibleDorms(state),
      ).where((id) => !sampleIds.contains(id));
      expect(ownerIds, ['dorm_b', 'dorm_a']);
    });
  });
}
