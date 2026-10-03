import 'dart:convert';

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
import '../models/search_result.dart';
import '../models/stream_source.dart';
import '../models/track.dart';
import 'base_provider.dart';

/// A real, key-free, openly-licensed catalogue: the **Internet Archive**.
///
/// The Archive hosts public-domain and Creative-Commons audio (78rpm records,
/// the Live Music Archive, and user-uploaded open audio). Its search + metadata
/// APIs and its audio files are CORS-enabled so tracks stream in the web
/// preview as well as on Android. We only ever stream files the Archive already
/// serves publicly — nothing is scraped, extracted or redistributed.
class ArchiveProvider extends BaseMusicProvider {
  ArchiveProvider({required super.api, required super.cache});

  static const String _searchHost = 'archive.org';
  static const String _fluxBase = 'https://archive.org/metadata';
  static const String _downloadBase = 'https://archive.org/download';
  static const String _imgBase = 'https://archive.org/services/img';

  /// Collections that are safe to surface: public-domain + open audio.
  static const String _collections =
      '(78rpm OR audio_music OR audio_foreign OR opensource_audio OR etree OR '
      'netlabels OR audio_religion OR musicandarts)';

  static const List<Genre> _genres = <Genre>[
    Genre(id: 'jazz', name: 'Jazz'),
    Genre(id: 'classical', name: 'Classical'),
    Genre(id: 'blues', name: 'Blues'),
    Genre(id: 'rock', name: 'Rock'),
    Genre(id: 'folk', name: 'Folk'),
    Genre(id: 'country', name: 'Country'),
    Genre(id: 'electronic', name: 'Electronic'),
    Genre(id: 'oldtime', name: 'Old Time'),
  ];

  @override
  String get id => 'archive';

  @override
  String get displayName => 'Internet Archive';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: false, // downloads are handled by the Archive UI itself
        backgroundPlayback: true,
        lyrics: false,
        playlists: true,
        favorites: true,
        radio: true,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: false,
        qualityTiers: <String>['VBR', '128 kbps', '64 kbps'],
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> dispose() async {}

  // ---------------------------------------------------------------------------
  // Search + metadata
  // ---------------------------------------------------------------------------
  Uri _searchUri({
    required String query,
    required int rows,
    required int page,
    String sort = 'downloads desc',
  }) {
    return Uri.https(_searchHost, '/advancedsearch.php', <String, dynamic>{
      'q': query,
      'fl[]': <String>['identifier', 'title', 'creator', 'year', 'publicdate'],
      'sort[]': <String>[sort],
      'rows': '$rows',
      'page': '$page',
      'output': 'json',
    });
  }

  Future<List<_ArchiveDoc>> _runSearch(
    String query, {
    required int offset,
    required int limit,
    String sort = 'downloads desc',
  }) async {
    final int page = (offset ~/ limit) + 1;
    final Uri uri = _searchUri(query: query, rows: limit, page: page, sort: sort);
    final String key = 'archive:search:${_hash(query)}:$limit:$page:$sort';
    Map<String, dynamic>? json = cache.getJson(key);
    if (json == null) {
      try {
        json = await api.getJson(uri);
      } on AppException {
        rethrow;
      } catch (_) {
        throw const ProviderException('archive');
      }
      await cache.set(key, json, AppConstants.searchCacheTtl);
    }
    final dynamic response = json['response'];
    final List<dynamic> docs =
        (response is Map ? response['docs'] as List<dynamic>? : null) ?? <dynamic>[];
    return docs
        .map((dynamic e) => _ArchiveDoc.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<_ArchiveMetadata?> _fetchMetadata(String identifier) async {
    final Uri uri = Uri.parse('$_fluxBase/$identifier');
    final String key = 'archive:meta:$identifier';
    Map<String, dynamic>? json = cache.getJson(key);
    if (json == null) {
      try {
        json = await api.getJson(uri);
      } on NotFoundException {
        return null;
      } catch (e) {
        throw toAppException(e);
      }
      await cache.set(key, json, AppConstants.entityCacheTtl);
    }
    return _ArchiveMetadata.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------
  Track _docToTrack(_ArchiveDoc doc) {
    final String artistName = doc.creator.isNotEmpty ? doc.creator : 'Internet Archive';
    final Artist artist = Artist(
      id: 'archive:artist:${_slug(artistName)}',
      providerId: id,
      providerArtistId: _slug(artistName),
      name: artistName,
    );
    return Track(
      id: 'archive:track:${doc.identifier}',
      providerId: id,
      providerTrackId: doc.identifier,
      title: doc.title,
      artists: <Artist>[artist],
      album: Album(
        id: 'archive:album:${doc.identifier}',
        providerId: id,
        providerAlbumId: doc.identifier,
        title: doc.title,
        artists: <Artist>[artist],
        year: doc.year,
        artworkUrl: '$_imgBase/${doc.identifier}',
      ),
      duration: Duration.zero,
      artworkUrl: '$_imgBase/${doc.identifier}',
      isStreamable: true,
      isDownloadable: false,
      hasLyrics: false,
      qualityOptions: const <AudioQuality>[AudioQuality.normal],
      genre: null,
      extra: <String, dynamic>{'identifier': doc.identifier},
    );
  }

  // ---------------------------------------------------------------------------
  // Retrieval
  // ---------------------------------------------------------------------------
  @override
  Future<Track> getTrack(String trackId) async {
    final String identifier = trackId.replaceAll('archive:track:', '');
    final _ArchiveMetadata? meta = await _fetchMetadata(identifier);
    if (meta == null) throw const NotFoundException();
    final _ArchiveFile? file = _pickPlayableFile(meta.files);
    if (file == null) throw const TrackUnavailableException();

    final String artistName = meta.creator.isNotEmpty ? meta.creator : 'Internet Archive';
    final Artist artist = Artist(
      id: 'archive:artist:${_slug(artistName)}',
      providerId: id,
      providerArtistId: _slug(artistName),
      name: artistName,
    );
    return Track(
      id: trackId,
      providerId: id,
      providerTrackId: identifier,
      title: file.title.isNotEmpty ? file.title : meta.title,
      artists: <Artist>[artist],
      album: Album(
        id: 'archive:album:$identifier',
        providerId: id,
        providerAlbumId: identifier,
        title: meta.title,
        artists: <Artist>[artist],
        year: meta.year,
        artworkUrl: '$_imgBase/$identifier',
      ),
      duration: file.duration,
      artworkUrl: '$_imgBase/$identifier',
      isStreamable: true,
      qualityOptions: _qualityOptionsFor(file),
      extra: <String, dynamic>{
        'identifier': identifier,
        'fileName': file.name,
      },
    );
  }

  @override
  Future<StreamSource> getStream(Track track,
      {AudioQuality quality = AudioQuality.auto}) async {
    String? fileName = track.extra['fileName'] as String?;
    final String identifier =
        (track.extra['identifier'] as String?) ?? track.providerTrackId;

    if (fileName == null) {
      final _ArchiveMetadata? meta = await _fetchMetadata(identifier);
      if (meta == null) throw const NotFoundException();
      final _ArchiveFile? file = _pickPlayableFile(meta.files);
      if (file == null) throw const TrackUnavailableException();
      fileName = file.name;
    }

    final String url = '$_downloadBase/$identifier/${Uri.encodeComponent(fileName)}';
    return StreamSource(url: url, codec: _codecOf(fileName), qualityTier: 'VBR');
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    final String identifier = albumId.replaceAll('archive:album:', '');
    final Track t = await getTrack('archive:track:$identifier');
    return t.album ?? Album(
      id: albumId,
      providerId: id,
      providerAlbumId: identifier,
      title: t.title,
    );
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    final String slug = artistId.replaceAll('archive:artist:', '');
    final String name = slug.replaceAll('-', ' ');
    return Artist(id: artistId, providerId: id, providerArtistId: slug, name: name);
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    // Archive collections behave like provider-owned playlists.
    final String collection = playlistId.replaceAll('archive:playlist:', '');
    final List<_ArchiveDoc> docs = await _runSearch(
      'collection:$collection AND mediatype:audio',
      offset: 0,
      limit: 30,
    );
    return Playlist(
      id: playlistId,
      title: _titleCase(collection.replaceAll('_', ' ')),
      source: PlaylistSource.provider,
      providerId: id,
      tracks: docs.map(_docToTrack).toList(),
      trackCount: docs.length,
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
    final String q = query.trim();
    if (q.isEmpty) return SearchResult.empty;
    final String sanitized = q.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    final String lucene =
        'mediatype:audio AND ($_collections) AND (title:($sanitized) OR creator:($sanitized))';
    final List<_ArchiveDoc> docs =
        await _runSearch(lucene, offset: offset, limit: limit, sort: 'downloads desc');
    final List<Track> tracks = docs.map(_docToTrack).toList();
    final Map<String, Artist> artists = <String, Artist>{};
    final Map<String, Album> albums = <String, Album>{};
    for (final Track t in tracks) {
      for (final Artist a in t.artists) {
        artists[a.id] = a;
      }
      if (t.album != null) albums[t.album!.id] = t.album!;
    }
    return SearchResult(
      query: query,
      tracks: tracks,
      artists: artists.values.toList(),
      albums: albums.values.toList(),
    );
  }

  Future<PagedResult<Track>> _browse(
    String query, {
    required int offset,
    required int limit,
    String sort = 'downloads desc',
  }) async {
    final List<_ArchiveDoc> docs =
        await _runSearch(query, offset: offset, limit: limit, sort: sort);
    return PagedResult<Track>(
      items: docs.map(_docToTrack).toList(),
      total: offset + docs.length,
      hasMore: docs.length >= limit,
      nextOffset: offset + docs.length,
    );
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) =>
      _browse('mediatype:audio AND $_collections', offset: offset, limit: limit);

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) =>
      _browse(
        'mediatype:audio AND $_collections',
        offset: offset,
        limit: limit,
        sort: 'publicdate desc',
      );

  @override
  Future<PagedResult<Genre>> getGenres() async =>
      PagedResult<Genre>(items: _genres, total: _genres.length);

  @override
  Future<PagedResult<Track>> getTracksByGenre(String genreId,
      {int offset = 0, int limit = 20}) {
    return _browse(
      'mediatype:audio AND $_collections AND subject:("$genreId")',
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    final String slug = artistId.replaceAll('archive:artist:', '');
    final List<_ArchiveDoc> docs = await _runSearch(
      'creator:("${slug.replaceAll('-', ' ')}") AND mediatype:audio',
      offset: 0,
      limit: 12,
    );
    return docs
        .map((_ArchiveDoc d) => Album(
              id: 'archive:album:${d.identifier}',
              providerId: id,
              providerAlbumId: d.identifier,
              title: d.title,
              artworkUrl: '$_imgBase/${d.identifier}',
              year: d.year,
            ))
        .toList();
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final String slug = artistId.replaceAll('archive:artist:', '');
    final List<_ArchiveDoc> docs = await _runSearch(
      'creator:("${slug.replaceAll('-', ' ')}") AND mediatype:audio',
      offset: 0,
      limit: 20,
    );
    return docs.map(_docToTrack).toList();
  }

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations(
      {int offset = 0, int limit = 20}) async {
    // Open audio, most downloaded — a safe, license-clear recommendation set.
    return _browse(
      'mediatype:audio AND (collection:opensource_audio OR collection:78rpm)',
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async {
    final String creator = track.artists.isNotEmpty ? track.artists.first.name : '';
    final String q = creator.isNotEmpty
        ? 'mediatype:audio AND $_collections AND creator:("$creator")'
        : 'mediatype:audio AND $_collections AND subject:("${track.genre ?? 'music'}")';
    final List<_ArchiveDoc> docs = await _runSearch(q, offset: 0, limit: limit + 1);
    return docs
        .map(_docToTrack)
        .where((Track t) => t.id != track.id)
        .take(limit)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  _ArchiveFile? _pickPlayableFile(List<_ArchiveFile> files) {
    const List<String> preferred = <String>[
      'VBR MP3',
      '128Kbps MP3',
      '64Kbps MP3',
      'MP3',
      'Ogg Vorbis',
      'Flac',
    ];
    for (final String format in preferred) {
      for (final _ArchiveFile f in files) {
        if (f.format == format && _isPlayable(f.name)) return f;
      }
    }
    for (final _ArchiveFile f in files) {
      if (_isPlayable(f.name)) return f;
    }
    return null;
  }

  bool _isPlayable(String name) {
    final String lower = name.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav');
  }

  List<AudioQuality> _qualityOptionsFor(_ArchiveFile file) {
    final String lower = file.name.toLowerCase();
    if (lower.contains('64kbps')) {
      return const <AudioQuality>[AudioQuality.low, AudioQuality.normal];
    }
    if (lower.contains('128kbps')) {
      return const <AudioQuality>[AudioQuality.normal, AudioQuality.high];
    }
    return const <AudioQuality>[AudioQuality.normal, AudioQuality.high];
  }

  String? _codecOf(String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.ogg')) return 'ogg';
    if (lower.endsWith('.flac')) return 'flac';
    if (lower.endsWith('.m4a')) return 'm4a';
    if (lower.endsWith('.wav')) return 'wav';
    return null;
  }

  String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  String _titleCase(String s) => s
      .split(' ')
      .where((String w) => w.isNotEmpty)
      .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _hash(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

  static Duration parseArchiveLength(dynamic raw) {
    if (raw == null) return Duration.zero;
    if (raw is num) return Duration(milliseconds: (raw * 1000).round());
    final String s = raw.toString().trim();
    if (s.contains(':')) {
      final List<String> parts = s.split(':');
      try {
        final List<int> nums = parts.map((String p) => int.parse(p)).toList();
        if (nums.length == 2) {
          return Duration(minutes: nums[0], seconds: nums[1]);
        }
        if (nums.length == 3) {
          return Duration(hours: nums[0], minutes: nums[1], seconds: nums[2]);
        }
      } catch (_) {
        return Duration.zero;
      }
    }
    final double? secs = double.tryParse(s);
    if (secs == null) return Duration.zero;
    return Duration(milliseconds: (secs * 1000).round());
  }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------
class _ArchiveDoc {
  final String identifier;
  final String title;
  final String creator;
  final int? year;
  const _ArchiveDoc({
    required this.identifier,
    required this.title,
    required this.creator,
    this.year,
  });

  factory _ArchiveDoc.fromJson(Map<String, dynamic> json) {
    final dynamic creator = json['creator'];
    final String creatorStr = creator is List
        ? creator.whereType<String>().join(', ')
        : (creator?.toString() ?? '');
    return _ArchiveDoc(
      identifier: json['identifier'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      creator: creatorStr,
      year: int.tryParse(json['year']?.toString() ?? ''),
    );
  }
}

class _ArchiveMetadata {
  final String title;
  final String creator;
  final int? year;
  final List<_ArchiveFile> files;

  const _ArchiveMetadata({
    required this.title,
    required this.creator,
    required this.files,
    this.year,
  });

  factory _ArchiveMetadata.fromJson(Map<String, dynamic> json) {
    final dynamic meta = json['metadata'];
    final Map<String, dynamic> m =
        meta is Map ? meta.cast<String, dynamic>() : <String, dynamic>{};
    final dynamic creator = m['creator'];
    final String creatorStr = creator is List
        ? creator.whereType<String>().join(', ')
        : (creator?.toString() ?? '');
    final List<dynamic> rawFiles = (json['files'] as List<dynamic>?) ?? <dynamic>[];
    return _ArchiveMetadata(
      title: m['title']?.toString() ?? 'Untitled',
      creator: creatorStr,
      year: int.tryParse(m['year']?.toString() ?? ''),
      files: rawFiles
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => _ArchiveFile.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class _ArchiveFile {
  final String name;
  final String format;
  final String title;
  final Duration duration;

  const _ArchiveFile({
    required this.name,
    required this.format,
    required this.title,
    required this.duration,
  });

  factory _ArchiveFile.fromJson(Map<String, dynamic> json) => _ArchiveFile(
        name: json['name']?.toString() ?? '',
        format: json['format']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        duration: ArchiveProvider.parseArchiveLength(json['length']),
      );
}
