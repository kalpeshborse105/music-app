import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
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
        final int total = (body['total'] as num?)?.toInt() ?? (body['pool_size'] as num?)?.toInt() ?? 1000;
        return PagedResult<Track>(items: tracks, total: total);
      }
    } catch (_) {}

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
      final http.Response res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rawTracks = (body['tracks'] as List<dynamic>?) ?? <dynamic>[];
        if (rawTracks.isNotEmpty) {
          final List<Track> tracks = rawTracks.map((dynamic item) {
            return _mapTrack(item as Map<String, dynamic>);
          }).toList();
          final int total = (body['total'] as num?)?.toInt() ?? 1000;
          return PagedResult<Track>(items: tracks, total: total);
        }
      }
    } catch (_) {}

    return getTrending(offset: offset, limit: limit, language: language);
  }

  @override
  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20, String? language}) =>
      getTrending(offset: offset, limit: limit, language: language);

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
    throw ProviderException(id, message: 'Albums handled at track level.');
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    throw ProviderException(id, message: 'Artists handled at track level.');
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    throw ProviderException(id, message: 'Playlists handled at client level.');
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
  Future<List<Album>> getArtistAlbums(String artistId) async => <Album>[];

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final SearchResult s = await search(artistId, limit: 10);
    return s.tracks;
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
}
