import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// The user's own audio files, read from the device (Android MediaStore).
///
/// Files never leave the device — no uploads, no server (spec §13/§32). On web
/// the platform channel is unavailable, so the provider simply reports itself
/// as unavailable and returns empty results.
class LocalMusicProvider extends BaseMusicProvider {
  LocalMusicProvider({required super.api, required super.cache});

  static const MethodChannel _channel = MethodChannel('com.kalpkrut.beats/media');

  List<Track> _tracks = <Track>[];
  bool _scanned = false;
  bool _permissionDenied = false;

  @override
  String get id => 'local';

  @override
  String get displayName => 'On this device';

  @override
  ProviderStatus get status => ProviderStatus.active;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: true, // already local
        backgroundPlayback: true,
        lyrics: false,
        playlists: true,
        favorites: true,
        radio: true,
        search: true,
        browse: true,
        recommendations: false,
        localOnly: true,
        qualityTiers: <String>[],
      );

  bool get permissionDenied => _permissionDenied;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<void> dispose() async {}

  /// Requests permission (if needed) and reads the device music library.
  Future<List<Track>> scan({bool force = false}) async {
    if (kIsWeb) return <Track>[];
    if (_scanned && !force) return _tracks;

    final bool granted = await _ensurePermission();
    if (!granted) {
      _permissionDenied = true;
      _tracks = <Track>[];
      _scanned = true;
      return _tracks;
    }
    _permissionDenied = false;

    try {
      final List<dynamic>? rows =
          await _channel.invokeMethod<List<dynamic>>('queryAudio');
      _tracks = (rows ?? <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => _toTrack(e.cast<String, dynamic>()))
          .where((Track t) => t.isStreamable)
          .toList();
      _scanned = true;
      Logger.info('Local scan found ${_tracks.length} tracks');
      return _tracks;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION') {
        _permissionDenied = true;
        return <Track>[];
      }
      throw const StorageException(message: 'Could not read local music.');
    } on MissingPluginException {
      // Non-Android platforms without the channel.
      return <Track>[];
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      final Permission audio = Permission.audio;
      final Permission storage = Permission.storage;
      final Map<Permission, PermissionStatus> statuses =
          await <Permission>[audio, storage].request();
      final bool anyGranted =
          statuses.values.any((PermissionStatus s) => s.isGranted || s.isLimited);
      return anyGranted;
    } catch (_) {
      return false;
    }
  }

  Track _toTrack(Map<String, dynamic> m) {
    final String uri = m['uri']?.toString() ?? '';
    final String title = m['title']?.toString() ?? 'Unknown';
    final String artistName = m['artist']?.toString() ?? 'Unknown artist';
    final String albumName = m['album']?.toString() ?? 'Unknown album';
    final int durationMs = (m['duration'] as num?)?.toInt() ?? 0;
    final String? artUri = m['albumArtUri']?.toString();

    return Track(
      id: 'local:track:${m['id']}',
      providerId: id,
      providerTrackId: uri,
      title: title,
      artists: <Artist>[Artist.local(artistName)],
      album: Album(
        id: 'local:album:${m['albumId']}',
        providerId: id,
        providerAlbumId: m['albumId']?.toString() ?? '',
        title: albumName,
        artists: <Artist>[Artist.local(artistName)],
      ),
      duration: Duration(milliseconds: durationMs),
      artworkUrl: artUri,
      isStreamable: uri.isNotEmpty,
      isDownloadable: true,
      hasLyrics: false,
      qualityOptions: const <AudioQuality>[AudioQuality.normal, AudioQuality.high],
      extra: <String, dynamic>{
        'uri': uri,
        'path': m['path']?.toString(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Retrieval
  // ---------------------------------------------------------------------------
  @override
  Future<Track> getTrack(String trackId) async {
    await scan();
    final int idx = _tracks.indexWhere((Track t) => t.id == trackId);
    if (idx < 0) throw const NotFoundException();
    return _tracks[idx];
  }

  @override
  Future<StreamSource> getStream(Track track,
      {AudioQuality quality = AudioQuality.auto}) async {
    final String uri = track.extra['uri']?.toString() ?? track.providerTrackId;
    if (uri.isEmpty) throw const TrackUnavailableException();
    // just_audio / ExoPlayer resolves content:// URIs on Android.
    return StreamSource(url: uri, codec: 'local', qualityTier: 'Local file');
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    await scan();
    final List<Track> items =
        _tracks.where((Track t) => t.album?.id == albumId).toList();
    if (items.isEmpty) throw const NotFoundException();
    return items.first.album!;
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    await scan();
    final int idx = _tracks.indexWhere((Track t) => t.artists.first.id == artistId);
    if (idx < 0) throw const NotFoundException();
    return _tracks[idx].artists.first;
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    await scan();
    return Playlist(
      id: playlistId,
      title: 'On this device',
      source: PlaylistSource.provider,
      providerId: id,
      tracks: _tracks,
      trackCount: _tracks.length,
    );
  }

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  // ---------------------------------------------------------------------------
  // Discovery (all derived from the local scan)
  // ---------------------------------------------------------------------------
  @override
  Future<SearchResult> search(String query,
      {int offset = 0, int limit = 20, String? cursor}) async {
    await scan();
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return SearchResult.empty;
    final List<Track> matches = _tracks
        .where((Track t) =>
            t.title.toLowerCase().contains(q) ||
            t.artistNames.toLowerCase().contains(q) ||
            (t.album?.title.toLowerCase().contains(q) ?? false))
        .toList();
    return SearchResult(
      query: query,
      tracks: _paginate(matches, offset, limit),
      albums: _albumMap(matches).values.toList(),
      artists: _artistMap(matches).values.toList(),
    );
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async {
    final List<Track> all = await scan();
    return PagedResult<Track>(
      items: _paginate(all, offset, limit),
      total: all.length,
      hasMore: offset + limit < all.length,
      nextOffset: offset + limit,
    );
  }

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async {
    final List<Track> all = await scan();
    final List<Track> sorted = <Track>[...all]..sort((Track a, Track b) => b.id.compareTo(a.id));
    return PagedResult<Track>(
      items: _paginate(sorted, offset, limit),
      total: sorted.length,
      hasMore: offset + limit < sorted.length,
    );
  }

  @override
  Future<PagedResult<Genre>> getGenres() async => const PagedResult<Genre>.empty();

  @override
  Future<PagedResult<Track>> getTracksByGenre(String genreId,
      {int offset = 0, int limit = 20}) async {
    return const PagedResult<Track>.empty();
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    await scan();
    return _albumMap(_tracks).values.toList();
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    await scan();
    final String slug = artistId.replaceAll('local:artist:', '');
    return _tracks.where((Track t) => t.artistNames == slug).toList();
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations(
      {int offset = 0, int limit = 20}) async {
    return getTrending(offset: offset, limit: limit);
  }

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async {
    final List<Track> all = await scan();
    return all.where((Track t) => t.id != track.id).take(limit).toList();
  }

  List<T> _paginate<T>(List<T> all, int offset, int limit) {
    if (offset >= all.length) return <T>[];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  Map<String, Album> _albumMap(List<Track> tracks) => <String, Album>{
        for (final Track t in tracks)
          if (t.album != null) t.album!.id: t.album!,
      };

  Map<String, Artist> _artistMap(List<Track> tracks) => <String, Artist>{
        for (final Track t in tracks) t.artists.first.id: t.artists.first,
      };
}
