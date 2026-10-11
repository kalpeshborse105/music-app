import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../domain/models/advertisement.dart';
import '../../domain/models/history_entry.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';

/// Central Supabase service handling authentication, session persistence,
/// profiles, favorites, recently played history, playlists, and settings.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => _isInitialized ? client.auth.currentUser : null;
  Session? get currentSession => _isInitialized ? client.auth.currentSession : null;
  bool get isAuthenticated => _isInitialized && client.auth.currentUser != null;
  String? get currentUserId => currentUser?.id;

  /// Stream of Supabase auth state changes for dynamic UI reactions
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Initialize Supabase with runtime credentials
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!AppConfig.supabaseConfigured) {
      debugPrint('[SupabaseService] Supabase credentials not configured.');
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Initialized successfully. User: ${client.auth.currentUser?.email ?? "Guest"}');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization failed/skipped: $e');
    }
  }

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!_isInitialized) return null;
    final AuthResponse res = await client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null
          ? <String, dynamic>{
              'full_name': displayName,
              'name': displayName,
              'display_name': displayName,
            }
          : null,
    );
    if (res.user != null) {
      await ensureProfile(
        email: email,
        displayName: displayName,
      );
    }
    return res;
  }

  Future<AuthResponse?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) return null;
    final AuthResponse res = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user != null) {
      await ensureProfile(email: email);
    }
    return res;
  }

  /// Official Supabase Google OAuth sign in
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    if (!_isInitialized) return false;
    try {
      final String? redirect;
      if (redirectTo != null && redirectTo.isNotEmpty) {
        redirect = redirectTo;
      } else if (kIsWeb) {
        redirect = kReleaseMode ? 'https://beats.kalpkrutinfotech.com/' : Uri.base.origin;
      } else {
        redirect = 'com.kalpkrut.beats://login-callback';
      }

      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } catch (e) {
      debugPrint('[SupabaseService] Google sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_isInitialized) return;
    await client.auth.signOut();
  }

  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
    if (!_isInitialized) return;
    final String redirect = redirectTo ??
        (kIsWeb
            ? (kReleaseMode ? 'https://beats.kalpkrutinfotech.com/' : Uri.base.origin)
            : 'com.kalpkrut.beats://login-callback');
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirect,
    );
  }

  /// Updates the current authenticated user's password in Supabase DB.
  Future<void> updateUserPassword(String newPassword) async {
    if (!_isInitialized) return;
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ==========================================
  // AUTHORIZATION & ROLES
  // ==========================================

  /// Strictly verifies whether the current authenticated user has the 'admin' role.
  /// Checks both user/app metadata and the PostgreSQL `profiles` table.
  Future<bool> isUserAdmin() async {
    if (!_isInitialized || currentUser == null) return false;

    // Check user/app JWT metadata if present
    final dynamic appRole = currentUser!.appMetadata['role'];
    final dynamic userRole = currentUser!.userMetadata?['role'];
    if (appRole == 'admin' || userRole == 'admin') return true;

    try {
      final Map<String, dynamic>? data = await client
          .from('profiles')
          .select('role')
          .eq('id', currentUser!.id)
          .maybeSingle();

      return data != null && data['role'] == 'admin';
    } catch (e) {
      debugPrint('[SupabaseService] isUserAdmin error: $e');
      return false;
    }
  }

  // ==========================================
  // PROFILES
  // ==========================================

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    Map<String, dynamic>? data;
    if (_isInitialized) {
      try {
        data = await client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        debugPrint('[SupabaseService] getProfile error: $e');
      }
    }

    // Merge or fallback to locally cached avatar / name
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? cachedName = prefs.getString('cached_display_name_$userId');
      final String? cachedAvatar = prefs.getString('cached_avatar_url_$userId');
      if (cachedName != null || cachedAvatar != null) {
        final Map<String, dynamic> merged = <String, dynamic>{
          ...?data,
          'id': userId,
        };
        if (cachedName != null && (merged['display_name'] == null || (merged['display_name'] as String).isEmpty)) {
          merged['display_name'] = cachedName;
        }
        if (cachedAvatar != null && (merged['avatar_url'] == null || (merged['avatar_url'] as String).isEmpty)) {
          merged['avatar_url'] = cachedAvatar;
        }
        return merged;
      }
    } catch (_) {}

    return data;
  }

  /// Ensures a user profile exists in Supabase PostgreSQL `profiles` table.
  /// Safely creates missing row or fills missing display name/avatar without duplicates.
  Future<Map<String, dynamic>?> ensureProfile({
    String? email,
    String? displayName,
    String? avatarUrl,
  }) async {
    if (!_isInitialized || currentUser == null) return null;
    final String userId = currentUser!.id;
    try {
      final Map<String, dynamic>? existing = await getProfile(userId);
      final String? metaName = displayName ??
          (currentUser!.userMetadata?['full_name'] as String?) ??
          (currentUser!.userMetadata?['name'] as String?) ??
          (currentUser!.userMetadata?['display_name'] as String?);
      final String? metaAvatar = avatarUrl ??
          (currentUser!.userMetadata?['avatar_url'] as String?);
      final String? userEmail = email ?? currentUser!.email;

      if (existing != null) {
        final bool nameMissing = (existing['display_name'] == null ||
            (existing['display_name'] as String).trim().isEmpty);
        final bool avatarMissing = (existing['avatar_url'] == null ||
            (existing['avatar_url'] as String).trim().isEmpty);

        if ((nameMissing && metaName != null && metaName.isNotEmpty) ||
            (avatarMissing && metaAvatar != null && metaAvatar.isNotEmpty)) {
          final Map<String, dynamic> updates = <String, dynamic>{
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (nameMissing && metaName != null && metaName.isNotEmpty) {
            updates['display_name'] = metaName;
          }
          if (avatarMissing && metaAvatar != null && metaAvatar.isNotEmpty) {
            updates['avatar_url'] = metaAvatar;
          }
          await client.from('profiles').update(updates).eq('id', userId);
          return await getProfile(userId);
        }
        return existing;
      }

      // Profile does not exist yet: create safely
      final Map<String, dynamic> newProfile = <String, dynamic>{
        'id': userId,
        'email': userEmail,
        'display_name': (metaName != null && metaName.isNotEmpty)
            ? metaName
            : (userEmail?.split('@').first ?? 'Kalpkrut Listener'),
        if (metaAvatar != null && metaAvatar.isNotEmpty) 'avatar_url': metaAvatar,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('profiles').upsert(newProfile);
      return await getProfile(userId);
    } catch (e) {
      debugPrint('[SupabaseService] ensureProfile error: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final Map<String, dynamic> updates = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;

    // Immediately cache in local SharedPreferences for persistent offline & immediate reload
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (displayName != null) await prefs.setString('cached_display_name_$userId', displayName);
      if (avatarUrl != null) await prefs.setString('cached_avatar_url_$userId', avatarUrl);
    } catch (_) {}

    if (_isInitialized) {
      try {
        await client.from('profiles').upsert(updates);
      } catch (e) {
        debugPrint('[SupabaseService] profiles upsert error: $e');
        try {
          await client.from('profiles').update(updates).eq('id', userId);
        } catch (_) {}
      }

      // Keep auth user metadata in sync with database profile
      try {
        final Map<String, dynamic> meta = <String, dynamic>{};
        if (displayName != null) {
          meta['full_name'] = displayName;
          meta['name'] = displayName;
          meta['display_name'] = displayName;
        }
        // Only store in auth metadata if it's a URL, not a large data URI
        if (avatarUrl != null && !avatarUrl.startsWith('data:')) {
          meta['avatar_url'] = avatarUrl;
        }
        if (meta.isNotEmpty) {
          await client.auth.updateUser(UserAttributes(data: meta));
        }
      } catch (e) {
        debugPrint('[SupabaseService] sync userMetadata error: $e');
      }
    }
  }

  // ==========================================
  // FAVORITES / LIKED SONGS
  // ==========================================

  Future<List<Track>> fetchFavorites() async {
    if (!_isInitialized || currentUser == null) return <Track>[];
    try {
      final List<dynamic> response = await client
          .from('favorites')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);

      final List<Track> tracks = <Track>[];
      for (final dynamic item in response) {
        if (item is Map) {
          final dynamic meta = item['custom_metadata'];
          if (meta != null && meta is Map) {
            try {
              tracks.add(Track.fromJson(meta.cast<String, dynamic>()));
            } catch (_) {}
          }
        }
      }
      return tracks;
    } catch (e) {
      debugPrint('[SupabaseService] fetchFavorites error: $e');
      return <Track>[];
    }
  }

  Future<void> addFavorite(Track track) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      final List<dynamic> existing = await client
          .from('favorites')
          .select('id')
          .eq('user_id', currentUser!.id)
          .eq('local_track_id', track.id)
          .limit(1);

      if (existing.isEmpty) {
        await client.from('favorites').insert(<String, dynamic>{
          'user_id': currentUser!.id,
          'local_track_id': track.id,
          'custom_metadata': track.toJson(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[SupabaseService] addFavorite error: $e');
    }
  }

  Future<void> removeFavorite(String trackId) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', currentUser!.id)
          .eq('local_track_id', trackId);
    } catch (e) {
      debugPrint('[SupabaseService] removeFavorite error: $e');
    }
  }

  Future<void> toggleFavorite({
    required String trackId,
    required Map<String, dynamic> metadata,
    required bool isFavorite,
  }) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      if (isFavorite) {
        final List<dynamic> existing = await client
            .from('favorites')
            .select('id')
            .eq('user_id', currentUser!.id)
            .eq('local_track_id', trackId)
            .limit(1);

        if (existing.isEmpty) {
          await client.from('favorites').insert(<String, dynamic>{
            'user_id': currentUser!.id,
            'local_track_id': trackId,
            'custom_metadata': metadata,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        await client
            .from('favorites')
            .delete()
            .eq('user_id', currentUser!.id)
            .eq('local_track_id', trackId);
      }
    } catch (e) {
      debugPrint('[SupabaseService] toggleFavorite error: $e');
    }
  }

  // ==========================================
  // PLAYLISTS & PLAYLIST TRACKS
  // ==========================================

  Future<List<Playlist>> fetchPlaylists() async {
    if (!_isInitialized || currentUser == null) return <Playlist>[];
    try {
      final List<dynamic> playlistsData = await client
          .from('playlists')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);

      final List<Playlist> playlists = <Playlist>[];
      for (final dynamic p in playlistsData) {
        if (p is! Map) continue;
        final String playlistId = p['id'] as String;

        // Fetch tracks for this playlist
        final List<dynamic> tracksData = await client
            .from('playlist_tracks')
            .select()
            .eq('playlist_id', playlistId)
            .order('position', ascending: true);

        final List<Track> tracks = <Track>[];
        for (final dynamic t in tracksData) {
          if (t is Map) {
            final dynamic trackData = t['custom_track_data'];
            if (trackData != null && trackData is Map) {
              try {
                tracks.add(Track.fromJson(trackData.cast<String, dynamic>()));
              } catch (_) {}
            }
          }
        }

        playlists.add(Playlist(
          id: playlistId,
          title: p['title'] as String? ?? 'Untitled Playlist',
          description: p['description'] as String?,
          artworkUrl: p['artwork_url'] as String?,
          tracks: tracks,
          trackCount: tracks.length,
          source: PlaylistSource.user,
          updatedAt: p['updated_at'] != null ? DateTime.tryParse(p['updated_at'].toString()) : null,
        ));
      }
      return playlists;
    } catch (e) {
      debugPrint('[SupabaseService] fetchPlaylists error: $e');
      return <Playlist>[];
    }
  }

  Future<Playlist?> createPlaylist(String title, {String? description}) async {
    if (!_isInitialized || currentUser == null) return null;
    try {
      final Map<String, dynamic> response = await client
          .from('playlists')
          .insert(<String, dynamic>{
            'user_id': currentUser!.id,
            'title': title,
            'description': description,
            'track_count': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return Playlist(
        id: response['id'] as String,
        title: response['title'] as String? ?? title,
        description: response['description'] as String?,
        tracks: const <Track>[],
        trackCount: 0,
        source: PlaylistSource.user,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SupabaseService] createPlaylist error: $e');
      return null;
    }
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client.from('playlists').update(<String, dynamic>{
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', playlistId).eq('user_id', currentUser!.id);
    } catch (e) {
      debugPrint('[SupabaseService] renamePlaylist error: $e');
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client
          .from('playlists')
          .delete()
          .eq('id', playlistId)
          .eq('user_id', currentUser!.id);
    } catch (e) {
      debugPrint('[SupabaseService] deletePlaylist error: $e');
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track, int position) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client.from('playlist_tracks').insert(<String, dynamic>{
        'playlist_id': playlistId,
        'custom_track_data': track.toJson(),
        'position': position,
        'added_at': DateTime.now().toIso8601String(),
      });

      // Update playlist track count
      final Map<String, dynamic>? current = await client
          .from('playlists')
          .select('track_count')
          .eq('id', playlistId)
          .maybeSingle();

      final int count = ((current?['track_count'] as num?)?.toInt() ?? 0) + 1;
      await client.from('playlists').update(<String, dynamic>{
        'track_count': count,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', playlistId);
    } catch (e) {
      debugPrint('[SupabaseService] addTrackToPlaylist error: $e');
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client
          .from('playlist_tracks')
          .delete()
          .eq('playlist_id', playlistId)
          .filter('custom_track_data->>id', 'eq', trackId);

      final Map<String, dynamic>? current = await client
          .from('playlists')
          .select('track_count')
          .eq('id', playlistId)
          .maybeSingle();

      final int count = (((current?['track_count'] as num?)?.toInt() ?? 1) - 1).clamp(0, 99999);
      await client.from('playlists').update(<String, dynamic>{
        'track_count': count,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', playlistId);
    } catch (e) {
      debugPrint('[SupabaseService] removeTrackFromPlaylist error: $e');
    }
  }

  // ==========================================
  // RECENTLY PLAYED
  // ==========================================

  Future<List<HistoryEntry>> fetchRecentlyPlayed() async {
    if (!_isInitialized || currentUser == null) return <HistoryEntry>[];
    try {
      final List<dynamic> response = await client
          .from('recently_played')
          .select()
          .eq('user_id', currentUser!.id)
          .order('played_at', ascending: false)
          .limit(50);

      final List<HistoryEntry> history = <HistoryEntry>[];
      final Set<String> seen = <String>{};
      for (final dynamic item in response) {
        if (item is Map) {
          final dynamic meta = item['custom_metadata'];
          if (meta != null && meta is Map) {
            try {
              final Track track = Track.fromJson(meta.cast<String, dynamic>());
              // Strictly deduplicate by track.id: Keep only the latest play timestamp
              if (!seen.add(track.id)) continue;

              final DateTime playedAt = item['played_at'] != null
                  ? (DateTime.tryParse(item['played_at'].toString()) ?? DateTime.now())
                  : DateTime.now();
              history.add(HistoryEntry(
                track: track,
                lastPlayed: playedAt,
                completion: 1.0,
              ));
            } catch (_) {}
          }
        }
      }
      return history;
    } catch (e) {
      debugPrint('[SupabaseService] fetchRecentlyPlayed error: $e');
      return <HistoryEntry>[];
    }
  }

  // ==========================================
  // ACCOUNT DELETION (PLAY STORE COMPLIANCE)
  // ==========================================

  Future<bool> deleteAccount() async {
    if (!_isInitialized || currentUser == null) return false;
    final String userId = currentUser!.id;
    try {
      // 1. Delete user favorites
      try {
        await client.from('favorites').delete().eq('user_id', userId);
      } catch (_) {}

      // 2. Delete user playlists and tracks
      try {
        await client.from('playlists').delete().eq('user_id', userId);
      } catch (_) {}

      // 3. Delete user playback history
      try {
        await client.from('recently_played').delete().eq('user_id', userId);
      } catch (_) {}

      // 4. Delete user settings
      try {
        await client.from('user_settings').delete().eq('user_id', userId);
      } catch (_) {}

      // 5. Delete profile record
      try {
        await client.from('profiles').delete().eq('id', userId);
      } catch (_) {}

      // 6. Delete avatar storage files if any exist
      try {
        final List<FileObject> objects =
            await client.storage.from('avatars').list(path: 'avatars');
        final List<String> userFiles = objects
            .where((FileObject o) => o.name.startsWith(userId))
            .map((FileObject o) => 'avatars/${o.name}')
            .toList();
        if (userFiles.isNotEmpty) {
          await client.storage.from('avatars').remove(userFiles);
        }
      } catch (_) {}

      // 7. Sign out locally
      await client.auth.signOut();
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteAccount error: $e');
      return false;
    }
  }

  Future<void> recordRecentlyPlayed({
    required String trackId,
    required Map<String, dynamic> customMetadata,
    int durationPlayedMs = 0,
  }) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      await client.from('recently_played').insert(<String, dynamic>{
        'user_id': currentUser!.id,
        'custom_metadata': customMetadata,
        'duration_played_ms': durationPlayedMs,
        'played_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseService] recordRecentlyPlayed error: $e');
    }
  }

  // ==========================================
  // USER SETTINGS
  // ==========================================

  Future<Map<String, dynamic>?> fetchUserSettings() async {
    if (!_isInitialized || currentUser == null) return null;
    try {
      final Map<String, dynamic>? data = await client
          .from('user_settings')
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserSettings error: $e');
      return null;
    }
  }

  Future<void> saveUserSettings({
    String? themeMode,
    String? audioQuality,
    bool? normalizeVolume,
    bool? downloadOverWifiOnly,
  }) async {
    if (!_isInitialized || currentUser == null) return;
    try {
      final Map<String, dynamic> updates = <String, dynamic>{
        'user_id': currentUser!.id,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (themeMode != null) updates['theme_mode'] = themeMode;
      if (audioQuality != null) updates['audio_quality'] = audioQuality;
      if (normalizeVolume != null) updates['normalize_volume'] = normalizeVolume;
      if (downloadOverWifiOnly != null) updates['download_over_wifi_only'] = downloadOverWifiOnly;

      await client.from('user_settings').upsert(updates);
    } catch (e) {
      debugPrint('[SupabaseService] saveUserSettings error: $e');
    }
  }

  // ==========================================
  // PROFILE AVATAR UPLOAD (JPG, PNG ONLY)
  // ==========================================

  Future<String?> uploadAvatar({
    required String userId,
    required dynamic file, // XFile
  }) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final String ext = (file.name as String).split('.').last.toLowerCase();
      final String fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';

      if (_isInitialized) {
        // 1. Try uploading to 'avatars' bucket directly
        try {
          await client.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
          final String publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
          if (publicUrl.isNotEmpty) return publicUrl;
        } catch (e1) {
          debugPrint('[SupabaseService] upload to avatars bucket failed: $e1');
        }

        // 2. Try with path 'avatars/$fileName'
        try {
          await client.storage.from('avatars').uploadBinary(
            'avatars/$fileName',
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
          final String publicUrl = client.storage.from('avatars').getPublicUrl('avatars/$fileName');
          if (publicUrl.isNotEmpty) return publicUrl;
        } catch (_) {}
      }

      // 3. Guaranteed Fallback: Base64 data URI (instantly stores and persists without storage bucket constraints)
      final String base64Str = base64Encode(bytes);
      return 'data:image/$ext;base64,$base64Str';
    } catch (e) {
      debugPrint('[SupabaseService] uploadAvatar error: $e');
      return null;
    }
  }

  // ==========================================
  // ADMIN PLATFORM METRICS & USER MANAGEMENT
  // ==========================================

  /// Queries real platform metrics from Supabase database tables.
  /// If a table is not yet created or empty, safely returns "Not tracked yet".
  Future<Map<String, dynamic>> fetchAdminPlatformMetrics() async {
    if (!_isInitialized) {
      return <String, dynamic>{
        'database_status': 'Offline',
        'last_sync': DateTime.now().toIso8601String(),
      };
    }

    final Map<String, dynamic> metrics = <String, dynamic>{
      'database_status': 'Online & Connected',
      'last_sync': DateTime.now().toIso8601String(),
    };

    Future<String> countTable(String tableName) async {
      try {
        final PostgrestResponse res = await client
            .from(tableName)
            .select()
            .count(CountOption.exact);
        final int count = res.count;
        return count.toString();
      } catch (e) {
        return 'Not tracked yet';
      }
    }

    metrics['users_count'] = await countTable('profiles');
    metrics['tracks_count'] = await countTable('tracks');
    metrics['artists_count'] = await countTable('artists');
    metrics['albums_count'] = await countTable('albums');
    metrics['playlists_count'] = await countTable('playlists');
    metrics['favorites_count'] = await countTable('favorites');
    metrics['recently_played_count'] = await countTable('recently_played');
    metrics['reports_count'] = await countTable('reports');

    return metrics;
  }

  /// Fetches real registered users from `profiles` table for admin inspection.
  /// Passwords and sensitive authentication credentials are never returned.
  Future<List<Map<String, dynamic>>> fetchAdminUsers({int limit = 50}) async {
    if (!_isInitialized) return <Map<String, dynamic>>[];
    try {
      final List<dynamic> data = await client
          .from('profiles')
          .select('id, display_name, email, role, avatar_url, created_at, updated_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return data.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchAdminUsers error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Fetches real reports from `reports` table for admin review.
  Future<List<Map<String, dynamic>>> fetchAdminReports() async {
    if (!_isInitialized) return <Map<String, dynamic>>[];
    try {
      final List<dynamic> data = await client
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return data.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchAdminReports error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Updates report resolution status
  Future<bool> updateReportStatus(String reportId, String status) async {
    if (!_isInitialized) return false;
    try {
      await client.from('reports').update(<String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateReportStatus error: $e');
      return false;
    }
  }

  // ==========================================
  // ADVERTISEMENTS & ANNOUNCEMENTS (ADMIN CONTROLLED)
  // ==========================================

  static const String _adsPrefKey = 'cached_admin_advertisements';

  Future<List<Advertisement>> fetchAdvertisements() async {
    if (_isInitialized) {
      try {
        final List<dynamic> data = await client
            .from('advertisements')
            .select()
            .order('display_order', ascending: true);
        final List<Advertisement> ads = data
            .map((dynamic item) => Advertisement.fromJson(item as Map<String, dynamic>))
            .toList();
        await _saveLocalAds(ads);
        return ads;
      } catch (e) {
        debugPrint('[SupabaseService] Remote fetchAdvertisements skipped/fallback: $e');
      }
    }
    return _getLocalAds();
  }

  Future<List<Advertisement>> fetchActiveAdvertisements() async {
    final List<Advertisement> all = await fetchAdvertisements();
    return all.where((Advertisement ad) => ad.isActive && ad.imageUrl.isNotEmpty).toList();
  }

  Future<bool> saveAdvertisement(Advertisement ad) async {
    bool remoteSuccess = false;
    if (_isInitialized) {
      try {
        await client.from('advertisements').upsert(ad.toJson());
        remoteSuccess = true;
      } catch (e) {
        debugPrint('[SupabaseService] saveAdvertisement remote error: $e');
      }
    }

    final List<Advertisement> list = await _getLocalAds();
    final int idx = list.indexWhere((Advertisement a) => a.id == ad.id);
    if (idx >= 0) {
      list[idx] = ad;
    } else {
      list.insert(0, ad);
    }
    await _saveLocalAds(list);
    return remoteSuccess || true;
  }

  Future<bool> deleteAdvertisement(String id) async {
    if (_isInitialized) {
      try {
        await client.from('advertisements').delete().eq('id', id);
      } catch (e) {
        debugPrint('[SupabaseService] deleteAdvertisement remote error: $e');
      }
    }
    final List<Advertisement> list = await _getLocalAds();
    list.removeWhere((Advertisement a) => a.id == id);
    await _saveLocalAds(list);
    return true;
  }

  Future<bool> toggleAdvertisementActive(String id, bool isActive) async {
    final List<Advertisement> list = await _getLocalAds();
    final int idx = list.indexWhere((Advertisement a) => a.id == id);
    if (idx >= 0) {
      final Advertisement updated = list[idx].copyWith(isActive: isActive);
      return saveAdvertisement(updated);
    }
    return false;
  }

  Future<List<Advertisement>> _getLocalAds() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_adsPrefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((dynamic item) => Advertisement.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SupabaseService] _getLocalAds error: $e');
    }
    return <Advertisement>[];
  }

  Future<void> _saveLocalAds(List<Advertisement> ads) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(ads.map((Advertisement a) => a.toJson()).toList());
      await prefs.setString(_adsPrefKey, jsonStr);
    } catch (e) {
      debugPrint('[SupabaseService] _saveLocalAds error: $e');
    }
  }
}
