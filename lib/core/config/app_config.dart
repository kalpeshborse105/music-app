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
  static const String jamendoClientId = String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: '2af2c9e0',
  );

  /// Base URL for Jamendo's public API (never hardcoded elsewhere).
  static const String jamendoBaseUrl = 'https://api.jamendo.com/v3.0';

  /// Optional future licensed provider endpoint/key (empty until configured).
  static const String licensedBaseUrl =
      String.fromEnvironment('LICENSED_BASE_URL', defaultValue: '');
  static const String licensedApiKey =
      String.fromEnvironment('LICENSED_API_KEY', defaultValue: '');

  /// Privacy: analytics off by default (opt-in only).
  static const bool analyticsDefaultEnabled = false;

  /// Whether the Jamendo provider has a usable key.
  static bool get jamendoConfigured => jamendoClientId.trim().isNotEmpty;

  /// Whether the licensed provider is configured.
  static bool get licensedConfigured =>
      licensedBaseUrl.trim().isNotEmpty && licensedApiKey.trim().isNotEmpty;
}
