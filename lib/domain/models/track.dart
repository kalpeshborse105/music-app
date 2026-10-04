import 'album.dart';
import 'artist.dart';
import 'audio_quality.dart';
import 'media_type.dart';

/// The central normalized track model. Every provider maps its own payloads
/// onto this shape so the rest of the app never depends on a single provider.
class Track {
  /// Globally unique id, namespaced by provider: `jamendo:track:12345`.
  final String id;

  /// Provider that owns this record.
  final String providerId;

  /// Id within the owning provider (used for getStream/getLyrics).
  final String providerTrackId;

  final String title;
  final List<Artist> artists;
  final Album? album;
  final Duration duration;
  final String? artworkUrl;

  /// Explicit content flag (only meaningful when the provider supplies it).
  final bool explicit;

  final MediaType mediaType;

  /// ---- Availability flags (drive which UI actions are enabled) ----
  final bool isStreamable;
  final bool isDownloadable;
  final bool hasLyrics;

  /// Quality tiers the provider reports for this track (may be empty = unknown).
  final List<AudioQuality> qualityOptions;

  /// ISO 639-1 genre label if the provider exposes one.
  final String? genre;

  /// ---- Provider Compliance Model ----
  final bool commercialUseAllowed;
  final bool backgroundPlaybackAllowed;
  final String? license;
  final String? licenseUrl;
  final bool attributionRequired;

  /// Compliance alias getters
  String get provider => providerId;
  bool get streamAllowed => isStreamable;
  bool get downloadAllowed => isDownloadable;

  /// Free-form provider metadata we keep for richer detail pages.
  final Map<String, dynamic> extra;

  const Track({
    required this.id,
    required this.providerId,
    required this.providerTrackId,
    required this.title,
    this.artists = const <Artist>[],
    this.album,
    this.duration = Duration.zero,
    this.artworkUrl,
    this.explicit = false,
    this.mediaType = MediaType.audio,
    this.isStreamable = true,
    this.isDownloadable = false,
    this.hasLyrics = false,
    this.qualityOptions = const <AudioQuality>[],
    this.genre,
    this.commercialUseAllowed = false,
    this.backgroundPlaybackAllowed = true,
    this.license,
    this.licenseUrl,
    this.attributionRequired = true,
    this.extra = const <String, dynamic>{},
  });

  String get artistNames =>
      artists.isEmpty ? 'Unknown artist' : artists.map((Artist a) => a.name).join(', ');

  Artist get primaryArtist =>
      artists.isNotEmpty ? artists.first : Artist.local('Unknown artist');

  /// A compact lightweight copy used for persistence in the queue, history and
  /// library, avoiding very large `extra` blobs.
  Track toCompact() => Track(
        id: id,
        providerId: providerId,
        providerTrackId: providerTrackId,
        title: title,
        artists: artists,
        album: album,
        duration: duration,
        artworkUrl: artworkUrl,
        explicit: explicit,
        mediaType: mediaType,
        isStreamable: isStreamable,
        isDownloadable: isDownloadable,
        hasLyrics: hasLyrics,
        qualityOptions: qualityOptions,
        genre: genre,
        commercialUseAllowed: commercialUseAllowed,
        backgroundPlaybackAllowed: backgroundPlaybackAllowed,
        license: license,
        licenseUrl: licenseUrl,
        attributionRequired: attributionRequired,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'providerTrackId': providerTrackId,
        'title': title,
        'artists': artists.map((Artist a) => a.toJson()).toList(),
        'album': album?.toJson(),
        'durationMs': duration.inMilliseconds,
        'artworkUrl': artworkUrl,
        'explicit': explicit,
        'mediaType': mediaType.name,
        'isStreamable': isStreamable,
        'isDownloadable': isDownloadable,
        'hasLyrics': hasLyrics,
        'qualityOptions': qualityOptions.map((AudioQuality q) => q.storageId).toList(),
        'genre': genre,
        'commercialUseAllowed': commercialUseAllowed,
        'backgroundPlaybackAllowed': backgroundPlaybackAllowed,
        'license': license,
        'licenseUrl': licenseUrl,
        'attributionRequired': attributionRequired,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String? ?? '',
        providerId: json['providerId'] as String? ?? '',
        providerTrackId: json['providerTrackId'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown track',
        artists: ((json['artists'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => Artist.fromJson(e as Map<String, dynamic>))
            .toList(),
        album: json['album'] == null
            ? null
            : Album.fromJson(json['album'] as Map<String, dynamic>),
        duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
        artworkUrl: json['artworkUrl'] as String?,
        explicit: json['explicit'] as bool? ?? false,
        mediaType: MediaType.values.firstWhere(
          (MediaType m) => m.name == json['mediaType'],
          orElse: () => MediaType.audio,
        ),
        isStreamable: json['isStreamable'] as bool? ?? true,
        isDownloadable: json['isDownloadable'] as bool? ?? false,
        hasLyrics: json['hasLyrics'] as bool? ?? false,
        qualityOptions: ((json['qualityOptions'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => AudioQualityX.fromId(e as String?))
            .toList(),
        genre: json['genre'] as String?,
        commercialUseAllowed: json['commercialUseAllowed'] as bool? ?? false,
        backgroundPlaybackAllowed: json['backgroundPlaybackAllowed'] as bool? ?? true,
        license: json['license'] as String?,
        licenseUrl: json['licenseUrl'] as String?,
        attributionRequired: json['attributionRequired'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
