class Session {
  static String token = '';
  static int userId = 0;
  static String role = '';
  static String fullName = '';
  static bool get isLoggedIn => token.isNotEmpty;

  static void clear() {
    token = '';
    userId = 0;
    role = '';
    fullName = '';
  }
}
