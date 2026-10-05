/// Centralized constants. Never hardcode URLs/secrets deep in feature code.
class AppConstants {
  AppConstants._();

  static const String appName = 'Kalpkrut Beats';
  static const String appVersion = '1.0.1';
  static const String companyName = 'Kalpkrut Infotech';
  static const String officialWebUrl = 'https://beats.kalpkrutinfotech.com/';

  // Provider ids
  static const String providerDemo = 'demo';
  static const String providerJamendo = 'jamendo';
  static const String providerLocal = 'local';
  static const String providerLicensed = 'licensed';

  /// Local-first settings/box keys.
  static const String prefsBox = 'kalpkrut_prefs';
  static const String libraryBox = 'kalpkrut_library';
  static const String cacheBox = 'kalpkrut_cache';

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
