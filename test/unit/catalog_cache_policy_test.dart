import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/core/catalog/catalog_cache_policy.dart';
import 'package:kalpkrut_beats/domain/models/catalog_section.dart';
import 'package:kalpkrut_beats/domain/models/track.dart';
import 'package:kalpkrut_beats/domain/models/artist.dart';
import 'package:kalpkrut_beats/domain/models/album.dart';
import 'package:kalpkrut_beats/domain/models/media_type.dart';
import 'package:kalpkrut_beats/domain/models/audio_quality.dart';

Track _track(String id) => Track(
      id: 'custom_api:track:$id',
      providerId: 'custom_api',
      providerTrackId: id,
      title: 'Song $id',
      artists: <Artist>[
        Artist(
          id: 'a1',
          providerId: 'custom_api',
          providerArtistId: 'a1',
          name: 'Artist',
        ),
      ],
      album: Album(
        id: 'al1',
        providerId: 'custom_api',
        providerAlbumId: 'al1',
        title: 'Album',
      ),
      duration: const Duration(seconds: 200),
      artworkUrl: null,
      explicit: false,
      mediaType: MediaType.audio,
      isStreamable: true,
      isDownloadable: false,
      hasLyrics: false,
      qualityOptions: const <AudioQuality>[AudioQuality.high],
      commercialUseAllowed: false,
      backgroundPlaybackAllowed: true,
      license: 'test',
      attributionRequired: false,
    );

CatalogSection _section({
  required String key,
  List<Track> items = const <Track>[],
  String status = 'ok',
  String url = 'https://www.jiosaavn.com/featured/x/abc__',
  bool isMock = false,
}) {
  return CatalogSection(
    id: 'id_$key',
    key: key,
    sourceUrl: url,
    sourceType: 'playlist',
    sourceId: key,
    slug: key,
    displayTitle: key,
    displayGroup: 'Test',
    language: 'hindi',
    position: 1,
    isEnabled: true,
    providerStatus: status,
    lastRefresh: 0,
    isMock: isMock,
    itemCount: items.length,
    items: items,
  );
}

void main() {
  group('catalogTrackCacheLooksHealthy (R8)', () {
    test('rejects empty and metadata-only catalogues', () {
      expect(catalogTrackCacheLooksHealthy(<CatalogSection>[]), isFalse);
      final List<CatalogSection> metaOnly = List<CatalogSection>.generate(
        10,
        (int i) => _section(key: 's$i'),
      );
      expect(catalogTrackCacheLooksHealthy(metaOnly), isFalse);
    });

    test('accepts catalogues with enough filled shelves', () {
      final List<CatalogSection> mixed = <CatalogSection>[
        _section(key: 'a', items: <Track>[_track('1')]),
        _section(key: 'b', items: <Track>[_track('2')]),
        _section(key: 'c'),
        _section(key: 'd'),
        _section(key: 'e'),
      ];
      expect(catalogTrackCacheLooksHealthy(mixed), isTrue);
    });
  });

  group('mergeCatalogSectionTracks (R8)', () {
    test('preserves prior tracks when fresh is empty/unavailable', () {
      final CatalogSection cached = _section(
        key: 'mix',
        items: <Track>[_track('live1'), _track('live2')],
      );
      final CatalogSection fresh = _section(
        key: 'mix',
        status: 'unavailable',
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items.length, 2);
      expect(merged.items.first.providerTrackId, 'live1');
      expect(merged.isMock, isFalse);
    });

    test('does not keep tracks when source URL changed', () {
      final CatalogSection cached = _section(
        key: 'mix',
        items: <Track>[_track('old')],
        url: 'https://www.jiosaavn.com/featured/old/aaa__',
      );
      final CatalogSection fresh = _section(
        key: 'mix',
        url: 'https://www.jiosaavn.com/featured/new/bbb__',
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items, isEmpty);
    });
  });
}
