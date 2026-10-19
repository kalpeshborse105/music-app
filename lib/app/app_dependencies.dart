import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/cache/cache_store.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/connectivity_service.dart';
import '../core/storage/download_store.dart';
import '../core/storage/library_store.dart';
import '../core/storage/queue_store.dart';
import '../core/storage/settings_store.dart';
import '../core/utils/logger.dart';
import '../data/music_repository.dart';
import '../data/provider_registry.dart';
import '../domain/playback/audio_handler.dart';
import '../domain/playback/playback_controller.dart';
import '../domain/providers/local_provider.dart';
import '../domain/recommendations/recommendation_engine.dart';
import '../state/search_controller.dart';
import '../state/downloads_controller.dart';
import '../state/library_controller.dart';
import '../data/services/deep_link_service.dart';
import '../data/services/fcm_service.dart';
import '../data/services/supabase_service.dart';

/// Holds every long-lived dependency. Constructed once during bootstrap so the
/// widget tree stays free of async initialization (fast, deterministic startup,
/// spec §37).
class AppDependencies {
  AppDependencies({
    required this.settings,
    required this.cache,
    required this.libraryStore,
    required this.queueStore,
    required this.downloadStore,
    required this.registry,
    required this.repository,
    required this.handler,
    required this.playback,
    required this.library,
    required this.downloads,
    required this.connectivity,
    required this.recommendations,
    required this.search,
    required this.localProvider,
  });

  final SettingsStore settings;
  final CacheStore cache;
  final LibraryStore libraryStore;
  final QueueStore queueStore;
  final DownloadStore downloadStore;
  final ProviderRegistry registry;
  final MusicRepository repository;
  final EchoAudioHandler handler;
  final PlaybackController playback;
  final LibraryController library;
  final DownloadsController downloads;
  final ConnectivityService connectivity;
  final RecommendationEngine recommendations;
  final SearchController search;
  final LocalMusicProvider? localProvider;

  /// Initializes local storage, providers, playback and controllers.
  ///
  /// Note: provider network availability checks and queue restore are kicked
  /// off *after* the first frame (see [KalpkrutBeatsApp]) so they never delay
  /// startup.
  static Future<AppDependencies> bootstrap() async {
    await Hive.initFlutter();

    final SettingsStore settings = SettingsStore();
    final CacheStore cache = CacheStore();
    final LibraryStore libraryStore = LibraryStore();
    final QueueStore queueStore = QueueStore();
    final DownloadStore downloadStore = DownloadStore();
    final ConnectivityService connectivity = ConnectivityService();

    await Future.wait<void>(<Future<void>>[
      settings.init(),
      cache.init(),
      libraryStore.init(),
      queueStore.init(),
      downloadStore.init(),
      connectivity.init(),
      SupabaseService().initialize(),
    ]);

    final ApiClient api = ApiClient();
    final ProviderRegistry registry = ProviderRegistry(
      api: api,
      cache: cache,
      settings: settings,
    );
    final MusicRepository repository = MusicRepository(
      registry: registry,
      downloadStore: downloadStore,
      settings: settings,
      cache: cache,
    );

    // Initialize the background audio service. If the platform doesn't support
    // it (e.g. some web contexts) fall back to a plain handler so playback and
    // the in-app UI still work.
    EchoAudioHandler handler;
    try {
      handler = await AudioService.init(
        builder: () => EchoAudioHandler(resolver: repository.resolveStream),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.kalpkrut.beats.audio',
          androidNotificationChannelName: AppConstants.appName,
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      Logger.warn('AudioService.init unavailable, using in-process handler', error: e);
      handler = EchoAudioHandler(resolver: repository.resolveStream);
    }

    final PlaybackController playback = PlaybackController(
      handler: handler,
      repository: repository,
      library: libraryStore,
      queueStore: queueStore,
      settings: settings,
    );
    final LibraryController library = LibraryController(store: libraryStore);
    final DownloadsController downloads = DownloadsController(
      repository: repository,
      settings: settings,
      store: downloadStore,
    );
    final RecommendationEngine recommendations =
        RecommendationEngine(repository: repository);
    final SearchController search = SearchController(repository: repository);
    final LocalMusicProvider? localProvider =
        registry.byId('local') as LocalMusicProvider?;

    return AppDependencies(
      settings: settings,
      cache: cache,
      libraryStore: libraryStore,
      queueStore: queueStore,
      downloadStore: downloadStore,
      registry: registry,
      repository: repository,
      handler: handler,
      playback: playback,
      library: library,
      downloads: downloads,
      connectivity: connectivity,
      recommendations: recommendations,
      search: search,
      localProvider: localProvider,
    );
  }

  /// Post-first-frame work that must not block startup (spec §37).
  Future<void> warmUp() async {
    // 1. Discover which providers are usable (network) — failure is isolated.
    await registry.initialize().catchError((Object e) {
      Logger.warn('registry init failed', error: e);
    });
    // 2. Fresh open: clear bottom player / queue (no stale mini-player).
    await playback.resetForFreshLaunch().catchError((Object e) {
      Logger.warn('fresh launch player reset failed', error: e);
    });
    // 3. FCM device token (no-op until Android google-services.json is added).
    await FcmService.instance.initialize().catchError((Object e) {
      Logger.warn('FCM warm-up skipped', error: e);
    });
    // 4. Share / App Links + FCM tap → open song/album/artist.
    await DeepLinkService.instance.start(repository).catchError((Object e) {
      Logger.warn('deep link warm-up skipped', error: e);
    });
  }

  Future<void> dispose() async {
    downloads.dispose();
    library.dispose();
    search.dispose();
    playback.dispose();
    await handler.disposeHandler();
    await registry.dispose();
    connectivity.dispose();
  }
}
