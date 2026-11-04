/// Runtime configuration.
///
/// Secrets are supplied at build time via `--dart-define` so they are never
/// committed. Example:
///
///   flutter run --dart-define=JAMENDO_CLIENT_ID=xxxxxxxx
///
/// Nothing here is a hardcoded production secret. When a value is missing the
/// app degrades gracefully (see [jamendoConfigured]).
class AppConfig {
  AppConfig._();

  /// Public Jamendo client id. Jamendo is an authorized, Creative-Commons
  /// licensed catalogue that explicitly permits streaming via its public API.
  /// A development/demo id is bundled as a fallback so the provider works out
  /// of the box; supply your own for production volume. See README.
  static String jamendoClientId = const String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: '56d30c95',
  );

  /// Base URL for Jamendo's public API (never hardcoded elsewhere).
  static const String jamendoBaseUrl = 'https://api.jamendo.com/v3.0';

  /// Optional future licensed provider endpoint/key (empty until configured).
  static const String licensedBaseUrl = String.fromEnvironment(
    'LICENSED_BASE_URL',
    defaultValue: '',
  );
  static const String licensedApiKey = String.fromEnvironment(
    'LICENSED_API_KEY',
    defaultValue: '',
  );

  /// Supabase project URL and Publishable/Anon Key
  static String supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rotvxnnblkxbqhfcbynt.supabase.co',
  );

  static String supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvdHZ4bm5ibGt4YnFoZmNieW50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwNDQ4MDEsImV4cCI6MjEwNjYyMDgwMX0.F7oTJbsxXifFHU0GKlGvJSA65RSSqB0o0RuwLq26r4Y',
    ),
  );

  /// Official Audius API base URL and application identification
  static const String audiusBaseUrl = 'https://api.audius.co';

  static String audiusAppName = const String.fromEnvironment(
    'AUDIUS_APP_NAME',
    defaultValue: 'KalpkrutBeats',
  );

  static String audiusApiKey = const String.fromEnvironment(
    'AUDIUS_API_KEY',
    defaultValue: '',
  );

  /// Custom Audio Gateway API Base URL (Python Flask on Fly.io)
  static String customApiUrl = const String.fromEnvironment(
    'CUSTOM_API_URL',
    defaultValue: 'https://kalpkrut-beats-api.fly.dev',
  );

  /// Google Cloud **Web** OAuth Client ID (public, optional in app).
  /// Supabase Dashboard holds Client ID + Secret for browser OAuth.
  /// Client **secret** must never be shipped in the APK / .env used by mobile.
  static String googleWebClientId = const String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '986422322069-su7f5uvackoutj3ar8679fbrrkmmqo7q.apps.googleusercontent.com',
  );

  /// Load environment from .env if available
  static void loadFromEnv(Map<String, String> env) {
    if (env.containsKey('CUSTOM_API_URL') && env['CUSTOM_API_URL']!.isNotEmpty) {
      customApiUrl = env['CUSTOM_API_URL']!;
    }
    if (env.containsKey('SUPABASE_URL') && env['SUPABASE_URL']!.isNotEmpty) {
      supabaseUrl = env['SUPABASE_URL']!;
    }
    if (env.containsKey('SUPABASE_PUBLISHABLE_KEY') &&
        env['SUPABASE_PUBLISHABLE_KEY']!.isNotEmpty) {
      supabaseAnonKey = env['SUPABASE_PUBLISHABLE_KEY']!;
    } else if (env.containsKey('SUPABASE_ANON_KEY') &&
        env['SUPABASE_ANON_KEY']!.isNotEmpty) {
      supabaseAnonKey = env['SUPABASE_ANON_KEY']!;
    }
    if (env.containsKey('AUDIUS_API_KEY') && env['AUDIUS_API_KEY']!.isNotEmpty) {
      audiusApiKey = env['AUDIUS_API_KEY']!;
    }
    if (env.containsKey('AUDIUS_APP_NAME') && env['AUDIUS_APP_NAME']!.isNotEmpty) {
      audiusAppName = env['AUDIUS_APP_NAME']!;
    }
    if (env.containsKey('JAMENDO_CLIENT_ID') && env['JAMENDO_CLIENT_ID']!.isNotEmpty) {
      jamendoClientId = env['JAMENDO_CLIENT_ID']!;
    }
    if (env.containsKey('GOOGLE_WEB_CLIENT_ID') &&
        env['GOOGLE_WEB_CLIENT_ID']!.isNotEmpty) {
      googleWebClientId = env['GOOGLE_WEB_CLIENT_ID']!;
    }
  }

  /// Whether Supabase is configured
  static bool get supabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Privacy: analytics off by default (opt-in only).
  static const bool analyticsDefaultEnabled = false;

  /// Whether the Jamendo provider has a usable key.
  static bool get jamendoConfigured => jamendoClientId.trim().isNotEmpty;

  /// Whether the licensed provider is configured.
  static bool get licensedConfigured =>
      licensedBaseUrl.trim().isNotEmpty && licensedApiKey.trim().isNotEmpty;
}
