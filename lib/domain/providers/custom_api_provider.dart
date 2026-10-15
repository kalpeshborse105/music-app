import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/supabase_service.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/audio_quality.dart';
import '../models/genre.dart';
import '../models/lyrics.dart';
import '../models/media_type.dart';
import '../models/paged_result.dart';
import '../models/playlist.dart';
import '../models/provider_capabilities.dart';
import '../models/provider_status.dart';
import '../models/search_result.dart';
import '../models/stream_source.dart';
import '../models/track.dart';
import 'base_provider.dart';

/// CustomApiProvider — Connects to the user's self-hosted Python FastAPI
/// backend gateway with in-memory caching and high-concurrency streaming.
class CustomApiProvider extends BaseMusicProvider {
  CustomApiProvider({
    required super.api,
    required super.cache,
  });

  @override
  String get id => 'custom_api';

  @override
  String get displayName => 'Cloud Gateway';

  @override
  ProviderStatus get status => ProviderStatus.active;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: false,
        backgroundPlayback: true,
        lyrics: false,
        playlists: false,
        favorites: true,
        radio: true,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: false,
        qualityTiers: <String>['High (320k)', 'Lossless (m4a)'],
      );

  String get _baseUrl => AppConfig.customApiUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async {
    if (_baseUrl.isEmpty) return false;
    try {
      final Uri uri = Uri.parse('$_baseUrl/health');
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        return data is Map && (data['status'] == 'online' || data['status'] == 'healthy');
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = 20,
    String? cursor,
  }) async {
    if (_baseUrl.isEmpty) {
      return SearchResult(query: query, tracks: const <Track>[]);
    }

    final int page = (offset ~/ limit) + 1;
    final Uri uri = Uri.parse('$_baseUrl/api/search').replace(
      queryParameters: <String, String>{
        'q': query,
        'limit': limit.toString(),
        'p': page.toString(),
      },
    );

    try {
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return SearchResult(query: query, tracks: const <Track>[]);
      }

      final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];

      final List<Track> tracks = rawTracks.map((dynamic item) {
        return _mapTrack(item as Map<String, dynamic>);
      }).toList();

      final Map<String, Artist> artistMap = <String, Artist>{};
      final Map<String, Album> albumMap = <String, Album>{};

      for (final Track t in tracks) {
        for (final Artist a in t.artists) {
          final String key = a.name.trim().toLowerCase();
          if (key.isNotEmpty && !artistMap.containsKey(key)) {
            artistMap[key] = a;
          }
        }
        if (t.album != null && t.album!.title.trim().isNotEmpty) {
          final String key = t.album!.title.trim().toLowerCase();
          if (!albumMap.containsKey(key)) {
            albumMap[key] = t.album!;
          }
        }
      }

      return SearchResult(
        query: query,
        tracks: tracks,
        artists: artistMap.values.toList(),
        albums: albumMap.values.toList(),
      );
    } catch (e) {
      debugPrint('[CustomApiProvider] Search error: $e');
      return SearchResult(query: query, tracks: const <Track>[]);
    }
  }

  @override
  Future<StreamSource> getStream(Track track, {AudioQuality quality = AudioQuality.auto}) async {
    final String trackId = track.providerTrackId;
    if (_baseUrl.isEmpty) {
      throw ProviderException(id, message: 'Custom API base URL is not configured');
    }

    // Direct proxy stream endpoint for zero-block playback across all networks
    return StreamSource(
      url: '$_baseUrl/api/play/$trackId',
      codec: 'mp4',
      bitrateKbps: 320,
      qualityTier: 'Lossless',
      supportsSeek: true,
    );
  }

  @override
  Future<Track> getTrack(String trackId) async {
    final String cleanId = trackId.contains(':') ? trackId.split(':').last : trackId;
    final Uri uri = Uri.parse('$_baseUrl/api/track/$cleanId');

    try {
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        return _mapTrack(data);
      }
    } catch (_) {}

    throw ProviderException(id, message: 'Track $trackId not found on gateway');
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20, String? language}) async {
    if (_baseUrl.isEmpty) {
      return const PagedResult<Track>(items: <Track>[], total: 0);
    }

    final int page = (offset ~/ limit) + 1;
    final Map<String, String> queryParams = <String, String>{
      'limit': limit.toString(),
      'p': page.toString(),
    };
    if (language != null && language.isNotEmpty && language.toLowerCase() != 'all') {
      queryParams['lang'] = language.toLowerCase();
    }

    final Uri uri = Uri.parse('$_baseUrl/api/trending').replace(
      queryParameters: queryParams,
    );

    try {
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
        final List<Track> tracks = rawTracks.map((dynamic item) {
          return _mapTrack(item as Map<String, dynamic>);
        }).toList();
        // Respect the backend's has_more and real pool_size; never default to 1000
        final bool hasMore = (body['has_more'] as bool?) ?? rawTracks.isNotEmpty;
        final int total = (body['total'] as num?)?.toInt() ??
            (body['pool_size'] as num?)?.toInt() ??
            (hasMore ? (offset + tracks.length + 1) : (offset + tracks.length));
        return PagedResult<Track>(items: tracks, total: total, hasMore: hasMore);
      } else {
        debugPrint('[CustomApiProvider] getTrending HTTP ${res.statusCode} for $uri');
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getTrending error: $e');
    }

    return const PagedResult<Track>(items: <Track>[], total: 0);
  }

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20, String? language}) async {
    if (_baseUrl.isEmpty) {
      return const PagedResult<Track>(items: <Track>[], total: 0);
    }

    final int page = (offset ~/ limit) + 1;
    final Map<String, String> queryParams = <String, String>{
      'limit': limit.toString(),
      'p': page.toString(),
    };
    if (language != null && language.isNotEmpty && language.toLowerCase() != 'all') {
      queryParams['lang'] = language.toLowerCase();
    }

    final Uri uri = Uri.parse('$_baseUrl/api/new-releases').replace(
      queryParameters: queryParams,
    );

    try {
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
        // DO NOT fall back to getTrending. If tracks are empty, return an honest empty result.
        // The backend may return empty 'tracks' but populated 'albums' — that is truthful.
        final List<Track> tracks = rawTracks.map((dynamic item) {
          return _mapTrack(item as Map<String, dynamic>);
        }).toList();
        // Respect backend has_more; total is the real count of song tracks on this page
        final bool hasMore = (body['has_more'] as bool?) ?? false;
        final int total = (body['total'] as num?)?.toInt() ??
            (hasMore ? (offset + tracks.length + 1) : (offset + tracks.length));
        final bool isStale = (body['stale'] as bool?) ?? false;
        if (isStale) {
          debugPrint('[CustomApiProvider] getNewReleases: backend returned stale data '
              '(updated_at=${body["updated_at"]})');
        }
        return PagedResult<Track>(items: tracks, total: total, hasMore: hasMore);
      } else {
        debugPrint('[CustomApiProvider] getNewReleases HTTP ${res.statusCode} for $uri');
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getNewReleases error: $e');
    }

    // Return honest empty — never alias to getTrending.
    return const PagedResult<Track>(items: <Track>[], total: 0);
  }

  /// Returns JioSaavn recommendations for a seed track.
  /// Uses the backend's /api/related endpoint which calls reco.getreco.
  /// Requires a seed track ID; without one, returns an honest empty list.
  /// This is NOT a trending alias — it is a real per-song recommendation call.
  @override
  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20, String? language}) async {
    // getRecommendations without a seed track ID cannot produce meaningful results.
    // Return empty — do not silently alias to generic trending.
    // Callers with a specific seed track should use getRadio(track) instead,
    // which calls /api/related with the track id, title and artist.
    debugPrint('[CustomApiProvider] getRecommendations called without seed — returning empty. '
        'Use getRadio(track) for per-song JioSaavn recommendations.');
    return const PagedResult<Track>(items: <Track>[], total: 0, hasMore: false);
  }

  Track _mapTrack(Map<String, dynamic> item) {
    final String trackId = item['id'] as String? ?? '';
    final String title = item['title'] as String? ?? 'Unknown Title';
    final String artistName = item['artist'] as String? ?? 'Unknown Artist';
    final int durationMs = (item['duration_ms'] as num?)?.toInt() ?? 0;
    final String? artworkUrl = item['artwork_url'] as String?;

    return Track(
      id: 'custom_api:track:$trackId',
      providerId: id,
      providerTrackId: trackId,
      title: title,
      artists: <Artist>[
        Artist(
          id: 'custom_api:artist:$artistName',
          providerId: id,
          providerArtistId: artistName,
          name: artistName,
        ),
      ],
      album: Album(
        id: 'custom_api:album:$trackId',
        providerId: id,
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
      qualityOptions: const <AudioQuality>[AudioQuality.high, AudioQuality.veryHigh],
      commercialUseAllowed: false,
      backgroundPlaybackAllowed: true,
      license: 'Cloud Gateway Stream',
      attributionRequired: false,
      extra: <String, dynamic>{
        'language': item['language'] ?? '',
        'year': item['year'] ?? '',
        'album': item['album'] ?? '',
        'play_count': item['play_count'] ?? 0,
      },
    );
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    final String cleanId = albumId.replaceFirst('custom_api:album:', '');
    if (_baseUrl.isEmpty) {
      throw ProviderException(id, message: 'Custom API base URL is not configured.');
    }
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/album/$cleanId');
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
        final List<Track> tracks = rawTracks
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> m) => _mapTrack(m))
            .toList();
        return Album(
          id: 'custom_api:album:$cleanId',
          providerId: id,
          providerAlbumId: cleanId,
          title: body['title'] as String? ?? 'Album',
          artists: <Artist>[
            Artist(
              id: 'custom_api:artist:${body['primary_artist'] ?? body['artist'] ?? ''}',
              providerId: id,
              providerArtistId: body['primary_artist'] as String? ?? '',
              name: body['primary_artist'] as String? ?? body['artist'] as String? ?? 'Various Artists',
            ),
          ],
          artworkUrl: body['artwork_url'] as String? ?? body['image'] as String?,
          year: int.tryParse('${body['year']}'),
          trackCount: tracks.length,
        );
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getAlbum error: $e');
    }
    throw ProviderException(id, message: 'Album not found or provider unavailable.');
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    final String cleanId = artistId.replaceFirst('custom_api:artist:', '');
    if (_baseUrl.isEmpty) {
      throw ProviderException(id, message: 'Custom API base URL is not configured.');
    }
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/artist/$cleanId');
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        return Artist(
          id: 'custom_api:artist:$cleanId',
          providerId: id,
          providerArtistId: cleanId,
          name: body['name'] as String? ?? cleanId,
          imageUrl: body['image'] as String? ?? body['artwork_url'] as String?,
        );
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getArtist error: $e');
    }
    throw ProviderException(id, message: 'Artist not found or provider unavailable.');
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    final String cleanId = playlistId.replaceFirst('custom_api:playlist:', '');
    if (_baseUrl.isEmpty) {
      throw ProviderException(id, message: 'Custom API base URL is not configured.');
    }
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/playlist/$cleanId');
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
        final List<Track> tracks = rawTracks
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> m) => _mapTrack(m))
            .toList();
        return Playlist(
          id: 'custom_api:playlist:$cleanId',
          title: body['title'] as String? ?? 'Playlist',
          description: body['subtitle'] as String? ?? body['description'] as String?,
          artworkUrl: body['artwork_url'] as String? ?? body['image'] as String?,
          source: PlaylistSource.provider,
          providerId: id,
          tracks: tracks,
          trackCount: tracks.length,
        );
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getPlaylist error: $e');
    }
    throw ProviderException(id, message: 'Playlist not found or provider unavailable.');
  }

  // ─── Catalogue Management API ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCatalogSections({
    bool includeDisabled = false,
    String? lang,
    String? group,
  }) async {
    if (_baseUrl.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Map<String, String> queryParams = <String, String>{};
      if (includeDisabled) queryParams['include_disabled'] = 'true';
      if (lang != null && lang.isNotEmpty && lang.toLowerCase() != 'all') {
        queryParams['lang'] = lang;
      }
      if (group != null && group.isNotEmpty) queryParams['group'] = group;

      final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final http.Response res = await http.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['sections'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['sections'] as List<dynamic>).whereType<Map<String, dynamic>>(),
          );
        }
      }
    } catch (e) {
      debugPrint('[CustomApiProvider] getCatalogSections error: $e');
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> previewCatalogUrl(String url) async {
    if (_baseUrl.isEmpty) return <String, dynamic>{'valid': false, 'error': 'Base URL not configured'};
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/catalog/preview');
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'url': url}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return <String, dynamic>{'valid': false, 'error': e.toString()};
    }
  }

  Map<String, String> _buildHeaders() {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };
    try {
      final String? token = SupabaseService().currentSession?.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<Map<String, dynamic>> createCatalogSection(Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to create section (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    throw const ProviderException('custom_api', message: 'Invalid response format from catalogue server');
  }

  Future<Map<String, dynamic>> updateCatalogSection(String key, Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections/$key');
    final http.Response res = await http.put(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to update section (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    throw const ProviderException('custom_api', message: 'Invalid response format from catalogue server');
  }

  Future<Map<String, dynamic>> resolveTrack(String urlOrId) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/resolve_track');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(<String, dynamic>{
        'url': urlOrId.startsWith('http') ? urlOrId : null,
        'song_id': !urlOrId.startsWith('http') ? urlOrId : null,
      }),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to resolve track (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    throw const ProviderException('custom_api', message: 'Invalid response format from resolve_track');
  }

  Future<bool> deleteCatalogSection(String key) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections/$key');
    final http.Response res = await http.delete(
      uri,
      headers: _buildHeaders(),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to delete section (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    return true;
  }

  Future<bool> reorderCatalogSections(List<String> keys) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections/reorder');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(<String, dynamic>{'order': keys}),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to reorder sections (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    return true;
  }

  Future<Map<String, dynamic>> toggleCatalogSection(String key) async {
    final Uri uri = Uri.parse('$_baseUrl/api/catalog/sections/$key/toggle');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Failed to toggle section (${res.statusCode})';
      try {
        final dynamic b = jsonDecode(res.body);
        if (b is Map && b['error'] != null) msg = b['error'].toString();
      } catch (_) {}
      throw ProviderException('custom_api', message: msg);
    }
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    throw const ProviderException('custom_api', message: 'Invalid response format from catalogue server');
  }

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  @override
  Future<PagedResult<Genre>> getGenres() async =>
      const PagedResult<Genre>(items: <Genre>[], total: 0);

  @override
  Future<PagedResult<Track>> getTracksByGenre(
    String genreId, {
    int offset = 0,
    int limit = 20,
  }) =>
      search(genreId, offset: offset, limit: limit).then(
        (SearchResult s) => PagedResult<Track>(items: s.tracks, total: s.tracks.length),
      );

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    final String cleanName = (artistId.contains(':') ? artistId.split(':').last : artistId).trim();
    if (_baseUrl.isNotEmpty) {
      try {
        final Uri uri = Uri.parse('$_baseUrl/api/artist/${Uri.encodeComponent(cleanName)}').replace(
          queryParameters: <String, String>{'albums': '20'},
        );
        final http.Response res = await http.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
          final List<dynamic> raw = (body['top_albums'] as List<dynamic>?) ?? <dynamic>[];
          if (raw.isNotEmpty) {
            return raw.map((dynamic item) {
              final Map<String, dynamic> m = item as Map<String, dynamic>;
              return Album(
                id: 'custom_api:album:${m['id'] ?? ''}',
                providerId: id,
                providerAlbumId: m['id']?.toString() ?? '',
                title: m['title']?.toString() ?? m['name']?.toString() ?? 'Album',
                artworkUrl: m['image']?.toString() ?? m['artwork_url']?.toString(),
              );
            }).toList();
          }
        }
      } catch (_) {}
    }
    return <Album>[];
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final String cleanName = (artistId.contains(':') ? artistId.split(':').last : artistId).trim();
    if (_baseUrl.isNotEmpty) {
      try {
        final Uri uri = Uri.parse('$_baseUrl/api/artist/${Uri.encodeComponent(cleanName)}').replace(
          queryParameters: <String, String>{'songs': '30'},
        );
        final http.Response res = await http.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
          final List<dynamic> raw = (body['top_songs'] as List<dynamic>?) ??
              (body['tracks'] as List<dynamic>?) ??
              <dynamic>[];
          if (raw.isNotEmpty) {
            final List<Track> tracks = raw.map((dynamic item) => _mapTrack(item as Map<String, dynamic>)).toList();
            if (tracks.isNotEmpty) return tracks;
          }
        }
      } catch (e) {
        debugPrint('[CustomApiProvider] getArtistTopTracks api error: $e');
      }
    }

    // High accuracy fallback: search and strictly filter to tracks by this artist
    final SearchResult s = await search(cleanName, limit: 40);
    final String lowerName = cleanName.toLowerCase();
    final List<Track> strict = s.tracks.where((Track t) {
      final String tArtists = t.artistNames.toLowerCase();
      if (tArtists.contains(lowerName)) return true;
      for (final Artist a in t.artists) {
        if (a.name.toLowerCase().contains(lowerName)) return true;
      }
      return false;
    }).toList();

    return strict.isNotEmpty ? strict : s.tracks;
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async {
    final String cleanId = track.providerTrackId.isNotEmpty
        ? track.providerTrackId
        : (track.id.contains(':') ? track.id.split(':').last : track.id);
    final String artistName = track.artists.isNotEmpty ? track.artists.first.name : '';

    if (_baseUrl.isNotEmpty) {
      try {
        final String trackLang = (track.extra['language'] as String?) ?? '';
        final Uri uri = Uri.parse('$_baseUrl/api/related').replace(
          queryParameters: <String, String>{
            if (cleanId.isNotEmpty) 'id': cleanId,
            if (track.title.isNotEmpty) 'title': track.title,
            if (artistName.isNotEmpty) 'artist': artistName,
            if (trackLang.isNotEmpty) 'lang': trackLang,
            'limit': limit.toString(),
          },
        );
        final http.Response res = await http.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
          final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
          final List<Track> tracks = rawTracks.map((dynamic item) {
            return _mapTrack(item as Map<String, dynamic>);
          }).toList();
          if (tracks.isNotEmpty) {
            return tracks.where((Track t) => t.id != track.id).toList();
          }
        }
      } catch (e) {
        debugPrint('[CustomApiProvider] getRadio error: $e');
      }
    }

    final String query = artistName.isNotEmpty ? artistName : track.title;
    final SearchResult s = await search(query, limit: limit);
    return s.tracks.where((Track t) => t.id != track.id).toList();
  }

  // ---------------------------------------------------------------------------
  // Radio Stations Admin Management
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchRadioStations() async {
    final Uri uri = Uri.parse('$_baseUrl/api/radio/stations');
    final http.Response res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> list = (body['stations'] as List<dynamic>?) ?? <dynamic>[];
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createRadioStation(Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/radio/stations');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ProviderException(id, message: 'Failed to create radio station (${res.statusCode})');
  }

  Future<Map<String, dynamic>> updateRadioStation(String stationId, Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/radio/stations/$stationId');
    final http.Response res = await http.put(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ProviderException(id, message: 'Failed to update radio station (${res.statusCode})');
  }

  Future<bool> deleteRadioStation(String stationId) async {
    final Uri uri = Uri.parse('$_baseUrl/api/radio/stations/$stationId');
    final http.Response res = await http.delete(
      uri,
      headers: _buildHeaders(),
    ).timeout(const Duration(seconds: 10));
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // ---------------------------------------------------------------------------
  // Library Discovery Categories Admin Management
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchLibraryCategories() async {
    final Uri uri = Uri.parse('$_baseUrl/api/library/categories');
    final http.Response res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> list = (body['categories'] as List<dynamic>?) ?? <dynamic>[];
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createLibraryCategory(Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/library/categories');
    final http.Response res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ProviderException(id, message: 'Failed to create library category (${res.statusCode})');
  }

  Future<Map<String, dynamic>> updateLibraryCategory(String catId, Map<String, dynamic> data) async {
    final Uri uri = Uri.parse('$_baseUrl/api/library/categories/$catId');
    final http.Response res = await http.put(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ProviderException(id, message: 'Failed to update library category (${res.statusCode})');
  }

  Future<bool> deleteLibraryCategory(String catId) async {
    final Uri uri = Uri.parse('$_baseUrl/api/library/categories/$catId');
    final http.Response res = await http.delete(
      uri,
      headers: _buildHeaders(),
    ).timeout(const Duration(seconds: 10));
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
