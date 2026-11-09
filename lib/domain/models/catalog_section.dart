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
  final String? contentHash;
  final int? contentVersion;

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
    this.contentHash,
    this.contentVersion,
  });

  static bool _isJunkCatalogTrack(Map<String, dynamic> item) {
    if (item['is_mock'] == true) return true;
    final String title = _asString(item['title'])?.trim() ?? '';
    final String artist = _asString(item['artist'])?.trim() ?? '';
    final String id =
        (_asString(item['id']) ?? _asString(item['token']) ?? '').trim();
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

  /// Jio / create responses sometimes nest objects (album Map, last_error JSON).
  /// Never cast those with `as String?` — that throws `_JsonMap` on admin Save.
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is Map) {
      final dynamic titled = value['title'] ?? value['name'] ?? value['message'];
      if (titled is String && titled.trim().isNotEmpty) return titled;
      return null;
    }
    return null;
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
      final String trackId = _asString(item['id']) ??
          _asString(item['providerTrackId']) ??
          '';
      final String title = _asString(item['title']) ?? 'Untitled';
      String artist = _asString(item['artist']) ?? '';
      if (artist.isEmpty && item['artists'] is List) {
        final List<String> names = <String>[];
        for (final dynamic a in item['artists'] as List<dynamic>) {
          if (a is Map) {
            final String? n = _asString(a['name']) ?? _asString(a['title']);
            if (n != null && n.trim().isNotEmpty) names.add(n.trim());
          } else if (a is String && a.trim().isNotEmpty) {
            names.add(a.trim());
          }
        }
        artist = names.join(', ');
      }
      if (artist.isEmpty) artist = 'Unknown Artist';
      final String? artworkUrl = _asString(item['artwork_url']) ??
          _asString(item['artworkUrl']) ??
          _asString(item['thumbnail']);
      final int durationMs = (item['duration_ms'] as num?)?.toInt() ??
          (item['durationMs'] as num?)?.toInt() ??
          210000;
      final bool isMock = item['is_mock'] == true;
      final String albumTitle = _asString(item['album']) ?? 'Single';

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
          title: albumTitle,
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
          'language': _asString(item['language']) ?? '',
          'year': _asString(item['year']) ?? '',
        },
      );
    }).toList();

    return CatalogSection(
      id: _asString(json['id']) ?? '',
      key: _asString(json['key']) ?? '',
      sourceUrl: _asString(json['source_url']) ?? '',
      sourceType: _asString(json['source_type']) ?? 'playlist',
      sourceId: _asString(json['source_id']) ?? '',
      slug: _asString(json['slug']) ?? '',
      displayTitle: _asString(json['display_title']) ?? 'Untitled Section',
      displayGroup: _asString(json['display_group']) ?? 'Featured',
      displayMode: () {
        final String raw =
            (_asString(json['display_mode']) ?? '').trim().toLowerCase();
        if (raw == 'tracks' || raw == 'songs' || raw == 'song') {
          return 'tracks';
        }
        final String st =
            (_asString(json['source_type']) ?? '').trim().toLowerCase();
        // Treat song/track as tracks shelf; ignore bogus "None"/null strings from API.
        if (st == 'song' || st == 'track') {
          return 'tracks';
        }
        return 'entity';
      }(),
      subtitle: _asString(json['subtitle']),
      language: _asString(json['language']) ?? 'all',
      position: (json['position'] as num?)?.toInt() ?? 1,
      isEnabled: json['is_enabled'] != false,
      customArtworkUrl: _asString(json['custom_artwork_url']) ??
          _asString(json['artwork_url']),
      isBanner: json['is_banner'] == true,
      campaignStart: () {
        final int v = _asUnixSeconds(json['campaign_start']);
        return v > 0 ? v : null;
      }(),
      campaignEnd: () {
        final int v = _asUnixSeconds(json['campaign_end']);
        return v > 0 ? v : null;
      }(),
      providerStatus: _asString(json['provider_status']) ?? 'ok',
      lastRefresh: _asUnixSeconds(json['last_refresh']),
      updatedAt: _asUnixSeconds(json['updated_at']),
      lastError: _asString(json['last_error']),
      isMock: json['is_mock'] == true,
      // Prefer live parsed tracks. If the payload was thin/filtered but the API
      // still reports a positive count (common for album shelves), keep that
      // count so admin does not flash "0 tracks" after a cache heal.
      itemCount: () {
        final int apiCount = (json['item_count'] as num?)?.toInt() ?? 0;
        if (parsedItems.isNotEmpty) return parsedItems.length;
        if (apiCount > 0) return apiCount;
        return 0;
      }(),
      items: parsedItems,
      excludedTrackIds: ((json['excluded_track_ids'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      contentHash: _asString(json['content_hash']),
      contentVersion: (json['content_version'] as num?)?.toInt(),
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
      if (contentHash != null) 'content_hash': contentHash,
      if (contentVersion != null) 'content_version': contentVersion,
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
    String? contentHash,
    int? contentVersion,
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
      contentHash: contentHash ?? this.contentHash,
      contentVersion: contentVersion ?? this.contentVersion,
    );
  }
}
