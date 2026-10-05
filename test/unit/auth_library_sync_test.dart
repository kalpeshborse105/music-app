import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/data/services/supabase_service.dart';
import 'package:kalpkrut_beats/domain/models/track.dart';

void main() {
  group('SupabaseService Auth & Admin Verification', () {
    test(
      'Default initial state is signed out with no active user or session',
      () {
        final SupabaseService service = SupabaseService();
        // Fresh app start without credentials/session must be unauthenticated
        expect(service.isAuthenticated, isFalse);
        expect(service.currentUser, isNull);
        expect(service.currentSession, isNull);
        expect(service.currentUserId, isNull);
      },
    );

    test(
      'Non-authenticated or guest user is strictly denied admin access',
      () async {
        final SupabaseService service = SupabaseService();
        final bool isAdmin = await service.isUserAdmin();
        expect(isAdmin, isFalse);
      },
    );

    test(
      'Track models serialize and deserialize correctly for Supabase storage',
      () {
        final Track track = Track(
          id: 'jamendo:track:999',
          providerId: 'jamendo',
          providerTrackId: '999',
          title: 'Cosmic Journey',
          duration: const Duration(seconds: 215),
        );

        final Map<String, dynamic> json = track.toJson();
        expect(json['id'], equals('jamendo:track:999'));
        expect(json['title'], equals('Cosmic Journey'));

        final Track restored = Track.fromJson(json);
        expect(restored.id, equals(track.id));
        expect(restored.title, equals(track.title));
        expect(restored.duration.inSeconds, equals(215));
      },
    );

    test(
      'ensureProfile safely returns null when unauthenticated or uninitialized',
      () async {
        final SupabaseService service = SupabaseService();
        final Map<String, dynamic>? profile = await service.ensureProfile();
        expect(profile, isNull);
      },
    );

    test(
      'Non-authenticated session operations return empty lists and do not crash',
      () async {
        final SupabaseService service = SupabaseService();
        final favs = await service.fetchFavorites();
        final playlists = await service.fetchPlaylists();
        final history = await service.fetchRecentlyPlayed();
        expect(favs, isEmpty);
        expect(playlists, isEmpty);
        expect(history, isEmpty);
      },
    );
  });
}
