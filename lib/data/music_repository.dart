import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/cache/ttl_cache.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/storage/download_store.dart';
import '../core/storage/settings_store.dart';
import '../core/utils/logger.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/audio_quality.dart';
import '../domain/models/genre.dart';
import '../domain/models/lyrics.dart';
import '../domain/models/paged_result.dart';
import '../domain/models/playlist.dart';
import '../domain/models/search_result.dart';
import '../domain/models/stream_source.dart';
import '../domain/models/track.dart';
import '../domain/models/media_type.dart';
import '../domain/models/catalog_section.dart';
import '../domain/providers/custom_api_provider.dart';
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
  MusicRepository({
    required ProviderRegistry registry,
    DownloadStore? downloadStore,
    SettingsStore? settings,
  })  : _registry = registry,
        _downloadStore = downloadStore,
        _settings = settings;

  final ProviderRegistry _registry;
  final DownloadStore? _downloadStore;
  final SettingsStore? _settings;

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
          case 'custom_api':
            return 0;
          case 'licensed':
            return 1;
          case 'jamendo':
            return 2;
          case 'audius':
            return 3;
          case 'local':
            return 4;
          case 'archive':
            return 5;
          case 'demo':
            return 6;
          default:
            return 7;
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

    List<MusicProvider> providers = <MusicProvider>[
      ..._discoveryProviders,
      if (_registry.localProvider != null && _registry.isAvailable('local'))
        _registry.localProvider!,
    ];
    if (providers.isEmpty) {
      // Bounded retry/recovery before throwing error (Phase 8)
      await _registry.retryUnavailableProviders(force: true);
      providers = <MusicProvider>[
        ..._discoveryProviders,
        if (_registry.localProvider != null && _registry.isAvailable('local'))
          _registry.localProvider!,
      ];
      if (providers.isEmpty) {
        throw const ProviderException('none', message: 'No music service is available.');
      }
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

    final List<Track> deduped = _dedupeTracks(merged.tracks);
    // Rank tracks by search relevance to the actual query (Phase 8)
    deduped.sort((Track a, Track b) {
      final int scoreB = _scoreTrackRelevance(b, query);
      final int scoreA = _scoreTrackRelevance(a, query);
      return scoreB.compareTo(scoreA);
    });

    final SearchResult out = SearchResult(
      query: query,
      tracks: deduped,
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
  Future<List<Track>> trending({int limit = 20, int offset = 0, String? language}) =>
      _aggregateTracks((MusicProvider p) {
        if (p is CustomApiProvider && language != null && language.isNotEmpty && language.toLowerCase() != 'all') {
          return p.getTrending(limit: limit, offset: offset, language: language);
        }
        return p.getTrending(limit: limit, offset: offset);
      }, limit: limit, language: language);

  /// Paged trending feed preserving truthful has_more and total from backend
  Future<PagedResult<Track>> trendingPaged({int limit = 20, int offset = 0, String? language}) async {
    final bool isRegionalFilter = language != null &&
        language.isNotEmpty &&
        language.toLowerCase() != 'all';

    final List<MusicProvider> providers = isRegionalFilter
        ? _discoveryProviders
            .where((MusicProvider p) => p.id == 'custom_api' || p.id == 'regional')
            .toList()
        : _discoveryProviders;

    if (providers.isEmpty) {
      return const PagedResult<Track>(items: <Track>[], total: 0, hasMore: false);
    }

    for (final MusicProvider p in providers) {
      if (p is CustomApiProvider) {
        try {
          final PagedResult<Track> res = await (isRegionalFilter
              ? p.getTrending(limit: limit, offset: offset, language: language)
              : p.getTrending(limit: limit, offset: offset));
          final List<Track> deduped = _dedupeTracks(res.items);
          return PagedResult<Track>(
            items: deduped,
            total: res.total,
            nextOffset: offset + deduped.length,
            hasMore: res.hasMore,
          );
        } catch (e) {
          Logger.warn('CustomApiProvider trendingPaged error: $e');
        }
      }
    }

    final List<Track> tracks = await trending(limit: limit, offset: offset, language: language);
    return PagedResult<Track>(
      items: tracks,
      total: tracks.length,
      nextOffset: offset + tracks.length,
      hasMore: tracks.length >= limit,
    );
  }

  Future<List<Track>> newReleases({int limit = 20, int offset = 0, String? language}) =>
      _aggregateTracks((MusicProvider p) {
        if (p is CustomApiProvider && language != null && language.isNotEmpty && language.toLowerCase() != 'all') {
          return p.getNewReleases(limit: limit, offset: offset, language: language);
        }
        return p.getNewReleases(limit: limit, offset: offset);
      }, limit: limit, language: language);

  Future<List<Track>> recommendations({int limit = 20, int offset = 0, String? language}) =>
      _aggregateTracks((MusicProvider p) {
        if (p is CustomApiProvider && language != null && language.isNotEmpty && language.toLowerCase() != 'all') {
          return p.getRecommendations(limit: limit, offset: offset, language: language);
        }
        return p.getRecommendations(limit: limit, offset: offset);
      }, limit: limit, language: language);

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
    String? language,
  }) async {
    final bool isRegionalFilter = language != null &&
        language.isNotEmpty &&
        language.toLowerCase() != 'all';

    final List<MusicProvider> providers = isRegionalFilter
        ? _discoveryProviders
            .where((MusicProvider p) => p.id == 'custom_api' || p.id == 'regional')
            .toList()
        : _discoveryProviders;

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
      final String target = artist.name.isNotEmpty
          ? artist.name
          : (artist.id.contains(':') ? artist.id.split(':').last : artist.id);
      return await _providerFor(artist.providerId).getArtistTopTracks(target);
    } catch (_) {
      return <Track>[];
    }
  }

  Future<List<Album>> artistAlbums(Artist artist) async {
    try {
      final String target = artist.name.isNotEmpty
          ? artist.name
          : (artist.id.contains(':') ? artist.id.split(':').last : artist.id);
      return await _providerFor(artist.providerId).getArtistAlbums(target);
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
  }) async {
    // 1. Offline-First: If track is downloaded and file exists locally, load LOCAL FILE
    // without requesting remote stream URL or checking internet connectivity.
    if (_downloadStore != null) {
      final DownloadRecord? record = _downloadStore.get(track.id);
      if (record != null && record.filePath.isNotEmpty) {
        if (!kIsWeb) {
          final File localFile = File(record.filePath);
          if (localFile.existsSync() && localFile.lengthSync() > 0) {
            Logger.info('Loading offline track from local storage: ${record.filePath}');
            return StreamSource(
              url: Uri.file(record.filePath).toString(),
              supportsSeek: true,
            );
          }
        }
      }
    }

    // 2. Jamendo disabled guard (default OFF per project specification)
    if (track.providerId == 'jamendo' && _settings?.jamendoEnabled != true) {
      throw const ProviderException(
        'jamendo',
        message: 'Jamendo is currently disabled in provider settings.',
      );
    }

    // 3. Live Radio Broadcasts (Akashvani / All India Radio)
    if (track.providerId == 'radio') {
      return StreamSource(
        url: track.providerTrackId,
        supportsSeek: false,
      );
    }

    if (!track.isStreamable) {
      throw const TrackUnavailableException();
    }
    return _providerFor(track.providerId).getStream(track, quality: quality);
  }

  Future<Lyrics> lyrics(Track track) async {
    try {
      final MusicProvider p = _providerFor(track.providerId);
      if (p.capabilities.lyrics) {
        final Lyrics l = await p.getLyrics(track);
        if (!l.isEmpty) return l;
      }
    } catch (_) {}

    return _fetchLrclibLyrics(track);
  }

  Future<Lyrics> _fetchLrclibLyrics(Track track) async {
    try {
      final String artist = track.artistNames.split(',').first.trim();
      final String cleanTitle = track.title
          .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'feat\..*|ft\..*', caseSensitive: false), '')
          .trim();
      final Uri uri = Uri.parse('https://lrclib.net/api/get').replace(
        queryParameters: <String, String>{
          'artist_name': artist,
          'track_name': cleanTitle.isNotEmpty ? cleanTitle : track.title,
        },
      );
      final http.Response res = await http.get(uri, headers: const <String, String>{
        'User-Agent': 'KalpkrutBeats/1.0.1 (Android; Mobile)',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map) {
          final String? plain = data['plainLyrics']?.toString();
          final String? syncedStr = data['syncedLyrics']?.toString();
          final List<LyricLine> syncedLines = <LyricLine>[];

          if (syncedStr != null && syncedStr.isNotEmpty) {
            final List<String> lines = syncedStr.split('\n');
            final RegExp regex = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)');
            for (final String l in lines) {
              final RegExpMatch? m = regex.firstMatch(l.trim());
              if (m != null) {
                final int min = int.tryParse(m.group(1) ?? '0') ?? 0;
                final double sec = double.tryParse(m.group(2) ?? '0') ?? 0;
                final String text = m.group(3)?.trim() ?? '';
                syncedLines.add(LyricLine(
                  time: Duration(milliseconds: (min * 60000 + sec * 1000).round()),
                  text: text,
                ));
              }
            }
          }

          if (syncedLines.isNotEmpty || (plain != null && plain.trim().isNotEmpty)) {
            return Lyrics(
              trackId: track.id,
              plain: plain,
              synced: syncedLines,
              isSynced: syncedLines.isNotEmpty,
              source: 'LRCLIB Open Database',
            );
          }
        }
      }
    } catch (_) {}
    return Lyrics.unavailable;
  }

  Future<List<Track>> radio(Track seed, {int limit = 20}) async {
    try {
      final List<Track> tracks = await _providerFor(seed.providerId).getRadio(seed, limit: limit);
      return _dedupeTracks(tracks);
    } catch (_) {
      return <Track>[];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static final RegExp _variantRegex = RegExp(
    r'\b(remix|acoustic|live|lofi|lo-fi|version|unplugged|reprise|instrumental|cover|mix|edit|extended|deluxe|slowed|reverb|mashup)\b',
    caseSensitive: false,
  );

  static String _normalize(String s) {
    if (s.isEmpty) return '';
    String t = s.toLowerCase();
    t = t.replaceAllMapped(RegExp(r'[\(\[][^\)\]]*[\)\]]'), (Match m) {
      final String match = m.group(0) ?? '';
      return _variantRegex.hasMatch(match) ? match : '';
    });
    t = t.replaceAll(
      RegExp(r'\b(feat|ft|official|audio|video|soundtrack|hd|4k|lyrics|from the movie)\b', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp(r'[^\w\s]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isNotEmpty ? t : s.toLowerCase().trim();
  }

  List<Track> _dedupeTracks(List<Track> tracks) {
    final Set<String> seenIds = <String>{};
    // Map from normalized-title to (providerId, language) for scoped dedup.
    // Tracks with the same normalized title are only merged if they share
    // the same provider AND language — never across languages or providers.
    final Map<String, (String, String)> seenTitleScope = <String, (String, String)>{};
    final List<Track> out = <Track>[];
    for (final Track t in tracks) {
      final String cleanId = t.id.toLowerCase().trim();
      if (!seenIds.add(cleanId)) continue;

      final String normTitle = _normalize(t.title);
      if (normTitle.isNotEmpty) {
        final String langKey = (t.extra['language'] as String? ?? '').toLowerCase();
        final String provKey = t.providerId;
        final (String, String) scope = (provKey, langKey);
        final (String, String)? existing = seenTitleScope[normTitle];
        if (existing != null && existing == scope) {
          // Same provider + same language: suppress duplicate
          continue;
        }
        if (existing == null) {
          seenTitleScope[normTitle] = scope;
        }
        // Different provider OR different language: allow (remixes, covers, language versions)
      }
      out.add(t);
    }
    return out;
  }

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
    final List<Track> combined = <Track>[];
    for (int index = 0; ; index++) {
      bool anyAdded = false;
      for (final List<Track> list in lists) {
        if (index < list.length) {
          combined.add(list[index]);
          anyAdded = true;
        }
      }
      if (!anyAdded) break;
    }
    final List<Track> deduped = _dedupeTracks(combined);
    return deduped.length > limit ? deduped.sublist(0, limit) : deduped;
  }

  int _scoreTrackRelevance(Track t, String query) {
    final String q = query.toLowerCase().trim();
    if (q.isEmpty) return 10;
    final String title = t.title.toLowerCase().trim();
    final String artists = t.artistNames.toLowerCase().trim();
    final String album = (t.album?.title ?? '').toLowerCase().trim();

    if (title == q) return 100;
    if (artists == q) return 95;
    if (title.startsWith(q)) return 85;
    if (artists.startsWith(q)) return 80;
    if (title.contains(q)) return 70;
    if (artists.contains(q)) return 65;
    if (album.contains(q)) return 50;

    final List<String> tokens = q.split(RegExp(r'\s+')).where((String s) => s.length > 1).toList();
    if (tokens.isNotEmpty) {
      int tokenHits = 0;
      for (final String tok in tokens) {
        if (title.contains(tok) || artists.contains(tok) || album.contains(tok)) {
          tokenHits++;
        }
      }
      if (tokenHits > 0) return 30 + (tokenHits * 10);
    }
    return 10;
  }

  // ─── Catalogue Management ──────────────────────────────────────────────────
  CustomApiProvider? get _customApiProvider => _registry.byId('custom_api') as CustomApiProvider?;

  Future<List<CatalogSection>> getCatalogSections({
    bool includeDisabled = false,
    String? lang,
    String? group,
  }) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return <CatalogSection>[];
    final List<Map<String, dynamic>> raw = await provider.getCatalogSections(
      includeDisabled: includeDisabled,
      lang: lang,
      group: group,
    );
    return raw.map((Map<String, dynamic> m) => CatalogSection.fromJson(m)).toList();
  }

  Future<Map<String, dynamic>> previewCatalogUrl(String url) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return <String, dynamic>{'valid': false, 'error': 'Custom API provider unavailable'};
    return provider.previewCatalogUrl(url);
  }

  Future<CatalogSection?> createCatalogSection({
    required String sourceUrl,
    required String displayTitle,
    required String displayGroup,
    String? subtitle,
    String language = 'all',
    int position = 1,
    bool isEnabled = true,
    String? customArtworkUrl,
    bool isBanner = false,
    int? campaignStart,
    int? campaignEnd,
    List<String>? excludedTrackIds,
    List<Map<String, dynamic>>? customTracks,
  }) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) {
      throw const ProviderException('custom_api', message: 'Custom API provider unavailable.');
    }
    final Map<String, dynamic> res = await provider.createCatalogSection(<String, dynamic>{
      'source_url': sourceUrl,
      'display_title': displayTitle,
      'display_group': displayGroup,
      if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
      'language': language,
      'position': position,
      'is_enabled': isEnabled,
      if (customArtworkUrl != null && customArtworkUrl.isNotEmpty) 'custom_artwork_url': customArtworkUrl,
      'is_banner': isBanner,
      if (campaignStart != null) 'campaign_start': campaignStart,
      if (campaignEnd != null) 'campaign_end': campaignEnd,
      if (excludedTrackIds != null) 'excluded_track_ids': excludedTrackIds,
      if (customTracks != null) 'custom_tracks': customTracks,
    });
    final CatalogSection section = CatalogSection.fromJson(res);

    // Verify persistence with read-back from source of truth (Phase 2 & 6)
    final List<CatalogSection> readBack = await getCatalogSections(includeDisabled: true);
    final bool exists = readBack.any((CatalogSection s) => s.key == section.key || s.id == section.id);
    if (!exists) {
      throw ProviderException('custom_api', message: 'Persistence verification failed: section "${section.displayTitle}" was not saved.');
    }
    return section;
  }

  Future<CatalogSection?> updateCatalogSection(
    String key, {
    String? sourceUrl,
    String? displayTitle,
    String? displayGroup,
    String? subtitle,
    String? language,
    int? position,
    bool? isEnabled,
    String? customArtworkUrl,
    bool? isBanner,
    int? campaignStart,
    int? campaignEnd,
    List<String>? excludedTrackIds,
    List<Map<String, dynamic>>? customTracks,
  }) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) {
      throw const ProviderException('custom_api', message: 'Custom API provider unavailable.');
    }
    final Map<String, dynamic> data = <String, dynamic>{
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (displayTitle != null) 'display_title': displayTitle,
      if (displayGroup != null) 'display_group': displayGroup,
      if (subtitle != null) 'subtitle': subtitle,
      if (language != null) 'language': language,
      if (position != null) 'position': position,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (customArtworkUrl != null) 'custom_artwork_url': customArtworkUrl,
      if (isBanner != null) 'is_banner': isBanner,
      if (campaignStart != null) 'campaign_start': campaignStart,
      if (campaignEnd != null) 'campaign_end': campaignEnd,
      if (excludedTrackIds != null) 'excluded_track_ids': excludedTrackIds,
      if (customTracks != null) 'custom_tracks': customTracks,
    };
    final Map<String, dynamic> res = await provider.updateCatalogSection(key, data);
    final CatalogSection section = CatalogSection.fromJson(res);

    // Verify persistence with read-back from source of truth (Phase 2 & 6)
    final List<CatalogSection> readBack = await getCatalogSections(includeDisabled: true);
    final bool exists = readBack.any((CatalogSection s) =>
        s.key.toLowerCase().replaceAll('-', '_') == key.toLowerCase().replaceAll('-', '_') ||
        s.id == section.id ||
        s.key == key);
    if (!exists) {
      throw ProviderException('custom_api', message: 'Persistence verification failed: updated section "$key" could not be verified.');
    }
    return section;
  }

  Future<Track?> resolveTrack(String urlOrId) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return null;
    final Map<String, dynamic> res = await provider.resolveTrack(urlOrId);
    if (res['valid'] == true && res['track'] != null) {
      final Map<String, dynamic> item = res['track'] as Map<String, dynamic>;
      final String trackId = item['id'] as String? ?? '';
      final String title = item['title'] as String? ?? 'Untitled';
      final String artist = item['artist'] as String? ?? 'Unknown Artist';
      final String? artworkUrl = item['artwork_url'] as String?;
      final int durationMs = (item['duration_ms'] as num?)?.toInt() ?? 210000;
      final bool isMock = item['is_mock'] == true;
      return Track(
        id: 'custom_api:track:$trackId',
        providerId: 'custom_api',
        providerTrackId: trackId,
        title: title,
        artists: <Artist>[
          Artist(
            id: 'custom_api:artist:$artist',
            providerId: 'custom_api',
            providerArtistId: artist,
            name: artist,
          ),
        ],
        album: Album(
          id: 'custom_api:album:$trackId',
          providerId: 'custom_api',
          providerAlbumId: trackId,
          title: item['album'] as String? ?? 'Single',
          artworkUrl: artworkUrl,
        ),
        duration: Duration(milliseconds: durationMs),
        artworkUrl: artworkUrl,
        explicit: false,
        mediaType: MediaType.audio,
        isStreamable: true,
        isDownloadable: false,
        hasLyrics: false,
        qualityOptions: const <AudioQuality>[AudioQuality.high],
        commercialUseAllowed: false,
        backgroundPlaybackAllowed: true,
        license: isMock ? 'Mock Development License' : 'Cloud Gateway Stream',
        attributionRequired: false,
        extra: <String, dynamic>{
          'is_mock': isMock,
          'language': item['language'] ?? '',
          'year': item['year'] ?? '',
        },
      );
    }
    return null;
  }

  Future<bool> deleteCatalogSection(String key) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return false;
    return provider.deleteCatalogSection(key);
  }

  Future<bool> reorderCatalogSections(List<String> keys) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return false;
    return provider.reorderCatalogSections(keys);
  }

  Future<CatalogSection?> toggleCatalogSection(String key, [bool? enabled]) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return null;
    final Map<String, dynamic> res = await provider.toggleCatalogSection(key);
    return CatalogSection.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Radio & Library Category Admin Operations
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchRadioStations() async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return <Map<String, dynamic>>[];
    return provider.fetchRadioStations();
  }

  Future<Map<String, dynamic>> createRadioStation(Map<String, dynamic> data) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) throw const ProviderException('custom_api', message: 'Custom API provider not configured');
    return provider.createRadioStation(data);
  }

  Future<Map<String, dynamic>> updateRadioStation(String stationId, Map<String, dynamic> data) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) throw const ProviderException('custom_api', message: 'Custom API provider not configured');
    return provider.updateRadioStation(stationId, data);
  }

  Future<bool> deleteRadioStation(String stationId) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return false;
    return provider.deleteRadioStation(stationId);
  }

  Future<List<Map<String, dynamic>>> fetchLibraryCategories() async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return <Map<String, dynamic>>[];
    return provider.fetchLibraryCategories();
  }

  Future<Map<String, dynamic>> createLibraryCategory(Map<String, dynamic> data) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) throw const ProviderException('custom_api', message: 'Custom API provider not configured');
    return provider.createLibraryCategory(data);
  }

  Future<Map<String, dynamic>> updateLibraryCategory(String catId, Map<String, dynamic> data) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) throw const ProviderException('custom_api', message: 'Custom API provider not configured');
    return provider.updateLibraryCategory(catId, data);
  }

  Future<bool> deleteLibraryCategory(String catId) async {
    final CustomApiProvider? provider = _customApiProvider;
    if (provider == null) return false;
    return provider.deleteLibraryCategory(catId);
  }
}
