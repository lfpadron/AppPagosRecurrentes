class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const userId = String.fromEnvironment(
    'USER_ID',
    defaultValue: '00000000-0000-0000-0000-000000000001',
  );

  static const dataMode = String.fromEnvironment(
    'DATA_MODE',
    defaultValue: 'auto',
  );

  static bool get forceLocalData => dataMode.toLowerCase() == 'local';
}
