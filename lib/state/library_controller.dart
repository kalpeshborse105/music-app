import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/storage/library_store.dart';
import '../core/utils/logger.dart';
import '../data/services/supabase_service.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/history_entry.dart';
import '../domain/models/playlist.dart';
import '../domain/models/track.dart';
import '../domain/providers/local_provider.dart';

/// UI-facing facade over [LibraryStore] plus the device music scan,
/// dynamically synchronized with real Supabase database when authenticated.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required LibraryStore store,
    SupabaseService? supabase,
  })  : _store = store,
        _supabase = supabase ?? SupabaseService() {
    _initAuth();
  }

  final LibraryStore _store;
  final SupabaseService _supabase;
  StreamSubscription<AuthState>? _authSub;

  bool get isAuthenticated => _supabase.isAuthenticated;

  void _initAuth() {
    try {
      _authSub = _supabase.authStateChanges.listen((AuthState state) {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.userUpdated) {
          syncWithSupabase();
        } else if (state.event == AuthChangeEvent.signedOut) {
          onSignedOut();
        }
      });

      if (_supabase.isAuthenticated) {
        syncWithSupabase();
      }
    } catch (e) {
      Logger.warn('Auth state listener init: $e');
    }
  }

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  String get displayName {
    if (_userProfile != null &&
        _userProfile!['display_name'] != null &&
        (_userProfile!['display_name'] as String).trim().isNotEmpty) {
      return _userProfile!['display_name'] as String;
    }
    final dynamic metaName = _supabase.currentUser?.userMetadata?['full_name'] ??
        _supabase.currentUser?.userMetadata?['name'] ??
        _supabase.currentUser?.userMetadata?['display_name'];
    if (metaName is String && metaName.trim().isNotEmpty) {
      return metaName;
    }
    final String? email = _supabase.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Listener';
  }

  String? get avatarUrl {
    if (_userProfile != null &&
        _userProfile!['avatar_url'] != null &&
        (_userProfile!['avatar_url'] as String).trim().isNotEmpty) {
      return _userProfile!['avatar_url'] as String;
    }
    final dynamic metaAvatar = _supabase.currentUser?.userMetadata?['avatar_url'];
    if (metaAvatar is String && metaAvatar.trim().isNotEmpty) {
      return metaAvatar;
    }
    return null;
  }

  String get userEmail => _supabase.currentUser?.email ?? '';

  String? get preferredLanguage {
    if (_userProfile != null &&
        _userProfile!['preferred_language'] != null &&
        (_userProfile!['preferred_language'] as String).trim().isNotEmpty) {
      return _userProfile!['preferred_language'] as String;
    }
    return null;
  }

  bool get isAdmin => _userProfile?['role'] == 'admin';

  Future<void> refreshProfile() async {
    if (!_supabase.isAuthenticated || _supabase.currentUserId == null) {
      _userProfile = null;
      notifyListeners();
      return;
    }
    try {
      _userProfile = await _supabase.getProfile(_supabase.currentUserId!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    String? bio,
    String? preferredLanguage,
  }) async {
    if (!_supabase.isAuthenticated || _supabase.currentUserId == null) return;
    await _supabase.updateProfile(
      userId: _supabase.currentUserId!,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      preferredLanguage: preferredLanguage,
    );
    await refreshProfile();
  }

  /// Syncs remote favorites, playlists, profile, and history from Supabase with local store
  Future<void> syncWithSupabase() async {
    if (!_supabase.isAuthenticated) return;
    try {
      await refreshProfile();
      final List<Track> remoteFavs = await _supabase.fetchFavorites();
      if (remoteFavs.isNotEmpty) {
        await _store.setLikedTracks(remoteFavs);
      }
      final List<Playlist> remotePlaylists = await _supabase.fetchPlaylists();
      if (remotePlaylists.isNotEmpty) {
        await _store.setPlaylists(remotePlaylists);
      }
      final List<HistoryEntry> remoteHistory = await _supabase.fetchRecentlyPlayed();
      await _store.setHistory(remoteHistory);
      notifyListeners();
    } catch (e) {
      Logger.warn('Supabase sync error', error: e);
    }
  }

  /// Clears local user data when signed out so no private data remains
  Future<void> onSignedOut() async {
    _userProfile = null;
    await _store.clearUserData();
    notifyListeners();
  }

  // ---- Favorites ----
  List<Track> get likedTracks => _store.getLikedTracks();
  bool isLiked(String trackId) => _store.isLiked(trackId);

  Future<void> toggleLike(Track track) async {
    final bool willBeLiked = !isLiked(track.id);
    await _store.toggleLiked(track);
    if (_supabase.isAuthenticated) {
      if (willBeLiked) {
        await _supabase.addFavorite(track);
      } else {
        await _supabase.removeFavorite(track.id);
      }
    }
    notifyListeners();
  }

  Future<void> setLiked(Track track, bool liked) async {
    await _store.setLiked(track, liked);
    if (_supabase.isAuthenticated) {
      if (liked) {
        await _supabase.addFavorite(track);
      } else {
        await _supabase.removeFavorite(track.id);
      }
    }
    notifyListeners();
  }

  // ---- Artists / Albums ----
  List<Artist> get followedArtists => _store.getFollowedArtists();
  bool isFollowingArtist(String id) => _store.isFollowingArtist(id);

  Future<void> toggleFollowArtist(Artist artist) async {
    await _store.toggleFollowArtist(artist);
    notifyListeners();
  }

  List<Album> get savedAlbums => _store.getSavedAlbums();
  bool isAlbumSaved(String id) => _store.isAlbumSaved(id);

  Future<void> toggleSaveAlbum(Album album) async {
    await _store.toggleSaveAlbum(album);
    notifyListeners();
  }

  // ---- Playlists ----
  List<Playlist> get playlists => _store.getPlaylists();
  Playlist? playlist(String id) => _store.getPlaylist(id);

  Future<Playlist> createPlaylist(String title, {String? description}) async {
    Playlist p;
    if (_supabase.isAuthenticated) {
      final Playlist? remote = await _supabase.createPlaylist(title, description: description);
      if (remote != null) {
        p = remote;
      } else {
        p = await _store.createPlaylist(title, description: description);
      }
    } else {
      p = await _store.createPlaylist(title, description: description);
    }
    final List<Playlist> all = _store.getPlaylists();
    if (!all.any((Playlist pl) => pl.id == p.id)) {
      all.insert(0, p);
      await _store.setPlaylists(all);
    }
    notifyListeners();
    return p;
  }

  Future<void> renamePlaylist(String id, String title) async {
    await _store.renamePlaylist(id, title);
    if (_supabase.isAuthenticated) {
      await _supabase.renamePlaylist(id, title);
    }
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _store.deletePlaylist(id);
    if (_supabase.isAuthenticated) {
      await _supabase.deletePlaylist(id);
    }
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final Playlist? p = _store.getPlaylist(playlistId);
    final int nextPos = p?.tracks.length ?? 0;
    await _store.addTrackToPlaylist(playlistId, track);
    if (_supabase.isAuthenticated) {
      await _supabase.addTrackToPlaylist(playlistId, track, nextPos);
    }
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _store.removeTrackFromPlaylist(playlistId, trackId);
    if (_supabase.isAuthenticated) {
      await _supabase.removeTrackFromPlaylist(playlistId, trackId);
    }
    notifyListeners();
  }

  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex) async {
    await _store.reorderPlaylist(playlistId, oldIndex, newIndex);
    notifyListeners();
  }

  // ---- Recently played ----
  List<HistoryEntry> get history => _store.getHistory();
  List<Track> get recentTracks =>
      _store.getHistory().map((HistoryEntry h) => h.track).toList();

  Future<void> clearHistory() async {
    await _store.clearHistory();
    if (_supabase.isAuthenticated) {
      await _supabase.clearRecentlyPlayed();
    }
    notifyListeners();
  }

  Future<void> removeFromHistory(String trackId) async {
    await _store.removeFromHistory(trackId);
    if (_supabase.isAuthenticated) {
      await _supabase.removeRecentlyPlayedTrack(trackId);
    }
    notifyListeners();
  }

  // ---- Recent searches ----
  List<String> get recentSearches => _store.getRecentSearches();
  Future<void> addRecentSearch(String query) async {
    await _store.addRecentSearch(query);
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await _store.clearRecentSearches();
    notifyListeners();
  }

  // ---- Local music ----
  List<Track> _localTracks = <Track>[];
  bool _localScanned = false;
  bool _localScanning = false;

  List<Track> get localTracks => _localTracks;
  bool get localScanned => _localScanned;
  bool get localScanning => _localScanning;

  /// Scans the device for the user's own audio files (nothing is uploaded).
  Future<void> scanLocal(LocalMusicProvider provider, {bool force = false}) async {
    if (_localScanning) return;
    if (_localScanned && !force) return;
    _localScanning = true;
    notifyListeners();
    try {
      final List<Track> tracks = await provider.scan(force: force);
      _localTracks = tracks;
      _localScanned = true;
    } catch (e) {
      Logger.warn('Local scan failed', error: e);
      _localTracks = <Track>[];
      _localScanned = true;
    } finally {
      _localScanning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
