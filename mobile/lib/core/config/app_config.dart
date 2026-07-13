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

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get normalizedSupabaseUrl => supabaseUrl.trim();

  static String get normalizedSupabaseAnonKey => supabaseAnonKey.trim();

  static bool get forceLocalData => dataMode.toLowerCase() == 'local';

  static bool get supabaseAuthEnabled =>
      normalizedSupabaseUrl.isNotEmpty && normalizedSupabaseAnonKey.isNotEmpty;
}
