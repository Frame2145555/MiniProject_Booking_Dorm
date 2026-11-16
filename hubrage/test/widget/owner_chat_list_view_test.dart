import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/session.dart';
import '../../lib/views/chat_view.dart';
import '../support/chat_widget_test_helpers.dart';
import '../support/fake_chat_service.dart';

void main() {
  late FakeChatService service;

  setUp(() {
    Session.clear();
    service = createChatTestService();
  });

  testWidgets('shows the tenant chat heading and the dorm of interest', (
    tester,
  ) async {
    loginChatTestUser(role: 'seller');
    service.conversationList = [chatTestConversation()];

    await tester.pumpWidget(
      chatTestApp(ChatView(asSeller: true, service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('แชทผู้เช่า'), findsOneWidget);
    expect(find.text('สนใจ หอรวย เธะ'), findsOneWidget);
  });
}
