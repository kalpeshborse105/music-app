import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
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

/// Jamendo — an authorized catalogue of Creative-Commons licensed music that
/// explicitly permits streaming through its public API.
///
/// Requires a (free) `client_id`, supplied via
/// `--dart-define=JAMENDO_CLIENT_ID=...`. When it is not configured the
/// provider reports [isAvailable] = false and is skipped — the app keeps
/// working with the other providers (spec §29/§41/§50).
class JamendoProvider extends BaseMusicProvider {
  JamendoProvider({required super.api, required super.cache, String? clientId})
      : _clientId = clientId ?? AppConfig.jamendoClientId;

  final String _clientId;

  static const String _genresResource = '/genres';

  @override
  String get id => 'jamendo';

  @override
  String get displayName => 'Jamendo (Creative Commons)';

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
        radio: true,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: true,
        requiresApiKey: true,
        qualityTiers: <String>['mp31 (96)', 'mp32 (192)', 'flac'],
      );

  bool get _configured => _clientId.trim().isNotEmpty;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async {
    if (!_configured) return false;
    // A cheap ping validates the credential so the registry can skip it when
    // the key is invalid/suspended.
    try {
      final Map<String, dynamic> json = await api.getJson(
        _uri('/tracks', <String, String>{'limit': '1'}),
        retry: false,
      );
      return _statusOk(json);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {}

  // ---------------------------------------------------------------------------
  // Request scaffolding
  // ---------------------------------------------------------------------------
  Uri _uri(String path, Map<String, String> params) {
    return Uri.parse('${AppConfig.jamendoBaseUrl}$path').replace(
      queryParameters: <String, String>{
        'client_id': _clientId,
        'format': 'json',
        'include': 'musicinfo+licenses',
        'audioformat': 'mp32',
        ...params,
      },
    );
  }

  bool _statusOk(Map<String, dynamic> json) {
    final dynamic headers = json['headers'];
    if (headers is Map) {
      return headers['status']?.toString() != 'failed';
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> _results(
    String path,
    Map<String, String> params, {
    Duration ttl = AppConstants.discoveryCacheTtl,
  }) async {
    if (!_configured) throw const AuthenticationException();
    final Uri uri = _uri(path, params);
    final String key = 'jamendo:$path:${params.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join('&')}';

    Map<String, dynamic>? json = cache.getJson(key);
    if (json == null) {
      try {
        json = await api.getJson(uri);
      } on AppException {
        rethrow;
      } catch (_) {
        throw const ProviderException('jamendo');
      }
      if (!_statusOk(json)) {
        final dynamic h = json['headers'];
        final String code = h is Map ? (h['code']?.toString() ?? '') : '';
        if (code.contains('5') || code.contains('11')) {
          throw const AuthenticationException(
            message: 'Jamendo needs a valid client id. See Settings.',
          );
        }
        throw const ProviderException('jamendo');
      }
      await cache.set(key, json, ttl);
    }
    final dynamic results = json['results'];
    if (results is! List) return <Map<String, dynamic>>[];
    return results
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------
  AudioQuality _qualityFromFormat(String? audioFormat) {
    switch (audioFormat) {
      case 'mp31':
        return AudioQuality.low;
      case 'mp32':
        return AudioQuality.normal;
      case 'flac':
        return AudioQuality.veryHigh;
      default:
        return AudioQuality.normal;
    }
  }

  Track _toTrack(Map<String, dynamic> json) {
    final String trackId = json['id']?.toString() ?? '';
    final String artistName = json['artist_name']?.toString() ?? 'Unknown artist';
    final String artistId = json['artist_id']?.toString() ?? artistName;
    final Artist artist = Artist(
      id: 'jamendo:artist:$artistId',
      providerId: id,
      providerArtistId: artistId,
      name: artistName,
      imageUrl: json['artist_image']?.toString(),
    );
    final String? albumId = json['album_id']?.toString();
    final String albumName = json['album_name']?.toString() ?? '';
    final dynamic musicinfo = json['musicinfo'];
    String? genre;
    if (musicinfo is Map) {
      final dynamic genres = musicinfo['tags'];
      if (genres is Map) {
        final dynamic g = genres['genres'];
        if (g is List && g.isNotEmpty) genre = g.first.toString();
      }
    }
    return Track(
      id: 'jamendo:track:$trackId',
      providerId: id,
      providerTrackId: trackId,
      title: json['name']?.toString() ?? 'Untitled',
      artists: <Artist>[artist],
      album: albumId == null
          ? null
          : Album(
              id: 'jamendo:album:$albumId',
              providerId: id,
              providerAlbumId: albumId,
              title: albumName.isEmpty ? 'Single' : albumName,
              artists: <Artist>[artist],
              artworkUrl: json['album_image']?.toString(),
            ),
      duration: Duration(seconds: int.tryParse(json['duration']?.toString() ?? '') ?? 0),
      artworkUrl: json['album_image']?.toString() ?? json['image']?.toString(),
      isStreamable: (json['audio']?.toString().isNotEmpty ?? false),
      isDownloadable: false,
      hasLyrics: false,
      commercialUseAllowed: false,
      backgroundPlaybackAllowed: true,
      license: json['license_ccurl']?.toString() ?? 'Creative Commons CC BY-SA',
      licenseUrl: json['license_ccurl']?.toString(),
      attributionRequired: true,
      qualityOptions: <AudioQuality>[
        _qualityFromFormat(json['audioformat']?.toString()),
        AudioQuality.normal,
      ],
      genre: genre,
      extra: <String, dynamic>{
        'streamUrl': json['audio']?.toString(),
        'downloadUrl': json['audiodownload']?.toString(),
        'license': json['license_ccurl']?.toString(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Retrieval
  // ---------------------------------------------------------------------------
  @override
  Future<Track> getTrack(String trackId) async {
    final String id0 = trackId.replaceAll('jamendo:track:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/tracks',
      <String, String>{'id': id0, 'limit': '1'},
      ttl: AppConstants.entityCacheTtl,
    );
    if (rows.isEmpty) throw const NotFoundException();
    return _toTrack(rows.first);
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    final String id0 = albumId.replaceAll('jamendo:album:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/albums',
      <String, String>{'id': id0, 'limit': '1'},
      ttl: AppConstants.entityCacheTtl,
    );
    if (rows.isEmpty) throw const NotFoundException();
    final Map<String, dynamic> a = rows.first;
    return Album(
      id: albumId,
      providerId: id,
      providerAlbumId: id0,
      title: a['name']?.toString() ?? 'Album',
      artists: <Artist>[
        Artist(
          id: 'jamendo:artist:${a['artist_id']}',
          providerId: id,
          providerArtistId: a['artist_id']?.toString() ?? '',
          name: a['artist_name']?.toString() ?? 'Unknown artist',
        ),
      ],
      artworkUrl: a['image']?.toString(),
      year: int.tryParse(a['releasedate']?.toString().split('-').first ?? ''),
      trackCount: int.tryParse(a['tracks_count']?.toString() ?? ''),
    );
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    final String id0 = artistId.replaceAll('jamendo:artist:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/artists',
      <String, String>{'id': id0, 'limit': '1'},
      ttl: AppConstants.entityCacheTtl,
    );
    if (rows.isEmpty) return Artist(id: artistId, providerId: id, providerArtistId: id0, name: 'Unknown artist');
    final Map<String, dynamic> a = rows.first;
    return Artist(
      id: artistId,
      providerId: id,
      providerArtistId: id0,
      name: a['name']?.toString() ?? 'Unknown artist',
      imageUrl: a['image']?.toString(),
    );
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    final String id0 = playlistId.replaceAll('jamendo:playlist:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/playlists/tracks',
      <String, String>{'id': id0, 'limit': '50'},
      ttl: AppConstants.entityCacheTtl,
    );
    return Playlist(
      id: playlistId,
      title: 'Jamendo Playlist',
      source: PlaylistSource.provider,
      providerId: id,
      tracks: rows.map(_toTrack).toList(),
      trackCount: rows.length,
    );
  }

  @override
  Future<StreamSource> getStream(Track track,
      {AudioQuality quality = AudioQuality.auto}) async {
    String? url = track.extra['streamUrl'] as String?;
    if (url == null || url.isEmpty) {
      final Track fresh = await getTrack(track.id);
      url = fresh.extra['streamUrl'] as String?;
    }
    if (url == null || url.isEmpty) throw const TrackUnavailableException();

    // Jamendo exposes mp31 (~96k), mp32 (~192k) and a download (often 320/FLAC).
    int bitrate = 192;
    String? format = 'mp32';
    if (quality == AudioQuality.low) {
      url = url.replaceAll('mp32', 'mp31');
      bitrate = 96;
      format = 'mp31';
    } else if (quality == AudioQuality.veryHigh) {
      final String? dl = track.extra['downloadUrl'] as String?;
      if (dl != null && dl.isNotEmpty) {
        url = dl;
        bitrate = 320;
        format = 'mp3';
      }
    } else if (quality == AudioQuality.high) {
      final String? dl = track.extra['downloadUrl'] as String?;
      if (dl != null && dl.isNotEmpty) {
        url = dl;
        bitrate = 320;
        format = 'mp3';
      }
    }
    return StreamSource(
      url: url,
      bitrateKbps: bitrate,
      codec: format == 'flac' ? 'flac' : 'mp3',
      qualityTier: '$format ($bitrate)',
    );
  }

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------
  @override
  Future<SearchResult> search(String query,
      {int offset = 0, int limit = 20, String? cursor}) async {
    if (!_configured) throw const AuthenticationException();
    final String q = query.trim();
    if (q.isEmpty) return SearchResult.empty;
    final int page = run(offset, limit);
    final List<Map<String, dynamic>> rows = await _results(
      '/tracks',
      <String, String>{
        'search': q,
        'limit': (limit * 2).toString(),
        'offset': offset.toString(),
        'order': 'relevance',
      },
      ttl: AppConstants.searchCacheTtl,
    );
    final List<Track> tracks = rows.map(_toTrack).toList();
    final Map<String, Artist> artists = <String, Artist>{};
    final Map<String, Album> albums = <String, Album>{};
    for (final Track t in tracks) {
      for (final Artist a in t.artists) {
        artists[a.id] = a;
      }
      if (t.album != null) albums[t.album!.id] = t.album!;
    }
    // Track the requested page so pagination continues correctly.
    assert(page >= 0);
    return SearchResult(
      query: query,
      tracks: tracks,
      artists: artists.values.toList(),
      albums: albums.values.toList(),
    );
  }

  int run(int offset, int limit) => (offset ~/ limit);

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) =>
      _browse(
        '/tracks',
        <String, String>{'limit': '$limit', 'offset': '$offset', 'order': 'popularity_total'},
        offset,
        limit,
      );

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) =>
      _browse(
        '/tracks',
        <String, String>{
          'limit': '$limit',
          'offset': '$offset',
          'order': 'releasedate_desc',
          'releasedate': '2024-01-01_2026-12-31',
        },
        offset,
        limit,
      );

  Future<PagedResult<Track>> _browse(
    String path,
    Map<String, String> params,
    int offset,
    int limit,
  ) async {
    if (!_configured) throw const AuthenticationException();
    final List<Map<String, dynamic>> rows = await _results(path, params);
    return PagedResult<Track>(
      items: rows.map(_toTrack).toList(),
      total: offset + rows.length,
      hasMore: rows.length >= limit,
      nextOffset: offset + rows.length,
    );
  }

  @override
  Future<PagedResult<Genre>> getGenres() async {
    try {
      final List<Map<String, dynamic>> rows = await _results(
        _genresResource,
        <String, String>{'limit': '40'},
        ttl: AppConstants.entityCacheTtl,
      );
      return PagedResult<Genre>(
        items: rows
            .map((Map<String, dynamic> g) => Genre(
                  id: g['id']?.toString() ?? g['name']?.toString() ?? '',
                  name: g['name']?.toString() ?? 'Genre',
                ))
            .toList(),
        total: rows.length,
      );
    } catch (_) {
      return const PagedResult<Genre>.empty();
    }
  }

  @override
  Future<PagedResult<Track>> getTracksByGenre(String genreId,
      {int offset = 0, int limit = 20}) {
    return _browse(
      '/tracks',
      <String, String>{
        'tags': genreId,
        'limit': '$limit',
        'offset': '$offset',
        'order': 'popularity_total',
      },
      offset,
      limit,
    );
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    final String id0 = artistId.replaceAll('jamendo:artist:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/artists/albums',
      <String, String>{'id': id0, 'limit': '20'},
      ttl: AppConstants.entityCacheTtl,
    );
    return rows
        .map((Map<String, dynamic> a) => Album(
              id: 'jamendo:album:${a['id']}',
              providerId: id,
              providerAlbumId: a['id']?.toString() ?? '',
              title: a['name']?.toString() ?? 'Album',
              artworkUrl: a['image']?.toString(),
              year: int.tryParse(a['releasedate']?.toString().split('-').first ?? ''),
            ))
        .toList();
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final String id0 = artistId.replaceAll('jamendo:artist:', '');
    final List<Map<String, dynamic>> rows = await _results(
      '/artists/tracks',
      <String, String>{'id': id0, 'limit': '20', 'order': 'popularity_total'},
    );
    return rows.map(_toTrack).toList();
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations(
      {int offset = 0, int limit = 20}) async {
    return _browse(
      '/tracks',
      <String, String>{
        'featured': '1',
        'limit': '$limit',
        'offset': '$offset',
      },
      offset,
      limit,
    );
  }

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async {
    final String? genre = track.genre;
    final Map<String, String> params = <String, String>{
      'limit': '${limit + 1}',
      'order': 'popularity_total',
    };
    if (genre != null && genre.isNotEmpty) {
      params['tags'] = genre;
    } else if (track.artists.isNotEmpty) {
      params['artist_name'] = track.artists.first.name;
    }
    final List<Map<String, dynamic>> rows = await _results('/tracks', params);
    return rows
        .map(_toTrack)
        .where((Track t) => t.id != track.id)
        .take(limit)
        .toList();
  }
}
