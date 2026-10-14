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
  final String? subtitle;
  final String language;
  final int position;
  final bool isEnabled;
  final String providerStatus;
  final int lastRefresh;
  final String? lastError;
  final String? customArtworkUrl;
  final bool isBanner;
  final int? campaignStart;
  final int? campaignEnd;
  final bool isMock;
  final int itemCount;
  final List<Track> items;

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
    this.lastError,
    required this.isMock,
    required this.itemCount,
    required this.items,
  });

  factory CatalogSection.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = (json['items'] as List<dynamic>?) ?? <dynamic>[];
    final List<Track> parsedItems = rawItems.map((dynamic item) {
      if (item is! Map<String, dynamic>) {
        return Track(
          id: 'custom_api:track:unknown',
          providerId: 'custom_api',
          providerTrackId: 'unknown',
          title: 'Unknown Track',
          artists: const <Artist>[],
          duration: Duration.zero,
          explicit: false,
          mediaType: MediaType.audio,
          isStreamable: false,
          isDownloadable: false,
          hasLyrics: false,
          qualityOptions: const <AudioQuality>[],
          commercialUseAllowed: false,
          backgroundPlaybackAllowed: true,
          license: 'Mock',
          attributionRequired: false,
        );
      }
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
      subtitle: json['subtitle'] as String?,
      language: json['language'] as String? ?? 'all',
      position: (json['position'] as num?)?.toInt() ?? 1,
      isEnabled: json['is_enabled'] != false,
      customArtworkUrl: json['custom_artwork_url'] as String? ?? json['artwork_url'] as String?,
      isBanner: json['is_banner'] == true,
      campaignStart: (json['campaign_start'] as num?)?.toInt(),
      campaignEnd: (json['campaign_end'] as num?)?.toInt(),
      providerStatus: json['provider_status'] as String? ?? 'ok',
      lastRefresh: (json['last_refresh'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
      isMock: json['is_mock'] == true,
      itemCount: (json['item_count'] as num?)?.toInt() ?? parsedItems.length,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'key': key,
      'source_url': sourceUrl,
      'source_type': sourceType,
      'source_id': sourceId,
      'slug': slug,
      'display_title': displayTitle,
      'display_group': displayGroup,
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
      'last_error': lastError,
      'is_mock': isMock,
      'item_count': itemCount,
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
    String? lastError,
    bool? isMock,
    int? itemCount,
    List<Track>? items,
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
      lastError: lastError ?? this.lastError,
      isMock: isMock ?? this.isMock,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
    );
  }
}
