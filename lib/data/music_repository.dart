import '../core/cache/ttl_cache.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/logger.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/audio_quality.dart';
import '../domain/models/genre.dart';
import '../domain/models/lyrics.dart';
import '../domain/models/playlist.dart';
import '../domain/models/search_result.dart';
import '../domain/models/stream_source.dart';
import '../domain/models/track.dart';
import '../domain/providers/music_provider.dart';
import 'provider_registry.dart';

/// A genre together with the provider that owns it.
class GenreRef {
  final Genre genre;
  final String providerId;
  const GenreRef({required this.genre, required this.providerId});
}

/// The app-facing music API. Aggregates providers behind a single surface and
/// routes per-track operations back to the *owning* provider. The UI never
/// talks to a concrete provider directly (spec §29).
class MusicRepository {
  MusicRepository({required ProviderRegistry registry}) : _registry = registry;

  final ProviderRegistry _registry;

  // Aggregate result caches for the hot discovery path.
  final TtlCache<String, SearchResult> _searchCache =
      TtlCache<String, SearchResult>(ttl: AppConstants.searchCacheTtl, maxEntries: 40);

  MusicProvider _providerFor(String providerId) {
    final MusicProvider? p = _registry.byId(providerId);
    if (p == null) {
      throw ProviderException(providerId, message: 'Unknown music source.');
    }
    if (!_registry.isAvailable(providerId) && !p.capabilities.localOnly) {
      throw ProviderException.unavailable(providerId);
    }
    return p;
  }

  /// The set of providers Home/Search should aggregate, in priority order.
  List<MusicProvider> get _discoveryProviders {
    final List<MusicProvider> list = _registry.discoveryProviders;
    // Interleave: prefer a configured licensed provider first when present.
    list.sort((MusicProvider a, MusicProvider b) {
      int rank(MusicProvider p) {
        switch (p.id) {
          case 'licensed':
            return 0;
          case 'jamendo':
            return 1;
          case 'archive':
            return 2;
          case 'demo':
            return 3;
          default:
            return 4;
        }
      }

      return rank(a).compareTo(rank(b));
    });
    return list;
  }

  // ---------------------------------------------------------------------------
  // Search (provider aggregation)
  // ---------------------------------------------------------------------------
  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = AppConstants.defaultPageSize,
  }) async {
    final String q = query.trim();
    if (q.isEmpty) return SearchResult.empty;

    final List<MusicProvider> providers = _discoveryProviders;
    if (providers.isEmpty) {
      throw const ProviderException('none', message: 'No music service is available.');
    }

    // Cache only the first page (the common case); later pages are paginated.
    final String cacheKey = 'search:${q.toLowerCase()}:$offset:$limit';
    if (offset == 0) {
      final SearchResult? cached = _searchCache.get(cacheKey);
      if (cached != null) return cached;
    }

    // Query providers concurrently, isolating failures so one bad provider does
    // not break search (spec §29/§41).
    final List<Future<SearchResult>> futures = providers.map((MusicProvider p) async {
      try {
        return await p.search(q, offset: offset, limit: limit);
      } catch (e) {
        Logger.warn('Search failed on ${p.id}', error: e);
        return SearchResult.empty;
      }
    }).toList();

    final List<SearchResult> results = await Future.wait(futures);
    SearchResult merged = SearchResult.empty;
    for (final SearchResult r in results) {
      merged = merged.merge(r);
    }
    final SearchResult out = SearchResult(
      query: query,
      tracks: _dedupeTracks(merged.tracks),
      artists: _dedupeBy(merged.artists, (Artist a) => a.id),
      albums: _dedupeBy(merged.albums, (Album a) => a.id),
      playlists: _dedupeBy(merged.playlists, (Playlist p) => p.id),
    );
    if (offset == 0 && !out.isEmpty) {
      _searchCache.set(cacheKey, out);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Discovery feeds (merged + de-duplicated)
  // ---------------------------------------------------------------------------
  Future<List<Track>> trending({int limit = 20}) =>
      _aggregateTracks((MusicProvider p) => p.getTrending(limit: limit), limit: limit);

  Future<List<Track>> newReleases({int limit = 20}) =>
      _aggregateTracks((MusicProvider p) => p.getNewReleases(limit: limit), limit: limit);

  Future<List<Track>> recommendations({int limit = 20}) =>
      _aggregateTracks((MusicProvider p) => p.getRecommendations(limit: limit), limit: limit);

  Future<List<GenreRef>> genres({int perProvider = 20}) async {
    final List<MusicProvider> providers = _discoveryProviders;
    final List<Future<List<GenreRef>>> futures = providers.map((MusicProvider p) async {
      try {
        if (!p.capabilities.browse) return <GenreRef>[];
        final dynamic page = await p.getGenres();
        return (page.items as List<Genre>)
            .map((Genre g) => GenreRef(genre: g, providerId: p.id))
            .toList();
      } catch (_) {
        return <GenreRef>[];
      }
    }).toList();
    final List<List<GenreRef>> all = await Future.wait(futures);
    final Map<String, GenreRef> unique = <String, GenreRef>{};
    for (final List<GenreRef> list in all) {
      for (final GenreRef g in list) {
        unique.putIfAbsent(g.genre.id, () => g);
      }
    }
    return unique.values.toList();
  }

  Future<List<Track>> tracksByGenre(String providerId, String genreId,
      {int limit = 30}) async {
    final MusicProvider p = _providerFor(providerId);
    final dynamic page = await p.getTracksByGenre(genreId, limit: limit);
    return page.items as List<Track>;
  }

  Future<List<Track>> _aggregateTracks(
    Future<dynamic> Function(MusicProvider) fetch, {
    required int limit,
  }) async {
    final List<MusicProvider> providers = _discoveryProviders;
    if (providers.isEmpty) return <Track>[];
    final List<Future<List<Track>>> futures = providers.map((MusicProvider p) async {
      try {
        final dynamic page = await fetch(p);
        return (page.items as List<Track>);
      } catch (e) {
        Logger.warn('Feed failed on ${p.id}', error: e);
        return <Track>[];
      }
    }).toList();
    final List<List<Track>> all = await Future.wait(futures);
    // Round-robin interleave so no single provider dominates the feed.
    final List<Track> interleaved = _interleave(all, limit);
    return _dedupeTracks(interleaved);
  }

  // ---------------------------------------------------------------------------
  // Entity retrieval
  // ---------------------------------------------------------------------------
  Future<Track> refreshTrack(Track track) async {
    try {
      return await _providerFor(track.providerId).getTrack(track.id);
    } catch (_) {
      return track;
    }
  }

  Future<Album> getAlbum(Album album) =>
      _providerFor(album.providerId).getAlbum(album.id);

  Future<Artist> getArtist(Artist artist) =>
      _providerFor(artist.providerId).getArtist(artist.id);

  Future<List<Track>> artistTopTracks(Artist artist) async {
    try {
      return await _providerFor(artist.providerId).getArtistTopTracks(artist.id);
    } catch (_) {
      return <Track>[];
    }
  }

  Future<List<Album>> artistAlbums(Artist artist) async {
    try {
      return await _providerFor(artist.providerId).getArtistAlbums(artist.id);
    } catch (_) {
      return <Album>[];
    }
  }

  Future<List<Artist>> similarArtists(Artist artist) async {
    try {
      return await _providerFor(artist.providerId).getSimilarArtists(artist.id);
    } catch (_) {
      return <Artist>[];
    }
  }

  Future<Album> albumTracks(Album album) =>
      _providerFor(album.providerId).getAlbum(album.id);

  /// Returns the tracks belonging to [album]. Providers expose album metadata
  /// without a track list, so we resolve tracks via a search scoped to the
  /// album title and filter by album id (with a sensible fallback).
  Future<List<Track>> albumTrackList(Album album) async {
    try {
      final SearchResult r = await _providerFor(album.providerId)
          .search(album.title, offset: 0, limit: 30);
      final List<Track> matched = r.tracks
          .where((Track t) => t.album?.id == album.id)
          .toList();
      return matched.isNotEmpty ? matched : r.tracks;
    } catch (_) {
      try {
        return await _providerFor(album.providerId).getArtistTopTracks(
          album.artists.isNotEmpty ? album.artists.first.id : '');
      } catch (_) {
        return <Track>[];
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Streams + lyrics
  // ---------------------------------------------------------------------------
  /// Resolve a playable stream for [track] from its owning provider.
  ///
  /// Provider fallback (spec §41) is intentionally NOT performed here: we never
  /// silently substitute a different source that may not have rights to the
  /// track. If the owning provider cannot serve it, the user sees an honest
  /// unavailable state.
  Future<StreamSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.auto,
  }) {
    if (!track.isStreamable) {
      throw const TrackUnavailableException();
    }
    return _providerFor(track.providerId).getStream(track, quality: quality);
  }

  Future<Lyrics> lyrics(Track track) async {
    final MusicProvider p = _providerFor(track.providerId);
    if (!p.capabilities.lyrics) return Lyrics.unavailable;
    try {
      return await p.getLyrics(track);
    } catch (_) {
      return Lyrics.unavailable;
    }
  }

  Future<List<Track>> radio(Track seed, {int limit = 20}) async {
    try {
      return await _providerFor(seed.providerId).getRadio(seed, limit: limit);
    } catch (_) {
      return <Track>[];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  List<Track> _dedupeTracks(List<Track> tracks) =>
      _dedupeBy(tracks, (Track t) => t.id);

  List<T> _dedupeBy<T>(List<T> items, String Function(T) keyOf) {
    final Set<String> seen = <String>{};
    final List<T> out = <T>[];
    for (final T item in items) {
      final String key = keyOf(item);
      if (seen.add(key)) out.add(item);
    }
    return out;
  }

  List<Track> _interleave(List<List<Track>> lists, int limit) {
    final List<Track> out = <Track>[];
    final Set<String> seen = <String>{};
    int index = 0;
    bool progressed = true;
    while (out.length < limit && progressed) {
      progressed = false;
      for (final List<Track> list in lists) {
        if (index < list.length) {
          final Track t = list[index];
          if (seen.add(t.id)) {
            out.add(t);
            progressed = true;
            if (out.length >= limit) break;
          }
        }
      }
      index++;
    }
    return out;
  }
}
