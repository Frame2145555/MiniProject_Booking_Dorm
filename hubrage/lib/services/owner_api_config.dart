class OwnerApiConfig {
  static const _url = String.fromEnvironment(
    'OWNER_API_URL',
    defaultValue: 'http://localhost:3001',
  );

  static String get baseUrl => _url.replaceAll(RegExp(r'/+$'), '');
}
