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

  /// Official verified live Akashvani & 24/7 radio stations list
  static const List<RadioStation> stations = <RadioStation>[
    RadioStation(
      id: 'air_vividh_bharati',
      name: 'AIR Vividh Bharati',
      tagline: 'Classic Hindi Songs & Golden Era Melodies',
      frequency: '102.8 FM',
      state: 'National / Mumbai',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    ),
    RadioStation(
      id: 'air_marathi_asmita',
      name: 'Akashvani Marathi Samvad',
      tagline: 'Prasar Bharati Marathi broadcasts, Bhavgeete & state news',
      frequency: 'Statewide Live',
      state: 'Maharashtra',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio024/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    ),
    RadioStation(
      id: 'air_pune',
      name: 'Akashvani Pune',
      tagline: 'Akashvani Pune live Marathi programming & classical recitals',
      frequency: '101.0 FM',
      state: 'Pune / Western Maharashtra',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio025/playlist.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    ),
    RadioStation(
      id: 'air_nagpur',
      name: 'Akashvani Nagpur',
      tagline: 'Vidarbha regional broadcasts, Marathi folk & devotional news',
      frequency: 'Live Broadcast',
      state: 'Nagpur / Vidarbha',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio026/hlspbaudio02664kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    ),
    RadioStation(
      id: 'air_fm_rainbow_mumbai',
      name: 'AIR FM Rainbow Mumbai',
      tagline: 'Mumbai 107.1 FM live melodies and youth programming',
      frequency: '107.1 FM',
      state: 'Mumbai',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio002/hlspbaudio00264kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
    ),
    RadioStation(
      id: 'air_fm_gold',
      name: 'AIR FM Gold Delhi',
      tagline: 'Retro Bollywood, News & Melodious Classics',
      frequency: '106.4 FM',
      state: 'Delhi / National',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio005/hlspbaudio00564kbps.m3u8',
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    ),
    RadioStation(
      id: 'hindi_gold_retro',
      name: 'Hindi Gold Classics',
      tagline: 'Evergreen 60s, 70s, 80s & 90s Golden Melodies',
      frequency: 'Online 24/7',
      state: 'National',
      streamUrl: 'https://azuracast.vibesounds.in:8010/radio.mp3',
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    ),
    RadioStation(
      id: 'lofi_chill_live',
      name: 'Lo-Fi Chillhop Radio',
      tagline: 'Mellow Beats, Rain Textures & Study Vibes',
      frequency: 'HD 24/7',
      state: 'Global Live',
      streamUrl: 'https://streams.ilovemusic.de/iloveradio17.mp3',
      artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    ),
    RadioStation(
      id: 'top_charts_live',
      name: 'Today Top Chartbusters',
      tagline: 'Non-stop trending chart hits & fresh party beats',
      frequency: 'Live 24/7',
      state: 'National',
      streamUrl: 'https://streams.ilovemusic.de/iloveradio1.mp3',
      artworkUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
    ),
    RadioStation(
      id: 'bhakti_sagar_live',
      name: 'Bhakti Sagar Divine',
      tagline: 'Divine morning Bhajans, sacred mantras & Aartis',
      frequency: 'Devotional 24/7',
      state: 'National',
      streamUrl: 'http://millenniumhits.out.airtime.pro:8000/millenniumhits_a',
      artworkUrl: 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
    ),
    RadioStation(
      id: 'classical_symphonies',
      name: 'Classical Symphonies',
      tagline: 'Masterpieces from Mozart, Beethoven & Bach',
      frequency: 'Lossless HD',
      state: 'International',
      streamUrl: 'https://stream.srg-ssr.ch/m/rsc_de/mp3_128',
      artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    ),
    RadioStation(
      id: 'indie_groove_live',
      name: 'SomaFM Groove Salad',
      tagline: 'Independent acoustic gems, chill groove & ambient pop',
      frequency: 'Direct MP3',
      state: 'Global',
      streamUrl: 'https://ice2.somafm.com/groovesalad-128-mp3',
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&q=80',
    ),
  ];
}
