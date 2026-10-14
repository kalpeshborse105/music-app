import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/domain/models/catalog_section.dart';
import 'package:kalpkrut_beats/domain/models/track.dart';

void main() {
  group('CatalogSection Domain Model & Local Admin Suite', () {
    test('CatalogSection deserializes and serializes with decoupled sourceType and displayGroup', () {
      final Map<String, dynamic> sampleJson = <String, dynamic>{
        'id': 'catalog_hindi_top_50',
        'key': 'hindi_top_50',
        'source_url': 'https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__',
        'source_type': 'playlist',
        'source_id': 'zlJfJYVuyjpxWb5,FqsjKg__',
        'slug': 'hindi-india-superhits-top-50',
        'display_title': 'Hindi India Superhits Top 50',
        'display_group': 'Top Charts',
        'language': 'hindi',
        'position': 1,
        'is_enabled': true,
        'provider_status': 'ok [mock]',
        'last_refresh': 1760000000,
        'last_error': null,
        'is_mock': true,
        'item_count': 1,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'custom_api:track:mock_track_1',
            'providerId': 'custom_api',
            'providerTrackId': 'mock_track_1',
            'title': '[MOCK] Raataan Lambiyan',
            'artists': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'custom_api:artist:jubin',
                'providerId': 'custom_api',
                'providerArtistId': 'jubin',
                'name': 'Jubin Nautiyal',
              }
            ],
            'durationMs': 230000,
            'isStreamable': true,
          }
        ],
      };

      final CatalogSection section = CatalogSection.fromJson(sampleJson);

      expect(section.key, equals('hindi_top_50'));
      expect(section.sectionKey, equals('hindi_top_50'));
      expect(section.sourceType, equals('playlist'));
      expect(section.displayGroup, equals('Top Charts'));
      // Verify independence: source_type is playlist while display_group is Top Charts
      expect(section.sourceType != section.displayGroup, isTrue);
      expect(section.isEnabled, isTrue);
      expect(section.isMock, isTrue);
      expect(section.items.length, equals(1));
      expect(section.items.first.title, contains('[MOCK]'));

      final Map<String, dynamic> exported = section.toJson();
      expect(exported['key'], equals('hindi_top_50'));
      expect(exported['source_type'], equals('playlist'));
      expect(exported['display_group'], equals('Top Charts'));
    });

    test('CatalogSection copyWith correctly overrides title, position and enabled state', () {
      const CatalogSection original = CatalogSection(
        id: 'sec_1',
        key: 'salman_khan',
        sourceUrl: 'https://www.jiosaavn.com/artist/salman-khan-songs/uuAKJcbNOKg_',
        sourceType: 'artist',
        sourceId: 'uuAKJcbNOKg_',
        slug: 'salman-khan-songs',
        displayTitle: 'Salman Khan',
        displayGroup: 'Featured Artists',
        language: 'all',
        position: 1,
        isEnabled: true,
        providerStatus: 'ok [mock]',
        lastRefresh: 0,
        isMock: true,
        itemCount: 0,
        items: <Track>[],
      );

      final CatalogSection updated = original.copyWith(
        displayTitle: 'Salman Khan Mega Hits',
        position: 5,
        isEnabled: false,
      );

      expect(updated.displayTitle, equals('Salman Khan Mega Hits'));
      expect(updated.position, equals(5));
      expect(updated.isEnabled, isFalse);
      expect(updated.sourceType, equals('artist')); // Unchanged
    });

    test('Track.fromJson safely handles string album ("Brahmastra") and string artist without TypeError', () {
      final Map<String, dynamic> rawTrack = <String, dynamic>{
        'id': 'mock_pl_zlJfJYVu_1',
        'title': 'Kesariya',
        'artist': 'Arijit Singh, Pritam',
        'album': 'Brahmastra',
        'duration_ms': 268000,
        'artwork_url': 'https://c.saavncdn.com/kesariya.jpg',
        'is_mock': false,
      };

      final Track track = Track.fromJson(rawTrack);

      expect(track.title, equals('Kesariya'));
      expect(track.album, isNotNull);
      expect(track.album!.title, equals('Brahmastra'));
      expect(track.artists.isNotEmpty, isTrue);
      expect(track.artists.first.name, equals('Arijit Singh, Pritam'));
      expect(track.duration.inMilliseconds, equals(268000));
      expect(track.artworkUrl, equals('https://c.saavncdn.com/kesariya.jpg'));
    });
  });
}
