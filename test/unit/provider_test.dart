import 'package:flutter_test/flutter_test.dart';
import 'package:echo_flow_music/core/cache/cache_store.dart';
import 'package:echo_flow_music/core/network/api_client.dart';
import 'package:echo_flow_music/domain/models/audio_quality.dart';
import 'package:echo_flow_music/domain/models/track.dart';
import 'package:echo_flow_music/domain/providers/demo_provider.dart';
import 'package:echo_flow_music/domain/providers/licensed_provider_stub.dart';

void main() {
  group('AudioQuality data estimate', () {
    test('320 kbps ~ 137 MB/hour', () {
      expect(AudioQuality.veryHigh.estimatedMbPerHour!.round(), 137);
    });
    test('auto has no fixed estimate', () {
      expect(AudioQuality.auto.estimatedMbPerHour, isNull);
    });
  });

  group('DemoProvider', () {
    late DemoProvider p;
    setUp(() {
      p = DemoProvider(api: ApiClient(), cache: CacheStore());
    });

    test('is always available (zero-config playback)', () async {
      expect(await p.isAvailable(), isTrue);
    });

    test('searches its catalogue', () async {
      final r = await p.search('Neon');
      expect(r.tracks, isNotEmpty);
    });

    test('returns a playable stream', () async {
      final Track tr = await p.getTrack('demo:track:1');
      final s = await p.getStream(tr);
      expect(s.url, contains('http'));
      expect(s.bitrateKbps, isNotNull);
    });

    test('trending paginates', () async {
      final page = await p.getTrending(limit: 5);
      expect(page.items.length, lessThanOrEqualTo(5));
      expect(page.hasMore, isTrue);
    });
  });

  group('LicensedProviderStub', () {
    test('reports unavailable and refuses to fabricate data', () async {
      final p = LicensedProviderStub(api: ApiClient(), cache: CacheStore());
      expect(await p.isAvailable(), isFalse);
    });
  });
}
