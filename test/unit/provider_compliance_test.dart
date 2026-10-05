import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/core/cache/cache_store.dart';
import 'package:kalpkrut_beats/core/network/api_client.dart';
import 'package:kalpkrut_beats/data/provider_registry.dart';
import 'package:kalpkrut_beats/domain/models/provider_status.dart';
import 'package:kalpkrut_beats/domain/models/track.dart';
import 'package:kalpkrut_beats/domain/providers/audius_provider.dart';
import 'package:kalpkrut_beats/domain/providers/jamendo_provider.dart';
import 'package:kalpkrut_beats/domain/providers/regional_music_provider.dart';

void main() {
  group('Provider Compliance & Lifecycle Model', () {
    test(
      'Track model exposes all required compliance getters and metadata',
      () {
        const Track track = Track(
          id: 'audius:track:AVxVZV3',
          providerId: 'audius',
          providerTrackId: 'AVxVZV3',
          title: 'Deep Focus Pulse',
          isStreamable: true,
          isDownloadable: false,
          commercialUseAllowed: false,
          backgroundPlaybackAllowed: true,
          license: 'Audius Protocol Streaming',
          licenseUrl: 'https://audius.co',
          attributionRequired: true,
        );

        // Verify compliance getters
        expect(track.provider, equals('audius'));
        expect(track.streamAllowed, isTrue);
        expect(track.downloadAllowed, isFalse);
        expect(track.commercialUseAllowed, isFalse);
        expect(track.backgroundPlaybackAllowed, isTrue);
        expect(track.license, equals('Audius Protocol Streaming'));
        expect(track.licenseUrl, equals('https://audius.co'));
        expect(track.attributionRequired, isTrue);

        // Verify serialization round-trip
        final Map<String, dynamic> json = track.toJson();
        expect(json['commercialUseAllowed'], isFalse);
        expect(json['backgroundPlaybackAllowed'], isTrue);
        expect(json['license'], equals('Audius Protocol Streaming'));

        final Track restored = Track.fromJson(json);
        expect(restored.commercialUseAllowed, isFalse);
        expect(restored.backgroundPlaybackAllowed, isTrue);
        expect(restored.license, equals('Audius Protocol Streaming'));
        expect(restored.attributionRequired, isTrue);
      },
    );

    test(
      'Official AudiusProvider is ACTIVE and enforces compliance contracts',
      () {
        final AudiusProvider provider = AudiusProvider(
          api: ApiClient(),
          cache: CacheStore(),
        );

        expect(provider.id, equals('audius'));
        expect(provider.status, equals(ProviderStatus.active));
        expect(provider.status.isProductionActive, isTrue);
        expect(provider.capabilities.streaming, isTrue);
        expect(provider.capabilities.downloading, isFalse);
        expect(provider.capabilities.backgroundPlayback, isTrue);
      },
    );

    test(
      'JamendoProvider is ACTIVE and retains Creative Commons attribution',
      () {
        final JamendoProvider provider = JamendoProvider(
          api: ApiClient(),
          cache: CacheStore(),
        );

        expect(provider.id, equals('jamendo'));
        expect(provider.status, equals(ProviderStatus.active));
        expect(provider.status.isProductionActive, isTrue);
      },
    );

    test(
      'RegionalMusicProvider is LICENSE_PENDING and never fabricates tracks',
      () async {
        final RegionalMusicProvider provider = RegionalMusicProvider(
          api: ApiClient(),
          cache: CacheStore(),
        );

        expect(provider.id, equals('regional_indian'));
        expect(provider.status, equals(ProviderStatus.licensePending));
        expect(provider.status.isProductionActive, isFalse);

        // Must be unavailable until signed commercial partner license is configured
        final bool available = await provider.isAvailable();
        expect(available, isFalse);

        // Must support future Indian languages
        final List<RegionalLanguage> languages = provider.supportedLanguages;
        expect(
          languages.map((RegionalLanguage l) => l.displayName),
          containsAll(<String>[
            'Hindi',
            'Marathi',
            'Khandeshi',
            'Gujarati',
            'Punjabi',
            'Tamil',
            'Telugu',
            'Bengali',
          ]),
        );

        // Discovery returns empty safely without fabricating unauthorized data
        final searchResult = await provider.search('bolly');
        expect(searchResult.isEmpty, isTrue);

        final trending = await provider.getTrending();
        expect(trending.isEmpty, isTrue);
      },
    );

    test(
      'ProviderRegistry discoveryProviders filters out non-ACTIVE providers',
      () {
        final ProviderRegistry registry = ProviderRegistry(
          api: ApiClient(),
          cache: CacheStore(),
        );

        final List<String> discoveryIds = registry.discoveryProviders
            .map((p) => p.id)
            .toList();

        // Only ACTIVE providers can appear in discovery
        expect(discoveryIds, isNot(contains('regional_indian')));
        expect(discoveryIds, isNot(contains('licensed')));
        expect(discoveryIds, isNot(contains('demo')));
        expect(discoveryIds, isNot(contains('listenfree')));
      },
    );
  });
}
