import 'package:flutter/foundation.dart';

class Session {
  static String token = '';
  static int userId = 0;
  static String role = '';
  static String fullName = '';
  static bool get isLoggedIn => token.isNotEmpty;

  /// แจ้งทุกหน้าเมื่อ login / logout
  /// (NavigationShell สร้างหน้าไว้ครั้งเดียวใน IndexedStack หน้าแชท/บัญชีต้องฟังตัวนี้เพื่ออัปเดตเอง)
  static final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);

  static void clear() {
    token = '';
    userId = 0;
    role = '';
    fullName = '';
    loggedIn.value = false;
  }
}
