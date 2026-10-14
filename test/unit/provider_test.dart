import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/core/cache/cache_store.dart';
import 'package:kalpkrut_beats/core/network/api_client.dart';
import 'package:kalpkrut_beats/domain/models/audio_quality.dart';
import 'package:kalpkrut_beats/domain/providers/licensed_provider_stub.dart';

void main() {
  group('AudioQuality data estimate', () {
    test('320 kbps ~ 137 MB/hour', () {
      expect(AudioQuality.veryHigh.estimatedMbPerHour!.round(), 137);
    });
    test('auto has no fixed estimate', () {
      expect(AudioQuality.auto.estimatedMbPerHour, isNull);
    });
  });



  group('LicensedProviderStub', () {
    test('reports unavailable and refuses to fabricate data', () async {
      final p = LicensedProviderStub(api: ApiClient(), cache: CacheStore());
      expect(await p.isAvailable(), isFalse);
    });
  });
}
