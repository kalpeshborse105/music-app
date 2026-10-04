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

/// A small, always-available **royalty-free demo** catalogue.
///
/// This provider exists so the app is genuinely useful with zero configuration
/// (spec §50): its audio comes from SoundHelix, which publishes freely
/// distributable demo songs intended exactly for this purpose. It performs no
/// scraping and downloads nothing — the files are streamed directly from their
/// public host.
///
/// It is intentionally small (a curated set) but exposes real search,
/// streaming, radio and lyrics behaviour.
class DemoProvider extends BaseMusicProvider {
  DemoProvider({required super.api, required super.cache});

  static const String _host = 'https://www.soundhelix.com/examples/mp3';
  static const String _idPrefix = 'demo';

  /// Curated royalty-free tracks. Durations are approximate (VBR sources).
  static final List<_DemoTrackData> _catalogue = <_DemoTrackData>[
    const _DemoTrackData(1, 'Echoes of Dawn', 'SoundHelix', 'Aurora Sessions', 2021, 'Ambient', 372),
    const _DemoTrackData(2, 'Neon Cascade', 'SoundHelix', 'Aurora Sessions', 2021, 'Electronic', 425),
    const _DemoTrackData(3, 'Paper Lanterns', 'SoundHelix', 'Slow Rivers', 2022, 'Chill', 298),
    const _DemoTrackData(4, 'Midnight Circuit', 'SoundHelix', 'Neon Grid', 2022, 'Electronic', 341),
    const _DemoTrackData(5, 'Golden Hour Drive', 'SoundHelix', 'Slow Rivers', 2022, 'Chill', 388),
    const _DemoTrackData(6, 'Static Bloom', 'SoundHelix', 'Neon Grid', 2023, 'Electronic', 402),
    const _DemoTrackData(7, 'Velvet Skyline', 'SoundHelix', 'City Lights', 2023, 'Synthwave', 356),
    const _DemoTrackData(8, 'Northern Wires', 'SoundHelix', 'City Lights', 2023, 'Synthwave', 312),
    const _DemoTrackData(9, 'Analog Sunrise', 'SoundHelix', 'Aurora Sessions', 2021, 'Ambient', 445),
    const _DemoTrackData(10, 'Cassette Dreams', 'SoundHelix', 'Slow Rivers', 2022, 'Chill', 366),
    const _DemoTrackData(11, 'Pixel Rain', 'SoundHelix', 'Neon Grid', 2023, 'Electronic', 334),
    const _DemoTrackData(12, 'Horizon Line', 'SoundHelix', 'City Lights', 2023, 'Synthwave', 401),
    const _DemoTrackData(13, 'Low Orbit', 'SoundHelix', 'Analog Fields', 2024, 'Ambient', 378),
    const _DemoTrackData(14, 'Signal Fade', 'SoundHelix', 'Analog Fields', 2024, 'Ambient', 349),
    const _DemoTrackData(15, 'Coastal Lights', 'SoundHelix', 'City Lights', 2024, 'Synthwave', 322),
    const _DemoTrackData(16, 'Infinity Loop', 'SoundHelix', 'Analog Fields', 2024, 'Electronic', 397),
  ];

  @override
  String get id => 'demo';

  @override
  String get displayName => 'EchoFlow Masters';

  @override
  ProviderStatus get status => ProviderStatus.developmentOnly;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: true, // royalty-free demo files may be cached offline
        backgroundPlayback: true,
        lyrics: true,
        syncedLyrics: false,
        playlists: true,
        favorites: true,
        radio: true,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: false,
        qualityTiers: <String>['128 kbps'],
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> dispose() async {}

  // ---- Mapping ----
  Track _toTrack(_DemoTrackData d) {
    final String artistId = '$_idPrefix:artist:${_slug(d.artist)}';
    final String albumId = '$_idPrefix:album:${_slug(d.album)}';
    final String trackId = '$_idPrefix:track:${d.number}';
    final Artist artist = Artist(
      id: artistId,
      providerId: id,
      providerArtistId: _slug(d.artist),
      name: d.artist,
    );
    return Track(
      id: trackId,
      providerId: id,
      providerTrackId: '${d.number}',
      title: d.title,
      artists: <Artist>[artist],
      album: Album(
        id: albumId,
        providerId: id,
        providerAlbumId: _slug(d.album),
        title: d.album,
        artists: <Artist>[artist],
        year: d.year,
        artworkUrl: null,
      ),
      duration: Duration(seconds: d.seconds),
      artworkUrl: null,
      isStreamable: true,
      isDownloadable: true,
      hasLyrics: false,
      qualityOptions: const <AudioQuality>[AudioQuality.normal],
      genre: d.genre,
      extra: <String, dynamic>{'file': '$_host/SoundHelix-Song-${d.number}.mp3'},
    );
  }

  int? _numberFromId(String trackId) {
    final String value = trackId.replaceAll('$_idPrefix:track:', '');
    return int.tryParse(value);
  }

  String _slug(String s) => s.toLowerCase().replaceAll(' ', '-');

  // ---- Retrieval ----
  @override
  Future<Track> getTrack(String trackId) async {
    final int? n = _numberFromId(trackId);
    final _DemoTrackData d = _catalogue.firstWhere(
      (_DemoTrackData e) => e.number == n,
      orElse: () => _catalogue.first,
    );
    return _toTrack(d);
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    final String slug = albumId.replaceAll('$_idPrefix:album:', '');
    final List<_DemoTrackData> items =
        _catalogue.where((_DemoTrackData d) => _slug(d.album) == slug).toList();
    final _DemoTrackData first = items.isNotEmpty ? items.first : _catalogue.first;
    return Album(
      id: albumId,
      providerId: id,
      providerAlbumId: slug,
      title: first.album,
      artists: <Artist>[
        Artist(id: '$_idPrefix:artist:${_slug(first.artist)}', providerId: id, providerArtistId: _slug(first.artist), name: first.artist),
      ],
      year: first.year,
      trackCount: items.length,
    );
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    final String slug = artistId.replaceAll('$_idPrefix:artist:', '');
    final _DemoTrackData first = _catalogue.firstWhere(
      (_DemoTrackData d) => _slug(d.artist) == slug,
      orElse: () => _catalogue.first,
    );
    return Artist(
      id: artistId,
      providerId: id,
      providerArtistId: slug,
      name: first.artist,
    );
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async => Playlist(
        id: playlistId,
        title: 'Demo Mix',
        source: PlaylistSource.provider,
        providerId: id,
        trackCount: _catalogue.length,
        tracks: _catalogue.map(_toTrack).toList(),
      );

  @override
  Future<StreamSource> getStream(Track track,
      {AudioQuality quality = AudioQuality.auto}) async {
    final String? file = track.extra['file'] as String?;
    final String url = file ?? '$_host/SoundHelix-Song-1.mp3';
    return StreamSource(
      url: url,
      bitrateKbps: 128,
      codec: 'mp3',
      qualityTier: '128 kbps',
    );
  }

  @override
  Future<Lyrics> getLyrics(Track track) async =>
      Lyrics(trackId: track.id, plain: null, source: 'demo');

  // ---- Discovery ----
  @override
  Future<SearchResult> search(String query,
      {int offset = 0, int limit = 20, String? cursor}) async {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return SearchResult.empty;
    final List<Track> matches = _catalogue
        .where((_DemoTrackData d) =>
            d.title.toLowerCase().contains(q) ||
            d.artist.toLowerCase().contains(q) ||
            d.album.toLowerCase().contains(q) ||
            d.genre.toLowerCase().contains(q))
        .map(_toTrack)
        .toList();
    final Map<String, Artist> artists = <String, Artist>{};
    final Map<String, Album> albums = <String, Album>{};
    for (final Track t in matches) {
      for (final Artist a in t.artists) {
        artists[a.id] = a;
      }
      if (t.album != null) albums[t.album!.id] = t.album!;
    }
    return SearchResult(
      query: query,
      tracks: _paginate(matches, offset, limit),
      artists: artists.values.toList(),
      albums: albums.values.toList(),
    );
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async {
    final List<Track> all = _catalogue.map(_toTrack).toList();
    return PagedResult<Track>(
      items: _paginate(all, offset, limit),
      total: all.length,
      hasMore: offset + limit < all.length,
      nextOffset: offset + limit,
    );
  }

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async {
    final List<Track> all = _catalogue.reversed.map(_toTrack).toList();
    return PagedResult<Track>(
      items: _paginate(all, offset, limit),
      total: all.length,
      hasMore: offset + limit < all.length,
      nextOffset: offset + limit,
    );
  }

  @override
  Future<PagedResult<Genre>> getGenres() async {
    final Set<String> genres =
        _catalogue.map((_DemoTrackData d) => d.genre).toSet();
    return PagedResult<Genre>(
      items: genres
          .map((String g) => Genre(id: _slug(g), name: g))
          .toList(),
      total: genres.length,
      hasMore: false,
    );
  }

  @override
  Future<PagedResult<Track>> getTracksByGenre(String genreId,
      {int offset = 0, int limit = 20}) async {
    final List<Track> all = _catalogue
        .where((_DemoTrackData d) => _slug(d.genre) == genreId)
        .map(_toTrack)
        .toList();
    return PagedResult<Track>(
      items: _paginate(all, offset, limit),
      total: all.length,
      hasMore: offset + limit < all.length,
    );
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    final String slug = artistId.replaceAll('$_idPrefix:artist:', '');
    final Set<String> albums = _catalogue
        .where((_DemoTrackData d) => _slug(d.artist) == slug)
        .map((_DemoTrackData d) => d.album)
        .toSet();
    return albums.map((String a) => Album(
          id: '$_idPrefix:album:${_slug(a)}',
          providerId: id,
          providerAlbumId: _slug(a),
          title: a,
        )).toList();
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final String slug = artistId.replaceAll('$_idPrefix:artist:', '');
    return _catalogue
        .where((_DemoTrackData d) => _slug(d.artist) == slug)
        .map(_toTrack)
        .toList();
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
    final String? genre = track.genre;
    final List<Track> pool = _catalogue
        .where((_DemoTrackData d) => genre == null || d.genre == genre)
        .map(_toTrack)
        .where((Track t) => t.id != track.id)
        .toList();
    pool.shuffle();
    return pool.take(limit).toList();
  }

  List<T> _paginate<T>(List<T> all, int offset, int limit) {
    if (offset >= all.length) return <T>[];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }
}

class _DemoTrackData {
  final int number;
  final String title;
  final String artist;
  final String album;
  final int year;
  final String genre;
  final int seconds;
  const _DemoTrackData(
    this.number,
    this.title,
    this.artist,
    this.album,
    this.year,
    this.genre,
    this.seconds,
  );
}
