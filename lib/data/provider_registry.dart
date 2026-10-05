import '../core/cache/cache_store.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/settings_store.dart';
import '../core/utils/logger.dart';
import '../domain/models/provider_compliance_record.dart';
import '../domain/models/provider_status.dart';
import '../domain/providers/archive_provider.dart';
import '../domain/providers/audius_provider.dart';
import '../domain/providers/custom_api_provider.dart';
import '../domain/providers/demo_provider.dart';
import '../domain/providers/jamendo_provider.dart';
import '../domain/providers/licensed_provider_stub.dart';
import '../domain/providers/listenfree_provider.dart';
import '../domain/providers/local_provider.dart';
import '../domain/providers/music_provider.dart';
import '../domain/providers/regional_music_provider.dart';

/// Builds, owns and exposes all configured providers, and tracks which are
/// currently usable. Adding a new legal provider is a one-line change here —
/// nothing else in the app depends on concrete providers (spec §29).
class ProviderRegistry {
  ProviderRegistry({
    ApiClient? api,
    required CacheStore cache,
    SettingsStore? settings,
  })  : _api = api ?? ApiClient(),
        _cache = cache,
        _settings = settings {
    _providers = <MusicProvider>[
      DemoProvider(api: _api, cache: _cache),
      ArchiveProvider(api: _api, cache: _cache),
      JamendoProvider(api: _api, cache: _cache),
      AudiusProvider(api: _api, cache: _cache),
      LocalMusicProvider(api: _api, cache: _cache),
      RegionalMusicProvider(api: _api, cache: _cache),
      LicensedProviderStub(api: _api, cache: _cache),
      ListenFreeProvider(api: _api, cache: _cache),
      CustomApiProvider(api: _api, cache: _cache),
    ];
  }

  final ApiClient _api;
  final CacheStore _cache;
  final SettingsStore? _settings;
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

  bool isAvailable(String providerId) {
    if (providerId == 'jamendo' && _settings?.jamendoEnabled != true) {
      return false;
    }
    if (providerId == 'audius' && _settings?.audiusEnabled == false) {
      return false;
    }
    if (providerId == 'archive' && _settings?.archiveEnabled == false) {
      return false;
    }
    if (providerId == 'local' && _settings?.localEnabled == false) {
      return false;
    }
    if (providerId == 'regional_indian' && _settings?.regionalEnabled != true) {
      return false;
    }
    if (providerId == 'custom_api' && _settings?.customApiEnabled == false) {
      return false;
    }
    return !_unavailable.contains(providerId);
  }

  /// Providers that should feed the aggregate Home/Search experience, in
  /// priority order. Excludes purely-local content (surfaced separately).
  /// Enforces Provider Compliance: only ACTIVE and ENABLED providers appear in the catalog.
  List<MusicProvider> get discoveryProviders => available
      .where((MusicProvider p) {
        if (!p.status.isProductionActive || p.capabilities.localOnly || p.id == 'licensed') {
          return false;
        }
        // Jamendo is default OFF per project specification
        if (p.id == 'jamendo' && _settings?.jamendoEnabled != true) {
          return false;
        }
        if (p.id == 'audius' && _settings?.audiusEnabled == false) {
          return false;
        }
        if (p.id == 'archive' && _settings?.archiveEnabled == false) {
          return false;
        }
        if (p.id == 'regional_indian' && _settings?.regionalEnabled != true) {
          return false;
        }
        if (p.id == 'custom_api' && _settings?.customApiEnabled == false) {
          return false;
        }
        return true;
      })
      .toList();

  MusicProvider? get localProvider {
    if (_settings?.localEnabled == false) return null;
    return byId('local')?.capabilities.localOnly == true ? byId('local') : null;
  }

  /// Generates formal, audit-ready compliance records for every registered provider.
  List<ProviderComplianceRecord> get complianceRecords => <ProviderComplianceRecord>[
        ProviderComplianceRecord(
          provider: 'audius',
          displayName: 'Audius Discovery Protocol',
          enabled: _settings?.audiusEnabled ?? false,
          searchSupported: true,
          streamSupported: true,
          downloadSupported: false,
          commercialUseStatus: 'RESTRICTED / STREAM ONLY',
          backgroundPlaybackStatus: 'SUPPORTED',
          license: 'Audius Protocol Streaming License',
          licenseUrl: 'https://audius.co/legal/terms-of-use',
          sourceUrl: 'https://api.audius.co',
          attributionRequired: true,
          status: (_settings?.audiusEnabled ?? false)
              ? ProviderStatus.active
              : ProviderStatus.disabled,
        ),
        ProviderComplianceRecord(
          provider: 'archive',
          displayName: 'Internet Archive (Live Music)',
          enabled: _settings?.archiveEnabled ?? false,
          searchSupported: true,
          streamSupported: true,
          downloadSupported: true,
          commercialUseStatus: 'NON-COMMERCIAL / PUBLIC DOMAIN',
          backgroundPlaybackStatus: 'SUPPORTED',
          license: 'Public Domain / Creative Commons / Open Access',
          licenseUrl: 'https://archive.org/about/terms.php',
          sourceUrl: 'https://archive.org',
          attributionRequired: true,
          status: (_settings?.archiveEnabled ?? false)
              ? ProviderStatus.active
              : ProviderStatus.disabled,
        ),
        ProviderComplianceRecord(
          provider: 'local',
          displayName: 'Local Device MediaStore',
          enabled: _settings?.localEnabled ?? false,
          searchSupported: true,
          streamSupported: true,
          downloadSupported: true,
          commercialUseStatus: 'USER OWNED / PRIVATE PLAYBACK',
          backgroundPlaybackStatus: 'SUPPORTED',
          license: 'Local Scoped Storage / User-Owned Audio',
          licenseUrl: 'content://media/external/audio/media',
          sourceUrl: 'content://media/external/audio/media',
          attributionRequired: false,
          status: (_settings?.localEnabled ?? false)
              ? ProviderStatus.active
              : ProviderStatus.disabled,
        ),
        ProviderComplianceRecord(
          provider: 'jamendo',
          displayName: 'Jamendo Music API',
          enabled: _settings?.jamendoEnabled ?? false,
          searchSupported: true,
          streamSupported: true,
          downloadSupported: false,
          commercialUseStatus: 'CREATIVE COMMONS / PRO LICENSE REQUIRED',
          backgroundPlaybackStatus: 'SUPPORTED',
          license: 'Creative Commons 3.0 / Jamendo Licensing',
          licenseUrl: 'https://licensing.jamendo.com',
          sourceUrl: 'https://api.jamendo.com/v3.0',
          attributionRequired: true,
          status: (_settings?.jamendoEnabled ?? false)
              ? ProviderStatus.active
              : ProviderStatus.disabled,
        ),
        ProviderComplianceRecord(
          provider: 'regional_indian',
          displayName: 'Regional Indian Music Catalog',
          enabled: _settings?.regionalEnabled ?? false,
          searchSupported: true,
          streamSupported: false,
          downloadSupported: false,
          commercialUseStatus: 'PENDING COMMERCIAL PARTNER AGREEMENT',
          backgroundPlaybackStatus: 'PENDING',
          license: 'Direct Publisher License (Pending Execution)',
          licenseUrl: 'https://echoflowmusic.com/legal/licenses',
          sourceUrl: 'https://catalog.echoflowmusic.com/v1/indic',
          attributionRequired: true,
          status: ProviderStatus.licensePending,
        ),
        const ProviderComplianceRecord(
          provider: 'listenfree',
          displayName: 'ListenFree Unverified Gateway',
          enabled: false,
          searchSupported: false,
          streamSupported: false,
          downloadSupported: false,
          commercialUseStatus: 'UNVERIFIED / UNAUTHORIZED',
          backgroundPlaybackStatus: 'NOT SUPPORTED',
          license: 'Unverified Public Gateway',
          licenseUrl: 'https://echoflowmusic.com/compliance',
          sourceUrl: 'https://github.com/listenfree',
          attributionRequired: true,
          status: ProviderStatus.disabled,
        ),
        ProviderComplianceRecord(
          provider: 'custom_api',
          displayName: 'Cloud Audio Gateway (Self-Hosted)',
          enabled: _settings?.customApiEnabled ?? true,
          searchSupported: true,
          streamSupported: true,
          downloadSupported: false,
          commercialUseStatus: 'PRIVATE SELF-HOSTED GATEWAY',
          backgroundPlaybackStatus: 'SUPPORTED',
          license: 'Private Microservice Proxy',
          licenseUrl: '${AppConfig.customApiUrl}/docs',
          sourceUrl: AppConfig.customApiUrl,
          attributionRequired: false,
          status: (_settings?.customApiEnabled ?? true)
              ? ProviderStatus.active
              : ProviderStatus.disabled,
        ),
      ];

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
