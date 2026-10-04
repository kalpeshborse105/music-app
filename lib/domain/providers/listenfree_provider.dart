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

/// ListenFreeProvider — Inactive Adapter for unverified ListenFree API source.
///
/// COMPLIANCE EVALUATION & STATUS:
/// - Status: Strictly [ProviderStatus.disabled].
/// - Catalog rights, redistribution terms, and stream URL provenance are unverified.
/// - Unofficial YouTube/YouTube Music audio scraping/extraction is prohibited.
/// - Refuses to generate downloadable or streamable audio without verified distribution licenses.
class ListenFreeProvider extends BaseMusicProvider {
  ListenFreeProvider({
    required super.api,
    required super.cache,
  });

  @override
  String get id => 'listenfree';

  @override
  String get displayName => 'ListenFree (Unverified Source — Disabled)';

  @override
  ProviderStatus get status => ProviderStatus.disabled;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: false,
        downloading: false,
        backgroundPlayback: false,
        search: false,
        browse: false,
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Track> getTrack(String trackId) async {
    throw ProviderException(
      id,
      message: 'ListenFree source is unverified and disabled for production distribution.',
    );
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    throw ProviderException(id, message: 'Source disabled: unverified catalog rights.');
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    throw ProviderException(id, message: 'Source disabled: unverified catalog rights.');
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    throw ProviderException(id, message: 'Source disabled: unverified catalog rights.');
  }

  @override
  Future<StreamSource> getStream(Track track, {AudioQuality quality = AudioQuality.auto}) async {
    throw ProviderException(
      id,
      message: 'Streaming from unverified ListenFree gateway is strictly disabled.',
    );
  }

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  @override
  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = 20,
    String? cursor,
  }) async =>
      SearchResult(
        query: query,
        tracks: const <Track>[],
        artists: const <Artist>[],
        albums: const <Album>[],
      );

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>(items: <Track>[], total: 0);

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>(items: <Track>[], total: 0);

  @override
  Future<PagedResult<Genre>> getGenres() async =>
      const PagedResult<Genre>(items: <Genre>[], total: 0);

  @override
  Future<PagedResult<Track>> getTracksByGenre(
    String genreId, {
    int offset = 0,
    int limit = 20,
  }) async =>
      const PagedResult<Track>(items: <Track>[], total: 0);

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => <Album>[];

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async => <Track>[];

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>(items: <Track>[], total: 0);

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async => <Track>[];
}
