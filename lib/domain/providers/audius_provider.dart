import 'dart:async';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/audio_quality.dart';
import '../models/genre.dart';
import '../models/lyrics.dart';
import '../models/paged_result.dart';
import '../models/playlist.dart';
import '../models/provider_capabilities.dart';
import '../models/provider_status.dart';
import '../models/search_result.dart';
import '../models/stream_source.dart';
import '../models/track.dart';
import 'base_provider.dart';

/// Audius — Official Decentralized Music Protocol Provider.
///
/// Implements the official documented Audius API (https://api.audius.co/)
/// with built-in rate-limiting compliance, request deduplication, response caching,
/// health tracking, and circuit-breaker safeguards.
class AudiusProvider extends BaseMusicProvider {
  AudiusProvider({
    required super.api,
    required super.cache,
    String? appName,
    String? apiKey,
  })  : _appName = (appName != null && appName.isNotEmpty)
            ? appName
            : AppConfig.audiusAppName,
        _apiKey = (apiKey != null && apiKey.isNotEmpty)
            ? apiKey
            : AppConfig.audiusApiKey;

  final String _appName;
  final String _apiKey;

  // Provider health & circuit breaker state
  bool _isHealthy = true;
  DateTime? _lastFailureTime;
  int _consecutiveFailures = 0;
  static const int _maxFailuresBeforeCooloff = 3;
  static const Duration _cooloffDuration = Duration(seconds: 30);

  @override
  String get id => 'audius';

  @override
  String get displayName => 'Audius (Decentralized Stream)';

  @override
  ProviderStatus get status => ProviderStatus.active;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: false,
        backgroundPlayback: true,
        lyrics: false,
        playlists: true,
        favorites: true,
        radio: false,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: false,
        requiresApiKey: false,
        qualityTiers: <String>['320 kbps MP3'],
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async {
    _checkHealthReset();
    if (!_isHealthy) return false;

    try {
      final Uri uri = _buildUri('/v1/tracks/trending', <String, String>{'limit': '1'});
      final Map<String, dynamic> json = await api.getJson(uri, retry: false);
      final dynamic data = json['data'];
      final bool ok = data is List && data.isNotEmpty;
      if (ok) _recordSuccess();
      return ok;
    } catch (_) {
      _recordFailure();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Scaffolding & Compliance
  // ---------------------------------------------------------------------------

  Uri _buildUri(String path, [Map<String, String>? params]) {
    final Map<String, String> query = <String, String>{
      'app_name': _appName,
      if (_apiKey.isNotEmpty) 'api_key': _apiKey,
      if (params != null) ...params,
    };

    return Uri.parse('${AppConfig.audiusBaseUrl}$path').replace(
      queryParameters: query,
    );
  }

  void _checkHealthReset() {
    if (!_isHealthy && _lastFailureTime != null) {
      if (DateTime.now().difference(_lastFailureTime!) > _cooloffDuration) {
        _isHealthy = true;
        _consecutiveFailures = 0;
      }
    }
  }

  void _recordSuccess() {
    _isHealthy = true;
    _consecutiveFailures = 0;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    if (_consecutiveFailures >= _maxFailuresBeforeCooloff) {
      _isHealthy = false;
      Logger.warn(
        '[AudiusProvider] Circuit breaker tripped. Cooling off for ${_cooloffDuration.inSeconds}s.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getResults(
    String path,
    Map<String, String> params, {
    Duration ttl = AppConstants.discoveryCacheTtl,
  }) async {
    _checkHealthReset();
    final Uri uri = _buildUri(path, params);
    final String cacheKey = uri.toString();

    return coalesce<List<Map<String, dynamic>>>(cacheKey, () async {
      final Map<String, dynamic>? cached = cache.getJson(cacheKey);
      if (cached != null && cached['data'] is List) {
        return (cached['data'] as List).cast<Map<String, dynamic>>();
      }

      try {
        final Map<String, dynamic> resp = await api.getJson(uri);
        _recordSuccess();
        final dynamic data = resp['data'];
        if (data is List) {
          final List<Map<String, dynamic>> list =
              data.whereType<Map<String, dynamic>>().toList();
          await cache.set(cacheKey, <String, dynamic>{'data': list}, ttl);
          return list;
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        _recordFailure();
        Logger.warn('[AudiusProvider] Request failed on $path', error: e);
        return <Map<String, dynamic>>[];
      }
    });
  }

  Track _toTrack(Map<String, dynamic> json) {
    final String trackId = json['id']?.toString() ?? json['track_id']?.toString() ?? '';
    final dynamic userObj = json['user'];
    final Map<String, dynamic> user =
        (userObj is Map<String, dynamic>) ? userObj : <String, dynamic>{};

    final String artistId = user['id']?.toString() ?? 'creator';
    final String artistName = user['name']?.toString() ?? 'Audius Artist';

    // Extract artwork
    String? artwork;
    final dynamic artworkObj = json['artwork'];
    if (artworkObj is Map) {
      artwork = artworkObj['480x480']?.toString() ??
          artworkObj['1000x1000']?.toString() ??
          artworkObj['150x150']?.toString();
    }

    // Extract artist image
    String? artistImage;
    final dynamic profilePic = user['profile_picture'];
    if (profilePic is Map) {
      artistImage = profilePic['480x480']?.toString() ??
          profilePic['150x150']?.toString() ??
          profilePic['1000x1000']?.toString();
    }

    final Artist artist = Artist(
      id: 'audius:artist:$artistId',
      providerId: id,
      providerArtistId: artistId,
      name: artistName,
      imageUrl: artistImage,
    );

    // Stream URL resolution
    String? directStreamUrl;
    final dynamic streamObj = json['stream'];
    if (streamObj is Map && streamObj['url'] != null) {
      directStreamUrl = streamObj['url']?.toString();
    }

    final int durationSec = (json['duration'] as num?)?.toInt() ?? 0;

    return Track(
      id: 'audius:track:$trackId',
      providerId: id,
      providerTrackId: trackId,
      title: json['title']?.toString() ?? 'Untitled Audius Track',
      artists: <Artist>[artist],
      duration: Duration(seconds: durationSec),
      artworkUrl: artwork,
      genre: json['genre']?.toString(),
      isStreamable: json['is_streamable'] as bool? ?? true,
      isDownloadable: (json['is_downloadable'] as bool?) ?? (json['is_streamable'] as bool? ?? true),
      hasLyrics: false,
      commercialUseAllowed: false,
      backgroundPlaybackAllowed: true,
      license: json['license']?.toString() ?? 'Audius Protocol Streaming',
      licenseUrl: 'https://audius.co',
      attributionRequired: true,
      qualityOptions: const <AudioQuality>[AudioQuality.veryHigh],
      extra: <String, dynamic>{
        'streamUrl': directStreamUrl,
        'mood': json['mood']?.toString(),
        'play_count': json['play_count'],
        'permalink': json['permalink']?.toString(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Core Retrieval
  // ---------------------------------------------------------------------------

  @override
  Future<Track> getTrack(String trackId) async {
    final String cleanId = trackId.replaceAll('audius:track:', '');
    final Uri uri = _buildUri('/v1/tracks/$cleanId');
    try {
      final Map<String, dynamic> resp = await api.getJson(uri);
      final dynamic data = resp['data'];
      if (data is Map<String, dynamic>) {
        return _toTrack(data);
      }
      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        return _toTrack(data.first as Map<String, dynamic>);
      }
      throw const NotFoundException(message: 'Audius track not found.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NotFoundException(message: 'Audius track lookup error: $e');
    }
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    throw const NotFoundException(message: 'Audius albums not configured.');
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    final String cleanId = artistId.replaceAll('audius:artist:', '');
    final Uri uri = _buildUri('/v1/users/$cleanId');
    try {
      final Map<String, dynamic> resp = await api.getJson(uri);
      final dynamic data = resp['data'];
      if (data is Map<String, dynamic>) {
        String? img;
        final dynamic pic = data['profile_picture'];
        if (pic is Map) {
          img = pic['480x480']?.toString() ?? pic['150x150']?.toString();
        }
        return Artist(
          id: artistId,
          providerId: id,
          providerArtistId: cleanId,
          name: data['name']?.toString() ?? 'Audius Artist',
          imageUrl: img,
        );
      }
      return Artist(
        id: artistId,
        providerId: id,
        providerArtistId: cleanId,
        name: 'Audius Artist',
      );
    } catch (_) {
      return Artist(
        id: artistId,
        providerId: id,
        providerArtistId: cleanId,
        name: 'Audius Artist',
      );
    }
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    final String cleanId = playlistId.replaceAll('audius:playlist:', '');
    final List<Map<String, dynamic>> rows = await _getResults(
      '/v1/playlists/$cleanId/tracks',
      <String, String>{'limit': '30'},
      ttl: AppConstants.entityCacheTtl,
    );

    return Playlist(
      id: playlistId,
      title: 'Audius Playlist',
      source: PlaylistSource.provider,
      providerId: id,
      tracks: rows.map(_toTrack).toList(),
      trackCount: rows.length,
    );
  }

  @override
  Future<StreamSource> getStream(
    Track track, {
    AudioQuality quality = AudioQuality.auto,
  }) async {
    final String? direct = track.extra['streamUrl'] as String?;
    if (direct != null && direct.isNotEmpty) {
      return StreamSource(
        url: direct,
        bitrateKbps: 320,
        codec: 'mp3',
        qualityTier: '320 kbps MP3',
      );
    }

    final String streamUrl =
        '${AppConfig.audiusBaseUrl}/v1/tracks/${track.providerTrackId}/stream?app_name=$_appName';

    return StreamSource(
      url: streamUrl,
      bitrateKbps: 320,
      codec: 'mp3',
      qualityTier: '320 kbps MP3',
    );
  }

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  // ---------------------------------------------------------------------------
  // Discovery & Search
  // ---------------------------------------------------------------------------

  @override
  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = 20,
    String? cursor,
  }) async {
    final String q = query.trim();
    if (q.isEmpty) return SearchResult.empty;

    // Rate-limiting safeguard: clamp limit to avoid requesting hundreds of tracks
    final int safeLimit = limit.clamp(1, 20);

    final List<Map<String, dynamic>> trackRows = await _getResults(
      '/v1/tracks/search',
      <String, String>{
        'query': q,
        'limit': '$safeLimit',
        'offset': '$offset',
      },
      ttl: AppConstants.searchCacheTtl,
    );

    final List<Track> tracks = trackRows.map(_toTrack).toList();

    // Query artists concurrently
    final List<Map<String, dynamic>> userRows = await _getResults(
      '/v1/users/search',
      <String, String>{
        'query': q,
        'limit': '5',
      },
      ttl: AppConstants.searchCacheTtl,
    );

    final List<Artist> artists = userRows.map((Map<String, dynamic> u) {
      final String uId = u['id']?.toString() ?? '';
      String? img;
      final dynamic pic = u['profile_picture'];
      if (pic is Map) {
        img = pic['480x480']?.toString() ?? pic['150x150']?.toString();
      }
      return Artist(
        id: 'audius:artist:$uId',
        providerId: id,
        providerArtistId: uId,
        name: u['name']?.toString() ?? 'Audius Artist',
        imageUrl: img,
      );
    }).toList();

    return SearchResult(
      query: query,
      tracks: tracks,
      artists: artists,
      albums: const <Album>[],
      playlists: const <Playlist>[],
    );
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async {
    final int safeLimit = limit.clamp(1, 20);
    final List<Map<String, dynamic>> rows = await _getResults(
      '/v1/tracks/trending',
      <String, String>{'limit': '$safeLimit', 'offset': '$offset'},
      ttl: AppConstants.discoveryCacheTtl,
    );

    return PagedResult<Track>(
      items: rows.map(_toTrack).toList(),
      total: offset + rows.length,
      hasMore: rows.length >= safeLimit,
      nextOffset: offset + rows.length,
    );
  }

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async {
    return getTrending(offset: offset, limit: limit);
  }

  @override
  Future<PagedResult<Genre>> getGenres() async {
    const List<String> popularAudiusGenres = <String>[
      'Electronic',
      'Hip-Hop/Rap',
      'Lo-Fi',
      'Pop',
      'R&B/Soul',
      'Rock',
      'Ambient',
      'House',
      'Techno',
      'Trap',
    ];

    return PagedResult<Genre>(
      items: popularAudiusGenres
          .map((String g) => Genre(id: g.toLowerCase(), name: g))
          .toList(),
      total: popularAudiusGenres.length,
    );
  }

  @override
  Future<PagedResult<Track>> getTracksByGenre(
    String genreId, {
    int offset = 0,
    int limit = 20,
  }) async {
    final int safeLimit = limit.clamp(1, 20);
    final List<Map<String, dynamic>> rows = await _getResults(
      '/v1/tracks/trending',
      <String, String>{
        'genre': genreId,
        'limit': '$safeLimit',
        'offset': '$offset',
      },
      ttl: AppConstants.discoveryCacheTtl,
    );

    return PagedResult<Track>(
      items: rows.map(_toTrack).toList(),
      total: offset + rows.length,
      hasMore: rows.length >= safeLimit,
      nextOffset: offset + rows.length,
    );
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => <Album>[];

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final String cleanId = artistId.replaceAll('audius:artist:', '');
    final List<Map<String, dynamic>> rows = await _getResults(
      '/v1/users/$cleanId/tracks',
      <String, String>{'limit': '15'},
      ttl: AppConstants.entityCacheTtl,
    );
    return rows.map(_toTrack).toList();
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20}) async {
    return getTrending(offset: offset, limit: limit);
  }

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async => <Track>[];
}
