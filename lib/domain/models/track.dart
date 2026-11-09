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

  factory Track.fromJson(Map<String, dynamic> json) {
    // 1. Safe Artists Parsing
    List<Artist> parsedArtists = <Artist>[];
    if (json['artists'] is List) {
      for (final dynamic e in json['artists'] as List) {
        if (e is Map<String, dynamic>) {
          parsedArtists.add(Artist.fromJson(e));
        } else if (e is Map) {
          parsedArtists.add(Artist.fromJson(Map<String, dynamic>.from(e)));
        } else if (e is String && e.trim().isNotEmpty) {
          parsedArtists.add(Artist(
            id: 'artist:${e.trim()}',
            providerId: json['providerId'] as String? ?? 'custom_api',
            providerArtistId: e.trim(),
            name: e.trim(),
          ));
        }
      }
    }
    if (parsedArtists.isEmpty && json['artist'] is String && (json['artist'] as String).trim().isNotEmpty) {
      final String art = (json['artist'] as String).trim();
      parsedArtists = <Artist>[
        Artist(
          id: 'artist:$art',
          providerId: json['providerId'] as String? ?? 'custom_api',
          providerArtistId: art,
          name: art,
        ),
      ];
    }

    // 2. Safe Album Parsing
    Album? parsedAlbum;
    if (json['album'] is Map<String, dynamic>) {
      parsedAlbum = Album.fromJson(json['album'] as Map<String, dynamic>);
    } else if (json['album'] is Map) {
      parsedAlbum = Album.fromJson(Map<String, dynamic>.from(json['album'] as Map));
    } else if (json['album'] is String && (json['album'] as String).trim().isNotEmpty) {
      final String albTitle = (json['album'] as String).trim();
      final String albumId = json['album_id']?.toString() ?? json['albumId']?.toString() ?? albTitle;
      final String? artUrl = json['artworkUrl'] as String? ?? json['artwork_url'] as String?;
      parsedAlbum = Album(
        id: 'album:$albumId',
        providerId: json['providerId'] as String? ?? 'custom_api',
        providerAlbumId: albumId,
        title: albTitle,
        artworkUrl: artUrl,
      );
    }

    // 3. Duration Parsing (handles num, string, seconds, milliseconds, or null safely)
    int durMs = 0;
    final dynamic rawDurMs = json['durationMs'] ?? json['duration_ms'];
    final dynamic rawDur = json['duration'];
    if (rawDurMs != null) {
      durMs = (rawDurMs is num) ? rawDurMs.toInt() : (int.tryParse(rawDurMs.toString()) ?? 0);
    }
    if (durMs <= 0 && rawDur != null) {
      final double s = (rawDur is num) ? rawDur.toDouble() : (double.tryParse(rawDur.toString()) ?? 0.0);
      durMs = s > 10000 ? s.round() : (s * 1000).round();
    }

    // 4. Artwork URL Parsing
    final String? artworkUrl = json['artworkUrl'] as String? ?? json['artwork_url'] as String? ?? json['thumbnail'] as String?;

    return Track(
      id: json['id'] as String? ?? '',
      providerId: json['providerId'] as String? ?? 'custom_api',
      providerTrackId: json['providerTrackId'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown track',
      artists: parsedArtists,
      album: parsedAlbum,
      duration: Duration(milliseconds: durMs),
      artworkUrl: artworkUrl,
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
      extra: (json['extra'] as Map<String, dynamic>?) ?? json,
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
