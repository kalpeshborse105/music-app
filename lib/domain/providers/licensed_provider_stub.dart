import '../../core/config/app_config.dart';
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

/// Template adapter for a **commercial/licensed** music provider.
///
/// This intentionally implements no provider specifics — it documents the exact
/// shape a real integration must take and refuses to fabricate results. Wire it
/// up by filling the marked TODOs against your licensor's API, then supply
/// `--dart-define=LICENSED_BASE_URL=... --dart-define=LICENSED_API_KEY=...`.
///
/// NOTE: per spec §30/§31, a real provider key must never be shipped in the
/// client. Production deployments should route authenticated calls through a
/// backend/token-service and hand the client only short-lived playback tokens.
/// The [capabilities] and methods below show the contract the UI relies on.
class LicensedProviderStub extends BaseMusicProvider {
  LicensedProviderStub({required super.api, required super.cache});

  @override
  String get id => 'licensed';

  @override
  String get displayName => 'Licensed Provider (not configured)';

  @override
  ProviderStatus get status => ProviderStatus.licensePending;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: true,
        downloading: true,
        backgroundPlayback: true,
        lyrics: true,
        syncedLyrics: true,
        playlists: true,
        favorites: true,
        radio: true,
        search: true,
        browse: true,
        recommendations: true,
        explicitContentMetadata: true,
        requiresApiKey: true,
        qualityTiers: <String>['64 kbps', '128 kbps', '256 kbps', '320 kbps'],
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => AppConfig.licensedConfigured;

  @override
  Future<void> dispose() async {}

  Never _notConfigured() => throw const UnsupportedOperationException(
        message: 'No licensed provider is configured. Add credentials in Settings.',
      );

  @override
  Future<Track> getTrack(String trackId) async => _notConfigured();

  @override
  Future<Album> getAlbum(String albumId) async => _notConfigured();

  @override
  Future<Artist> getArtist(String artistId) async => _notConfigured();

  @override
  Future<Playlist> getPlaylist(String playlistId) async => _notConfigured();

  @override
  Future<StreamSource> getStream(Track track,
          {AudioQuality quality = AudioQuality.auto}) async =>
      _notConfigured();

  @override
  Future<Lyrics> getLyrics(Track track) async => Lyrics.unavailable;

  @override
  Future<SearchResult> search(String query,
          {int offset = 0, int limit = 20, String? cursor}) async =>
      SearchResult.empty;

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<PagedResult<Genre>> getGenres() async => const PagedResult<Genre>.empty();

  @override
  Future<PagedResult<Track>> getTracksByGenre(String genreId,
          {int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => <Album>[];

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async => <Track>[];

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations(
          {int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async => <Track>[];
}
