import 'album.dart';
import 'artist.dart';
import 'audio_quality.dart';
import 'media_type.dart';
import 'track.dart';

/// Akashvani / All India Radio live broadcast station model.
class RadioStation {
  final String id;
  final String name;
  final String tagline;
  final String frequency;
  final String state;
  final String streamUrl;
  final String artworkUrl;
  final String category;
  final String language;
  final List<String> languages;
  final String tier;
  final String district;
  final bool isLive;
  final bool verified;

  const RadioStation({
    required this.id,
    required this.name,
    required this.tagline,
    required this.frequency,
    required this.state,
    required this.streamUrl,
    required this.artworkUrl,
    this.category = 'National',
    this.language = 'hindi',
    this.languages = const <String>['hindi'],
    this.tier = 'government',
    this.district = '',
    this.isLive = true,
    this.verified = true,
  });

  bool get isPrivate => tier == 'private';

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final List<String> langs = <String>[];
    final dynamic rawLangs = json['languages'];
    if (rawLangs is List) {
      for (final dynamic item in rawLangs) {
        final String value = '$item'.trim().toLowerCase();
        if (value.isNotEmpty) langs.add(value);
      }
    }
    final String primary = (json['language'] as String?)?.trim().toLowerCase() ??
        (langs.isNotEmpty ? langs.first : 'hindi');
    if (langs.isEmpty) langs.add(primary);

    final String category = json['category'] as String? ?? 'National';
    final String rawTier = (json['tier'] as String?)?.trim().toLowerCase() ?? '';
    final String catLower = category.toLowerCase();
    final String tier = (rawTier == 'private' || rawTier == 'government')
        ? rawTier
        : (catLower.contains('private') ||
                catLower.contains('popular') ||
                catLower.contains('mirchi')
            ? 'private'
            : 'government');

    return RadioStation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Radio Station',
      tagline: json['tagline'] as String? ?? json['description'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'AIR Live',
      state: json['state'] as String? ?? 'India',
      streamUrl: json['stream_url'] as String? ?? '',
      artworkUrl: json['artwork_url'] as String? ??
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: category,
      language: primary,
      languages: langs,
      tier: tier,
      district: json['district'] as String? ?? '',
      isLive: json['is_live'] as bool? ?? true,
      verified: json['verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'tagline': tagline,
      'frequency': frequency,
      'state': state,
      'district': district,
      'stream_url': streamUrl,
      'artwork_url': artworkUrl,
      'category': category,
      'language': language,
      'languages': languages,
      'tier': tier,
      'is_live': isLive,
      'verified': verified,
    };
  }

  /// Converts this radio station into a standard Kalpkrut Beats [Track] for the audio engine.
  Track toTrack() {
    return Track(
      id: 'radio:$id',
      providerId: 'radio',
      providerTrackId: streamUrl,
      title: name,
      artists: <Artist>[
        Artist(
          id: 'radio:station:$id',
          providerId: 'radio',
          providerArtistId: id,
          name: '$frequency • $state',
        ),
      ],
      album: Album(
        id: 'radio:album:$id',
        providerId: 'radio',
        providerAlbumId: id,
        title: '$frequency • $state',
        artworkUrl: artworkUrl,
      ),
      duration: Duration.zero,
      artworkUrl: artworkUrl,
      explicit: false,
      mediaType: MediaType.audio,
      isStreamable: true,
      isDownloadable: false,
      hasLyrics: false,
      qualityOptions: const <AudioQuality>[AudioQuality.high],
      commercialUseAllowed: false,
      backgroundPlaybackAllowed: true,
      license: 'Public Service Broadcast',
      attributionRequired: true,
    );
  }

  /// Offline fallback — verified AIR streams only (API is source of truth).
  static const List<RadioStation> stations = <RadioStation>[
    RadioStation(
      id: 'hindi_gold_classics',
      name: 'Hindi Gold Classics',
      tagline: 'Evergreen Bollywood classics 24/7',
      frequency: 'Online',
      state: 'Maharashtra',
      district: 'Mumbai',
      streamUrl: 'https://azuracast.vibesounds.in:8010/radio.mp3',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: 'Private Popular',
      language: 'hindi',
      tier: 'private',
    ),
    RadioStation(
      id: 'vividh_bharati',
      name: 'Vividh Bharati',
      tagline: 'Classic Hindi songs & golden-era melodies',
      frequency: 'AIR Live',
      state: 'National',
      streamUrl: 'https://radio.wavespb.com/live/146ed6ec6dea5a24/146ed6ec6dea5a24.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: 'Akashvani AIR',
      language: 'hindi',
      tier: 'government',
    ),
    RadioStation(
      id: 'akashvani_dhule',
      name: 'Akashvani Dhule',
      tagline: 'Akashvani live • Marathi, Hindi',
      frequency: 'AIR Live',
      state: 'Maharashtra',
      district: 'Dhule',
      streamUrl: 'https://radio.wavespb.com/live/c0040b54233d76a1/c0040b54233d76a1.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      category: 'Akashvani AIR',
      language: 'marathi',
      languages: <String>['marathi', 'hindi', 'english'],
      tier: 'government',
    ),
  ];
}
