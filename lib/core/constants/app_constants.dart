/// Centralized constants. Never hardcode URLs/secrets deep in feature code.
class AppConstants {
  AppConstants._();

  static const String appName = 'EchoFlow Music';
  static const String appVersion = '1.0.0';

  // Provider ids
  static const String providerDemo = 'demo';
  static const String providerJamendo = 'jamendo';
  static const String providerLocal = 'local';
  static const String providerLicensed = 'licensed';

  /// Local-first settings/box keys.
  static const String prefsBox = 'echoflow_prefs';
  static const String libraryBox = 'echoflow_library';
  static const String cacheBox = 'echoflow_cache';

  // Cache TTLs (see spec §11 caching strategy).
  static const Duration searchCacheTtl = Duration(minutes: 5);
  static const Duration discoveryCacheTtl = Duration(minutes: 30);
  static const Duration entityCacheTtl = Duration(hours: 6);
  static const Duration streamCacheTtl = Duration(minutes: 20);

  // Pagination
  static const int defaultPageSize = 20;

  /// Maximum number of recently-played entries kept locally.
  static const int recentHistoryLimit = 200;

  /// Default crossfade/gapless are off — not all engines/providers support them.
  static const bool supportsCrossfade = false;
  static const bool supportsGapless = false;
}
