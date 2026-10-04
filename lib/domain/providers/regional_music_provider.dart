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

/// Supported regional Indian languages for future licensed catalog integration.
enum RegionalLanguage {
  hindi('Hindi', 'hi'),
  marathi('Marathi', 'mr'),
  khandeshi('Khandeshi', 'khn'),
  gujarati('Gujarati', 'gu'),
  punjabi('Punjabi', 'pa'),
  bengali('Bengali', 'bn'),
  tamil('Tamil', 'ta'),
  telugu('Telugu', 'te'),
  kannada('Kannada', 'kn'),
  malayalam('Malayalam', 'ml'),
  odia('Odia', 'or'),
  assamese('Assamese', 'as');

  final String displayName;
  final String isoCode;
  const RegionalLanguage(this.displayName, this.isoCode);
}

/// RegionalMusicProvider — Architected for future Indian-language music partnerships.
///
/// COMPLIANCE & LEGAL SAFETY POLICY:
/// - strictly rejects unofficial scrapers, proxy APIs, or unapproved YouTube/stream extractors.
/// - Status is marked as [ProviderStatus.licensePending] until a verified commercial licensing agreement
///   (e.g., licensed Bollywood / Marathi / Khandeshi partners) is executed.
/// - Does NOT fabricate fake tracks; discovery methods safely yield empty results until licensing is live.
class RegionalMusicProvider extends BaseMusicProvider {
  RegionalMusicProvider({
    required super.api,
    required super.cache,
  });

  @override
  String get id => 'regional_indian';

  @override
  String get displayName => 'Regional Indian Music (License Pending)';

  @override
  ProviderStatus get status => ProviderStatus.licensePending;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        streaming: false,
        downloading: false,
        backgroundPlayback: true,
        lyrics: false,
        playlists: false,
        favorites: true,
        radio: false,
        search: true,
        browse: true,
        recommendations: false,
        explicitContentMetadata: false,
        requiresApiKey: true,
        qualityTiers: <String>['128 kbps AAC', '320 kbps MP3', 'FLAC lossless'],
      );

  List<RegionalLanguage> get supportedLanguages => RegionalLanguage.values;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async {
    // Only available when commercial regional streaming rights/keys are configured
    return false;
  }

  @override
  Future<Track> getTrack(String trackId) async {
    throw ProviderException(
      id,
      message: 'Regional catalog requires an active commercial streaming license agreement.',
    );
  }

  @override
  Future<Album> getAlbum(String albumId) async {
    throw ProviderException(
      id,
      message: 'Regional album catalog is pending commercial partner licensing.',
    );
  }

  @override
  Future<Artist> getArtist(String artistId) async {
    throw ProviderException(
      id,
      message: 'Regional artist catalog is pending commercial partner licensing.',
    );
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    throw ProviderException(
      id,
      message: 'Regional playlist catalog is pending commercial partner licensing.',
    );
  }

  @override
  Future<StreamSource> getStream(
    Track track, {
    AudioQuality quality = AudioQuality.auto,
  }) async {
    throw ProviderException(
      id,
      message: 'Streaming regional content requires signed copyright licensing.',
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
  }) async {
    // Safely returns empty without fabricating unauthorized/fake tracks
    return SearchResult.empty;
  }

  @override
  Future<PagedResult<Track>> getTrending({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<PagedResult<Track>> getNewReleases({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<PagedResult<Genre>> getGenres() async {
    return PagedResult<Genre>(
      items: supportedLanguages
          .map((RegionalLanguage lang) => Genre(
                id: 'lang:${lang.isoCode}',
                name: '${lang.displayName} Regional',
              ))
          .toList(),
      total: supportedLanguages.length,
    );
  }

  @override
  Future<PagedResult<Track>> getTracksByGenre(
    String genreId, {
    int offset = 0,
    int limit = 20,
  }) async =>
      const PagedResult<Track>.empty();

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => <Album>[];

  @override
  Future<List<Track>> getArtistTopTracks(String artistId) async => <Track>[];

  @override
  Future<List<Artist>> getSimilarArtists(String artistId) async => <Artist>[];

  @override
  Future<PagedResult<Track>> getRecommendations({int offset = 0, int limit = 20}) async =>
      const PagedResult<Track>.empty();

  @override
  Future<List<Track>> getRadio(Track track, {int limit = 20}) async => <Track>[];
}
