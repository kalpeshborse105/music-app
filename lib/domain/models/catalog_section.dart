import 'track.dart';
import 'artist.dart';
import 'album.dart';
import 'media_type.dart';
import 'audio_quality.dart';

class CatalogSection {
  final String id;
  final String key;
  final String sourceUrl;
  final String sourceType;
  final String sourceId;
  final String slug;
  final String displayTitle;
  final String displayGroup;
  /// `entity` (default) or `tracks` — Home horizontal song shelf when tracks.
  final String displayMode;
  final String? subtitle;
  final String language;
  final int position;
  final bool isEnabled;
  final String providerStatus;
  final int lastRefresh;
  final int updatedAt;
  final String? lastError;
  final String? customArtworkUrl;
  final bool isBanner;
  final int? campaignStart;
  final int? campaignEnd;
  final bool isMock;
  final int itemCount;
  final List<Track> items;
  final List<String> excludedTrackIds;
  final List<Track> customTracks;

  String get sectionKey => key;

  String? get effectiveArtworkUrl =>
      (customArtworkUrl != null && customArtworkUrl!.isNotEmpty)
          ? customArtworkUrl
          : (items.isNotEmpty ? items.first.artworkUrl : null);

  bool get isCampaignActive {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (campaignStart != null && now < campaignStart!) return false;
    if (campaignEnd != null && now > campaignEnd!) return false;
    return true;
  }

  const CatalogSection({
    required this.id,
    required this.key,
    required this.sourceUrl,
    required this.sourceType,
    required this.sourceId,
    required this.slug,
    required this.displayTitle,
    required this.displayGroup,
    this.displayMode = 'entity',
    this.subtitle,
    required this.language,
    required this.position,
    required this.isEnabled,
    this.customArtworkUrl,
    this.isBanner = false,
    this.campaignStart,
    this.campaignEnd,
    required this.providerStatus,
    required this.lastRefresh,
    this.updatedAt = 0,
    this.lastError,
    required this.isMock,
    required this.itemCount,
    required this.items,
    this.excludedTrackIds = const <String>[],
    this.customTracks = const <Track>[],
  });

  static bool _isJunkCatalogTrack(Map<String, dynamic> item) {
    if (item['is_mock'] == true) return true;
    final String title = (item['title'] as String? ?? '').trim();
    final String artist = (item['artist'] as String? ?? '').trim();
    final String id = (item['id'] as String? ?? item['token'] as String? ?? '').trim();
    if (title.isEmpty) return true;
    final String tl = title.toLowerCase();
    final String al = artist.toLowerCase();
    if (tl.contains('sample trailer') || tl.startsWith('this is a sample')) {
      return true;
    }
    if (al == 'null' || al == 'none' || al == 'undefined' || al == 'n/a') {
      return true;
    }
    if (artist.toUpperCase() == 'NULL') return true;
    if (id.isEmpty || id.toLowerCase() == 'null') return true;
    return false;
  }

  static int _asUnixSeconds(dynamic value) {
    if (value == null) return 0;
    if (value is num) {
      final int n = value.toInt();
      // ms timestamps → seconds
      return n > 20000000000 ? (n ~/ 1000) : n;
    }
    final String raw = value.toString().trim();
    if (raw.isEmpty) return 0;
    final int? asInt = int.tryParse(raw);
    if (asInt != null) {
      return asInt > 20000000000 ? (asInt ~/ 1000) : asInt;
    }
    try {
      return DateTime.parse(raw).toUtc().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  factory CatalogSection.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = (json['items'] as List<dynamic>?) ?? <dynamic>[];
    final List<Track> parsedItems = rawItems
        .whereType<Map>()
        .map((Map m) => Map<String, dynamic>.from(m))
        .where((Map<String, dynamic> item) => !_isJunkCatalogTrack(item))
        .map((Map<String, dynamic> item) {
      final String trackId = item['id'] as String? ?? '';
      final String title = item['title'] as String? ?? 'Untitled';
      final String artist = item['artist'] as String? ?? 'Unknown Artist';
      final String? artworkUrl = item['artwork_url'] as String?;
      final int durationMs = (item['duration_ms'] as num?)?.toInt() ?? 210000;
      final bool isMock = item['is_mock'] == true;

      return Track(
        id: 'custom_api:track:$trackId',
        providerId: 'custom_api',
        providerTrackId: trackId,
        title: title,
        artists: <Artist>[
          Artist(
            id: 'custom_api:artist:$artist',
            providerId: 'custom_api',
            providerArtistId: artist,
            name: artist,
          ),
        ],
        album: Album(
          id: 'custom_api:album:$trackId',
          providerId: 'custom_api',
          providerAlbumId: trackId,
          title: item['album'] as String? ?? 'Single',
          artworkUrl: artworkUrl,
        ),
        duration: Duration(milliseconds: durationMs),
        artworkUrl: artworkUrl,
        explicit: false,
        mediaType: MediaType.audio,
        isStreamable: true,
        isDownloadable: false,
        hasLyrics: false,
        qualityOptions: const <AudioQuality>[AudioQuality.high],
        commercialUseAllowed: false,
        backgroundPlaybackAllowed: true,
        license: isMock ? 'Mock Development License' : 'Cloud Gateway Stream',
        attributionRequired: false,
        extra: <String, dynamic>{
          'is_mock': isMock,
          'language': item['language'] ?? '',
          'year': item['year'] ?? '',
        },
      );
    }).toList();

    return CatalogSection(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? 'playlist',
      sourceId: json['source_id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      displayTitle: json['display_title'] as String? ?? 'Untitled Section',
      displayGroup: json['display_group'] as String? ?? 'Featured',
      displayMode: () {
        final String raw =
            (json['display_mode'] as String?)?.trim().toLowerCase() ?? '';
        if (raw == 'tracks' || raw == 'songs' || raw == 'song') {
          return 'tracks';
        }
        final String st =
            (json['source_type'] as String?)?.trim().toLowerCase() ?? '';
        // Treat song/track as tracks shelf; ignore bogus "None"/null strings from API.
        if (st == 'song' || st == 'track') {
          return 'tracks';
        }
        return 'entity';
      }(),
      subtitle: json['subtitle'] as String?,
      language: json['language'] as String? ?? 'all',
      position: (json['position'] as num?)?.toInt() ?? 1,
      isEnabled: json['is_enabled'] != false,
      customArtworkUrl: json['custom_artwork_url'] as String? ?? json['artwork_url'] as String?,
      isBanner: json['is_banner'] == true,
      campaignStart: () {
        final int v = _asUnixSeconds(json['campaign_start']);
        return v > 0 ? v : null;
      }(),
      campaignEnd: () {
        final int v = _asUnixSeconds(json['campaign_end']);
        return v > 0 ? v : null;
      }(),
      providerStatus: json['provider_status'] as String? ?? 'ok',
      lastRefresh: _asUnixSeconds(json['last_refresh']),
      updatedAt: _asUnixSeconds(json['updated_at']),
      lastError: json['last_error'] as String?,
      isMock: json['is_mock'] == true,
      // Live payloads win. If raw items existed but were all mock/junk, force 0
      // so Home never shows seed "5 songs" with an empty TrackListScreen.
      itemCount: parsedItems.isNotEmpty
          ? parsedItems.length
          : (rawItems.isNotEmpty
              ? 0
              : ((json['item_count'] as num?)?.toInt() ?? 0)),
      items: parsedItems,
      excludedTrackIds: ((json['excluded_track_ids'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> _trackToCatalogItem(Track t) {
    final String rawId = t.providerTrackId.trim().isNotEmpty
        ? t.providerTrackId.trim()
        : t.id.replaceFirst(RegExp(r'^custom_api:track:'), '');
    return <String, dynamic>{
      'id': rawId,
      'title': t.title,
      'artist': t.artistNames,
      'artwork_url': t.artworkUrl,
      'duration_ms': t.duration.inMilliseconds,
      'album': t.album?.title ?? 'Single',
      'is_mock': t.extra['is_mock'] == true,
      if (t.extra['language'] != null) 'language': t.extra['language'],
      if (t.extra['year'] != null) 'year': t.extra['year'],
    };
  }

  Map<String, dynamic> toJson() {
    // Persist a capped items payload so Home cache-first reopen is instant
    // and song counts match what TrackListScreen will show.
    final List<Map<String, dynamic>> cachedItems = items
        .take(40)
        .map(_trackToCatalogItem)
        .toList();
    return <String, dynamic>{
      'id': id,
      'key': key,
      'source_url': sourceUrl,
      'source_type': sourceType,
      'source_id': sourceId,
      'slug': slug,
      'display_title': displayTitle,
      'display_group': displayGroup,
      'display_mode': displayMode,
      if (subtitle != null) 'subtitle': subtitle,
      'language': language,
      'position': position,
      'is_enabled': isEnabled,
      'custom_artwork_url': customArtworkUrl,
      'is_banner': isBanner,
      if (campaignStart != null) 'campaign_start': campaignStart,
      if (campaignEnd != null) 'campaign_end': campaignEnd,
      'provider_status': providerStatus,
      'last_refresh': lastRefresh,
      'updated_at': updatedAt,
      'last_error': lastError,
      'is_mock': isMock,
      'item_count': cachedItems.isNotEmpty ? cachedItems.length : itemCount,
      'items': cachedItems,
      'excluded_track_ids': excludedTrackIds,
    };
  }

  CatalogSection copyWith({
    String? id,
    String? key,
    String? sourceUrl,
    String? sourceType,
    String? sourceId,
    String? slug,
    String? displayTitle,
    String? displayGroup,
    String? displayMode,
    String? subtitle,
    String? language,
    int? position,
    bool? isEnabled,
    String? customArtworkUrl,
    bool? isBanner,
    int? campaignStart,
    int? campaignEnd,
    String? providerStatus,
    int? lastRefresh,
    int? updatedAt,
    String? lastError,
    bool? isMock,
    int? itemCount,
    List<Track>? items,
    List<String>? excludedTrackIds,
    List<Track>? customTracks,
  }) {
    return CatalogSection(
      id: id ?? this.id,
      key: key ?? this.key,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      slug: slug ?? this.slug,
      displayTitle: displayTitle ?? this.displayTitle,
      displayGroup: displayGroup ?? this.displayGroup,
      displayMode: displayMode ?? this.displayMode,
      subtitle: subtitle ?? this.subtitle,
      language: language ?? this.language,
      position: position ?? this.position,
      isEnabled: isEnabled ?? this.isEnabled,
      customArtworkUrl: customArtworkUrl ?? this.customArtworkUrl,
      isBanner: isBanner ?? this.isBanner,
      campaignStart: campaignStart ?? this.campaignStart,
      campaignEnd: campaignEnd ?? this.campaignEnd,
      providerStatus: providerStatus ?? this.providerStatus,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: lastError ?? this.lastError,
      isMock: isMock ?? this.isMock,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
      excludedTrackIds: excludedTrackIds ?? this.excludedTrackIds,
      customTracks: customTracks ?? this.customTracks,
    );
  }
}
