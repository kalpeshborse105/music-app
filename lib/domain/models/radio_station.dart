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

  const RadioStation({
    required this.id,
    required this.name,
    required this.tagline,
    required this.frequency,
    required this.state,
    required this.streamUrl,
    required this.artworkUrl,
  });

  /// Converts this radio station into a standard Kalpkrut Beats [Track] for the audio engine.
  Track toTrack() {
    return Track(
      id: 'radio:$id',
      providerId: 'radio',
      providerTrackId: streamUrl,
      title: name,
      artists: <Artist>[
        Artist(
          id: 'radio:akashvani',
          providerId: 'radio',
          providerArtistId: 'akashvani',
          name: 'Akashvani • All India Radio',
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

  /// Official public Akashvani stations list
  static const List<RadioStation> stations = <RadioStation>[
    RadioStation(
      id: 'air_vividh_bharati',
      name: 'AIR Vividh Bharati',
      tagline: 'Classic Hindi Songs & Golden Era Melodies',
      frequency: '102.8 FM',
      state: 'National / Mumbai',
      streamUrl: 'https://stream.zeno.fm/4w884n2w2h8uv',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    ),
    RadioStation(
      id: 'air_fm_gold',
      name: 'AIR FM Gold',
      tagline: 'Retro Bollywood, News & Melodious Classics',
      frequency: '106.4 FM',
      state: 'Delhi / National',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio002/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    ),
    RadioStation(
      id: 'air_fm_rainbow',
      name: 'AIR FM Rainbow',
      tagline: 'Contemporary Hits, Pop, Indie & Youth Culture',
      frequency: '102.6 FM',
      state: 'National',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio003/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
    ),
    RadioStation(
      id: 'air_marathi',
      name: 'Akashvani Mumbai Asmita',
      tagline: 'Bhavgeet, Natyageet & Marathi Folk Classics',
      frequency: '558 kHz AM',
      state: 'Maharashtra',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio028/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&q=80',
    ),
    RadioStation(
      id: 'air_gujarati',
      name: 'Akashvani Ahmedabad',
      tagline: 'Sugam Sangeet, Garba & Gujarati Melodies',
      frequency: '846 kHz AM',
      state: 'Gujarat',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio047/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    ),
    RadioStation(
      id: 'air_urdu',
      name: 'Akashvani Urdu Service',
      tagline: 'Soulful Ghazals, Nazms & Cultural Broadcasts',
      frequency: 'National SW',
      state: 'National',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio007/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    ),
    RadioStation(
      id: 'air_bangla',
      name: 'Akashvani Kolkata Geetanjali',
      tagline: 'Rabindra Sangeet, Nazrul Geeti & Bengali Classics',
      frequency: '100.1 FM',
      state: 'West Bengal',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio054/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
    ),
    RadioStation(
      id: 'air_tamil',
      name: 'Akashvani Chennai Rainbow',
      tagline: 'Carnatic Treasures & Tamil Cinema Hits',
      frequency: '101.4 FM',
      state: 'Tamil Nadu',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio075/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500&q=80',
    ),
  ];
}
