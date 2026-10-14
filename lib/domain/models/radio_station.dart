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
  final bool isLive;

  const RadioStation({
    required this.id,
    required this.name,
    required this.tagline,
    required this.frequency,
    required this.state,
    required this.streamUrl,
    required this.artworkUrl,
    this.category = 'National',
    this.isLive = true,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Radio Station',
      tagline: json['tagline'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'FM Live',
      state: json['state'] as String? ?? 'India',
      streamUrl: json['stream_url'] as String? ?? '',
      artworkUrl: json['artwork_url'] as String? ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: json['category'] as String? ?? 'National',
      isLive: json['is_live'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'tagline': tagline,
      'frequency': frequency,
      'state': state,
      'stream_url': streamUrl,
      'artwork_url': artworkUrl,
      'category': category,
      'is_live': isLive,
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

  /// Official verified live Indian radio stations list (Akashvani & curated live Indian FM)
  static const List<RadioStation> stations = <RadioStation>[
    RadioStation(
      id: 'air_vividh_bharati',
      name: 'AIR Vividh Bharati',
      tagline: 'Classic Hindi Songs & Golden Era Melodies',
      frequency: '102.8 FM',
      state: 'Mumbai / National',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: 'AIR National',
    ),
    RadioStation(
      id: 'air_fm_gold',
      name: 'AIR FM Gold Delhi',
      tagline: 'Retro Bollywood, News & Melodious Classics',
      frequency: '106.4 FM',
      state: 'Delhi / National',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio005/hlspbaudio00564kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      category: 'AIR National',
    ),
    RadioStation(
      id: 'air_fm_rainbow_mumbai',
      name: 'AIR FM Rainbow Mumbai',
      tagline: 'Mumbai 107.1 FM live melodies and youth programming',
      frequency: '107.1 FM',
      state: 'Mumbai / Western',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio002/hlspbaudio00264kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
      category: 'AIR Regional',
    ),
    RadioStation(
      id: 'air_marathi_asmita',
      name: 'Akashvani Mumbai Asmita',
      tagline: 'Prasar Bharati Marathi broadcasts, Natyasangeet & Bhavgeete',
      frequency: '100.1 FM',
      state: 'Maharashtra',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio024/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      category: 'AIR Regional',
    ),
    RadioStation(
      id: 'air_pune',
      name: 'Akashvani Pune',
      tagline: 'Akashvani Pune Marathi programming, news & classical recitals',
      frequency: '101.0 FM',
      state: 'Pune / Maharashtra',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio025/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
      category: 'AIR Regional',
    ),
    RadioStation(
      id: 'air_nagpur',
      name: 'Akashvani Nagpur',
      tagline: 'Vidarbha regional broadcasts, Marathi folk & news',
      frequency: '102.2 FM',
      state: 'Nagpur / Vidarbha',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio026/hlspbaudio02664kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      category: 'AIR Regional',
    ),
    RadioStation(
      id: 'hindi_gold_classics',
      name: 'Radio City Hindi Classics',
      tagline: 'Evergreen 60s, 70s, 80s & 90s Golden Melodies',
      frequency: 'Online 24/7',
      state: 'National',
      streamUrl: 'https://cast1.asurahosting.com/proxy/radiocity/stream',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      category: 'Retro Melodies',
    ),
    RadioStation(
      id: 'vividh_bharati_retro',
      name: 'Vividh Bharati Retro',
      tagline: 'Non-stop Kishore Kumar, Lata Mangeshkar, and R.D. Burman gems',
      frequency: 'Web HD 24/7',
      state: 'National',
      streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      category: 'Retro Melodies',
    ),
    RadioStation(
      id: 'bhakti_sagar_divine',
      name: 'Akashvani Bhakti Sagar',
      tagline: 'Divine morning Bhajans, sacred mantras, Aarti & Hanuman Chalisa',
      frequency: 'Devotional 24/7',
      state: 'National',
      streamUrl: 'https://stream.zeno.fm/m9w6q1k5y1zuv',
      artworkUrl: 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
      category: 'Devotional',
    ),
    RadioStation(
      id: 'marathi_sangeet_live',
      name: 'Radio Marathi Sangeet',
      tagline: 'Marathi Bhavgeete, Lavani, Natyasangeet & evergreen classics',
      frequency: 'Regional 24/7',
      state: 'Maharashtra',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      category: 'Regional',
    ),
  ];
}
