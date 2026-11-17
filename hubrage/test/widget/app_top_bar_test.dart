import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hubrage/widgets/app_top_bar.dart';

void main() {
  testWidgets('shows report review notifications instead of demo alerts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppTopBar(
              onMenu: () {},
              onAccount: () {},
              onNotifications: () async {
                await showNotificationsSheet(
                  context,
                  notifications: const [
                    {
                      'id': 5,
                      'type': 'dorm_report_resolved',
                      'title': 'รายงานของคุณได้รับการจัดการแล้ว',
                      'message': 'แอดมินตรวจสอบรายงานหอพักแล้ว',
                      'isRead': false,
                    },
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('การแจ้งเตือน'));
    await tester.pumpAndSettle();

    expect(find.text('รายงานของคุณได้รับการจัดการแล้ว'), findsOneWidget);
    expect(find.text('แอดมินตรวจสอบรายงานหอพักแล้ว'), findsOneWidget);
    expect(find.text('ยินดีต้อนรับสู่ Dorm Master'), findsNothing);
  });
}
