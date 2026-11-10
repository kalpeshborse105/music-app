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
  String sourceType = 'playlist',
  bool isMock = false,
}) {
  return CatalogSection(
    id: 'id_$key',
    key: key,
    sourceUrl: url,
    sourceType: sourceType,
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

  group('mergeCatalogSectionTracks (R8 + Mix trust)', () {
    test('unresolved_mix does not restore old disk Mix tracks', () {
      final CatalogSection cached = _section(
        key: 'late_night_mix',
        sourceType: 'mix',
        items: <Track>[_track('trend1'), _track('trend2')],
        url: 'https://www.jiosaavn.com/s/mix/late_night_mix/tokA',
      );
      final CatalogSection fresh = _section(
        key: 'late_night_mix',
        sourceType: 'mix',
        status: 'unresolved_mix',
        url: 'https://www.jiosaavn.com/s/mix/late_night_mix/tokA',
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items, isEmpty);
      expect(merged.providerStatus, 'unresolved_mix');
    });

    test('unavailable does not restore old disk Mix tracks', () {
      final CatalogSection cached = _section(
        key: 'daily_mix_1',
        sourceType: 'mix',
        items: <Track>[_track('old1')],
      );
      final CatalogSection fresh = _section(
        key: 'daily_mix_1',
        sourceType: 'mix',
        status: 'unavailable',
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items, isEmpty);
      expect(merged.providerStatus, 'unavailable');
    });

    test('error does not restore old disk Mix tracks', () {
      final CatalogSection cached = _section(
        key: 'early_morning_mix',
        sourceType: 'mix',
        items: <Track>[_track('old1')],
      );
      final CatalogSection fresh = _section(
        key: 'early_morning_mix',
        sourceType: 'mix',
        status: 'error',
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items, isEmpty);
      expect(merged.providerStatus, 'error');
    });

    test('trusted stale Mix keeps stale tracks from API payload', () {
      final CatalogSection cached = _section(
        key: 'my_favorites_mix',
        sourceType: 'mix',
        items: <Track>[_track('disk_old')],
      );
      final CatalogSection fresh = _section(
        key: 'my_favorites_mix',
        sourceType: 'mix',
        status: 'stale',
        items: <Track>[_track('stale1'), _track('stale2')],
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items.map((Track t) => t.providerTrackId).toList(),
          <String>['stale1', 'stale2']);
      expect(merged.providerStatus, 'stale');
    });

    test('healthy Mix uses fresh tracks', () {
      final CatalogSection cached = _section(
        key: 'hindi_drivetime_mix',
        sourceType: 'mix',
        items: <Track>[_track('old')],
      );
      final CatalogSection fresh = _section(
        key: 'hindi_drivetime_mix',
        sourceType: 'mix',
        status: 'ok',
        items: <Track>[_track('new1'), _track('new2')],
      );
      final CatalogSection merged =
          mergeCatalogSectionTracks(fresh: fresh, cached: cached);
      expect(merged.items.map((Track t) => t.providerTrackId).toList(),
          <String>['new1', 'new2']);
      expect(merged.providerStatus, 'ok');
    });

    test('normal playlist empty ok still restores prior disk tracks', () {
      final CatalogSection cached = _section(
        key: 'featured_hits',
        sourceType: 'playlist',
        items: <Track>[_track('live1'), _track('live2')],
      );
      final CatalogSection fresh = _section(
        key: 'featured_hits',
        sourceType: 'playlist',
        status: 'ok',
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
