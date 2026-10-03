import '../../core/cache/cache_store.dart';
import '../../core/cache/request_deduplicator.dart';
import '../../core/network/api_client.dart';
import 'music_provider.dart';

/// Shared plumbing for network-backed providers: an HTTP client, a persistent
/// TTL cache and a request deduplicator.
///
/// Concrete providers map provider payloads to normalized models and use
/// [cache] to memoise raw JSON responses we are permitted to keep (metadata
/// only — never restricted audio content, spec §11/§30).
abstract class BaseMusicProvider implements MusicProvider {
  final ApiClient api;
  final CacheStore cache;
  final RequestDeduplicator dedup = RequestDeduplicator();

  BaseMusicProvider({required this.api, required this.cache});

  /// Runs [loader] through the deduplicator so concurrent identical requests
  /// only hit the network once (spec §38).
  Future<T> coalesce<T>(String key, Future<T> Function() loader) =>
      dedup.run<T>(key, loader);
}
