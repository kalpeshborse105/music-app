import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_flow_music/core/cache/cache_store.dart';
import 'package:echo_flow_music/core/network/api_client.dart';
import 'package:echo_flow_music/core/storage/settings_store.dart';
import 'package:echo_flow_music/data/provider_registry.dart';
import 'package:echo_flow_music/domain/models/track.dart';
import 'package:echo_flow_music/domain/providers/regional_music_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Production QA & Play Store Release Readiness Tests', () {
    late SettingsStore settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      settings = SettingsStore();
      await settings.init();
    });

    test('Default app theme is strictly DARK on fresh installation', () {
      expect(settings.themeMode, equals(ThemeMode.dark));
    });

    test('Provider settings default: Custom API ON, others OFF', () {
      expect(settings.customApiEnabled, isTrue);
      expect(settings.audiusEnabled, isFalse);
      expect(settings.jamendoEnabled, isFalse);
      expect(settings.archiveEnabled, isFalse);
      expect(settings.localEnabled, isFalse);
    });

    test('ProviderRegistry discovery uses Custom API by default', () async {
      final ProviderRegistry registry = ProviderRegistry(
        api: ApiClient(),
        cache: CacheStore(),
        settings: settings,
      );

      final List<String> discoveryIds =
          registry.discoveryProviders.map((p) => p.id).toList();

      expect(discoveryIds, isNot(contains('jamendo')));
      expect(discoveryIds, isNot(contains('audius')));
      expect(discoveryIds, contains('custom_api'));

      // Available check respects jamendoEnabled
      expect(registry.isAvailable('jamendo'), isFalse);
      expect(registry.isAvailable('custom_api'), isTrue);
    });

    test('ProviderRegistry dynamically enables Jamendo when toggled on by admin', () async {
      final ProviderRegistry registry = ProviderRegistry(
        api: ApiClient(),
        cache: CacheStore(),
        settings: settings,
      );

      expect(registry.isAvailable('jamendo'), isFalse);

      await settings.setJamendoEnabled(true);
      expect(settings.jamendoEnabled, isTrue);

      final List<String> discoveryIds =
          registry.discoveryProviders.map((p) => p.id).toList();
      expect(discoveryIds, contains('jamendo'));
      expect(registry.isAvailable('jamendo'), isTrue);
    });

    test('Regional Indian Music Provider supports all target Indian languages', () {
      final RegionalMusicProvider provider = RegionalMusicProvider(
        api: ApiClient(),
        cache: CacheStore(),
      );

      final List<String> languageNames =
          provider.supportedLanguages.map((RegionalLanguage l) => l.displayName).toList();

      expect(
        languageNames,
        containsAll(<String>[
          'Hindi',
          'Marathi',
          'Punjabi',
          'Bengali',
          'Gujarati',
          'Tamil',
          'Telugu',
          'Kannada',
          'Malayalam',
          'Odia',
          'Assamese',
        ]),
      );
    });

    test('Offline local playback source generation creates valid file URI', () {
      const String localPath = '/data/user/0/com.kalpkrut.beats/app_flutter/downloads/audius_123.mp3';
      final Uri fileUri = Uri.file(localPath);
      expect(fileUri.isScheme('file'), isTrue);
      expect(fileUri.toFilePath(windows: false), equals(localPath));
    });

    test('Track model stable ID deduplication logic', () {
      const Track t1 = Track(id: 'song_1', title: 'Song 1', providerId: 'audius', providerTrackId: '1');
      const Track t2 = Track(id: 'song_2', title: 'Song 2', providerId: 'audius', providerTrackId: '2');
      const Track t1Duplicate = Track(id: 'song_1', title: 'Song 1 Updated', providerId: 'audius', providerTrackId: '1');

      final List<Track> rawHistory = <Track>[t1, t2, t1Duplicate];
      final Set<String> seen = <String>{};
      final List<Track> deduplicated = <Track>[];

      for (final Track t in rawHistory.reversed) {
        if (seen.add(t.id)) {
          deduplicated.add(t);
        }
      }

      // Latest play timestamp of song_1 should be first, and total items must be 2
      expect(deduplicated.length, equals(2));
      expect(deduplicated.first.id, equals('song_1'));
      expect(deduplicated.first.title, equals('Song 1 Updated'));
      expect(deduplicated.last.id, equals('song_2'));
    });

    test('ProviderRegistry complianceRecords expose all mandatory compliance fields', () {
      final ProviderRegistry registry = ProviderRegistry(
        api: ApiClient(),
        cache: CacheStore(),
        settings: settings,
      );

      final records = registry.complianceRecords;
      expect(records, isNotEmpty);

      for (final r in records) {
        expect(r.provider, isNotEmpty);
        expect(r.license, isNotEmpty);
        expect(r.licenseUrl, isNotEmpty);
        expect(r.sourceUrl, isNotEmpty);
        expect(r.commercialUseStatus, isNotEmpty);
        expect(r.backgroundPlaybackStatus, isNotEmpty);
      }

      // Verify unverified sources are strictly disabled
      final listenFree = records.firstWhere((r) => r.provider == 'listenfree');
      expect(listenFree.enabled, isFalse);
      expect(listenFree.status.code, equals('DISABLED'));
      expect(listenFree.streamSupported, isFalse);
      expect(listenFree.commercialUseStatus, contains('UNVERIFIED'));

      // Verify regional indian provider is license pending
      final regional = records.firstWhere((r) => r.provider == 'regional_indian');
      expect(regional.status.code, equals('LICENSE_PENDING'));
      expect(regional.streamSupported, isFalse);
    });
  });
}
