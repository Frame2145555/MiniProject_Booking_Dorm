import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/admin_console_state.dart';
import '../support/admin_console_test_helpers.dart';

void main() {
  test('submitting a dorm creates a pending request with owner details', () {
    final state = AdminConsoleState();
    addTearDown(state.dispose);

    submitOwnerDorm(
      state,
      id: 'dorm_owner_test',
      name: 'หอที่เจ้าของส่ง',
      min: 4500,
      max: 7500,
      amenities: ['แอร์', 'Wi-Fi'],
    );

    final request = state.dormRequests.single;
    expect(request['sellerId'], 'seller_new');
    expect(request['sellerName'], 'เจ้าของใหม่');
    expect(request['dormId'], 'dorm_owner_test');
    expect(request['dormName'], 'หอที่เจ้าของส่ง');
    expect(request['priceMin'], 4500);
    expect(request['priceMax'], 7500);
    expect(request['amenities'], ['แอร์', 'Wi-Fi']);
    expect(request['status'], 'pending');
  });
}
