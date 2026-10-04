import '../core/cache/cache_store.dart';
import '../core/network/api_client.dart';
import '../core/utils/logger.dart';
import '../domain/providers/archive_provider.dart';
import '../domain/providers/audius_provider.dart';
import '../domain/providers/demo_provider.dart';
import '../domain/providers/jamendo_provider.dart';
import '../domain/providers/licensed_provider_stub.dart';
import '../domain/providers/local_provider.dart';
import '../domain/providers/music_provider.dart';
import '../domain/providers/regional_music_provider.dart';

/// Builds, owns and exposes all configured providers, and tracks which are
/// currently usable. Adding a new legal provider is a one-line change here —
/// nothing else in the app depends on concrete providers (spec §29).
class ProviderRegistry {
  ProviderRegistry({ApiClient? api, required CacheStore cache})
      : _api = api ?? ApiClient(),
        _cache = cache {
    _providers = <MusicProvider>[
      DemoProvider(api: _api, cache: _cache),
      ArchiveProvider(api: _api, cache: _cache),
      JamendoProvider(api: _api, cache: _cache),
      AudiusProvider(api: _api, cache: _cache),
      LocalMusicProvider(api: _api, cache: _cache),
      RegionalMusicProvider(api: _api, cache: _cache),
      LicensedProviderStub(api: _api, cache: _cache),
    ];
  }

  final ApiClient _api;
  final CacheStore _cache;
  late final List<MusicProvider> _providers;
  final Set<String> _unavailable = <String>{};
  bool _initialized = false;

  List<MusicProvider> get all => List<MusicProvider>.unmodifiable(_providers);

  List<MusicProvider> get available =>
      _providers.where((MusicProvider p) => !_unavailable.contains(p.id)).toList();

  MusicProvider? byId(String id) {
    for (final MusicProvider p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Initializes every provider and records which are usable. Failures are
  /// isolated — one bad provider never blocks the others (spec §29).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    for (final MusicProvider p in _providers) {
      try {
        await p.initialize();
        final bool ok = await p.isAvailable();
        if (!ok) _unavailable.add(p.id);
      } catch (e) {
        Logger.warn('Provider ${p.id} unavailable', error: e);
        _unavailable.add(p.id);
      }
    }
    Logger.info(
      'Providers ready: ${available.map((MusicProvider p) => p.id).join(', ')}',
    );
  }

  /// Re-checks a provider (used after a user configures credentials).
  Future<void> refresh(String providerId) async {
    final MusicProvider? p = byId(providerId);
    if (p == null) return;
    try {
      final bool ok = await p.isAvailable();
      if (ok) {
        _unavailable.remove(providerId);
      } else {
        _unavailable.add(providerId);
      }
    } catch (_) {
      _unavailable.add(providerId);
    }
  }

  bool isAvailable(String providerId) => !_unavailable.contains(providerId);

  /// Providers that should feed the aggregate Home/Search experience, in
  /// priority order. Excludes purely-local content (surfaced separately).
  /// Enforces Provider Compliance: only ACTIVE providers appear in the catalog.
  List<MusicProvider> get discoveryProviders => available
      .where((MusicProvider p) =>
          p.status.isProductionActive &&
          !p.capabilities.localOnly &&
          p.id != 'licensed')
      .toList();

  MusicProvider? get localProvider =>
      byId('local')?.capabilities.localOnly == true ? byId('local') : null;

  bool get hasAnyStreamingProvider =>
      available.any((MusicProvider p) => p.capabilities.streaming && !p.capabilities.localOnly);

  Future<void> dispose() async {
    for (final MusicProvider p in _providers) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _api.dispose();
  }
}
