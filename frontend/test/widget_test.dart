import 'package:flutter_test/flutter_test.dart';

import 'package:dormspace_app/main.dart';

void main() {
  testWidgets('Dashboard shows booking and payment history', (tester) async {
    await tester.pumpWidget(const DormSpaceApp());
    await tester.pumpAndSettle();

    expect(find.text('Student Housing Dashboard'), findsOneWidget);
    expect(find.text('Room 102 · North Hall (Block A)'), findsOneWidget);
    expect(find.text('Payment History'), findsOneWidget);
  });
}
