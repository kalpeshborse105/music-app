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

/// The contract every music source implements.
///
/// The UI and repositories depend only on this interface, never on a concrete
/// provider. Implementations must be resilient: one provider failing must not
/// crash the app. Methods should throw [AppException] subclasses on failure.
abstract class MusicProvider {
  /// Stable machine id, e.g. `jamendo`, `demo`, `local`, `licensed`.
  String get id;

  /// Human-readable name shown in settings / source labels.
  String get displayName;

  /// What this provider can do. The UI reads these flags.
  ProviderCapabilities get capabilities;

  /// Whether the provider is currently usable (configured && reachable).
  /// A provider may be unavailable if it requires an API key that is missing.
  Future<bool> isAvailable();

  /// Optional initialization (open boxes, request permissions...).
  Future<void> initialize();

  /// Release resources.
  Future<void> dispose();

  // ---- Core retrieval ----

  Future<Track> getTrack(String trackId);

  Future<Album> getAlbum(String albumId);

  Future<Artist> getArtist(String artistId);

  Future<Playlist> getPlaylist(String playlistId);

  /// Resolve a playable source for a track at the requested quality.
  /// Only called when [Track.isStreamable] is true.
  Future<StreamSource> getStream(Track track, {AudioQuality quality = AudioQuality.auto});

  Future<Lyrics> getLyrics(Track track);

  // ---- Discovery ----

  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = 20,
    String? cursor,
  });

  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20});

  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20});

  Future<PagedResult<Genre>> getGenres();

  Future<PagedResult<Track>> getTracksByGenre(
    String genreId, {
    int offset = 0,
    int limit = 20,
  });

  Future<List<Album>> getArtistAlbums(String artistId);

  Future<List<Track>> getArtistTopTracks(String artistId);

  Future<List<Artist>> getSimilarArtists(String artistId);

  // ---- Selection / radio (provider-authorized sources only) ----

  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20});

  /// Builds a continuous, duplicate-free radio queue seeded by [track].
  Future<List<Track>> getRadio(Track track, {int limit = 20});
}
