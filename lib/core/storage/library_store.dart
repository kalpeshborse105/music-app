import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/supabase_service.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/history_entry.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// On-device persistence for everything the *user* owns: liked tracks,
/// followed artists, saved albums, playlists, recently played and recent
/// searches. Nothing here is uploaded anywhere (privacy-first, spec §16/§32).
///
/// Stored as JSON blobs in a single Hive box for simplicity + fast reads.
class LibraryStore {
  static const String _boxName = AppConstants.libraryBox;

  static const String _kLiked = 'liked_tracks';
  static const String _kFollowedArtists = 'followed_artists';
  static const String _kSavedAlbums = 'saved_albums';
  static const String _kPlaylists = 'playlists';
  static const String _kHistory = 'history';
  static const String _kSearches = 'recent_searches';

  final _uuid = const Uuid();
  Box<dynamic>? _box;
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedAt;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requireBox {
    final Box<dynamic>? box = _box;
    if (box == null) throw StateError('LibraryStore not initialized');
    return box;
  }

  // ---------------------------------------------------------------------------
  // Liked tracks (favorites)
  // ---------------------------------------------------------------------------
  List<Track> getLikedTracks() {
    final List<dynamic> raw = _readList(_kLiked);
    return raw
        .map((dynamic e) => Track.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  bool isLiked(String trackId) =>
      getLikedTracks().any((Track t) => t.id == trackId);

  Future<void> toggleLiked(Track track) async {
    final List<Track> liked = getLikedTracks();
    final int idx = liked.indexWhere((Track t) => t.id == track.id);
    if (idx >= 0) {
      liked.removeAt(idx);
    } else {
      liked.insert(0, track.toCompact());
    }
    await _writeList(_kLiked, liked.map((Track t) => t.toJson()).toList());
  }

  Future<void> setLiked(Track track, bool liked) async {
    final List<Track> current = getLikedTracks();
    current.removeWhere((Track t) => t.id == track.id);
    if (liked) current.insert(0, track.toCompact());
    await _writeList(_kLiked, current.map((Track t) => t.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Followed artists / saved albums
  // ---------------------------------------------------------------------------
  List<Artist> getFollowedArtists() => _readList(_kFollowedArtists)
      .map((dynamic e) => Artist.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  bool isFollowingArtist(String id) {
    final String cleanId = id.trim().toLowerCase();
    final String tailId = cleanId.contains(':') ? cleanId.split(':').last : cleanId;
    return getFollowedArtists().any((Artist a) {
      final String aId = a.id.trim().toLowerCase();
      final String aTail = aId.contains(':') ? aId.split(':').last : aId;
      final String aName = a.name.trim().toLowerCase();
      return aId == cleanId || aTail == tailId || aName == cleanId || aName == tailId;
    });
  }

  Future<void> toggleFollowArtist(Artist artist) async {
    final List<Artist> list = getFollowedArtists();
    final String cleanId = artist.id.trim().toLowerCase();
    final String cleanName = artist.name.trim().toLowerCase();
    final String tailId = cleanId.contains(':') ? cleanId.split(':').last : cleanId;

    final int idx = list.indexWhere((Artist a) {
      final String aId = a.id.trim().toLowerCase();
      final String aTail = aId.contains(':') ? aId.split(':').last : aId;
      final String aName = a.name.trim().toLowerCase();
      return aId == cleanId || aTail == tailId || aName == cleanName || aName == tailId;
    });

    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.insert(0, artist);
    }
    await _writeList(_kFollowedArtists, list.map((Artist a) => a.toJson()).toList());
  }

  List<Album> getSavedAlbums() => _readList(_kSavedAlbums)
      .map((dynamic e) => Album.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  bool isAlbumSaved(String id) =>
      getSavedAlbums().any((Album a) => a.id == id);

  Future<void> toggleSaveAlbum(Album album) async {
    final List<Album> list = getSavedAlbums();
    final int idx = list.indexWhere((Album a) => a.id == album.id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.insert(0, album);
    }
    await _writeList(_kSavedAlbums, list.map((Album a) => a.toJson()).toList());
  }

  Future<void> setFollowedArtists(List<Artist> list) async {
    await _writeList(_kFollowedArtists, list.map((Artist a) => a.toJson()).toList());
  }

  Future<void> setSavedAlbums(List<Album> list) async {
    await _writeList(_kSavedAlbums, list.map((Album a) => a.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Playlists (user-owned only; provider playlists stay provider-owned)
  // ---------------------------------------------------------------------------
  List<Playlist> getPlaylists() => _readList(_kPlaylists)
      .map((dynamic e) => Playlist.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  Playlist? getPlaylist(String id) {
    for (final Playlist p in getPlaylists()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final Playlist playlist = Playlist(
      id: 'playlist:${_uuid.v4()}',
      title: title,
      description: description,
      source: PlaylistSource.user,
      updatedAt: DateTime.now(),
    );
    final List<Playlist> all = getPlaylists()..insert(0, playlist);
    await _persistPlaylists(all);
    return playlist;
  }

  Future<void> renamePlaylist(String id, String title) async {
    final List<Playlist> all = getPlaylists();
    final int idx = all.indexWhere((Playlist p) => p.id == id);
    if (idx < 0) return;
    all[idx] = all[idx].copyWith(title: title, updatedAt: DateTime.now());
    await _persistPlaylists(all);
  }

  Future<void> deletePlaylist(String id) async {
    final List<Playlist> all = getPlaylists()..removeWhere((Playlist p) => p.id == id);
    await _persistPlaylists(all);
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final List<Playlist> all = getPlaylists();
    final int idx = all.indexWhere((Playlist p) => p.id == playlistId);
    if (idx < 0) return;
    final List<Track> tracks = <Track>[...all[idx].tracks];
    if (tracks.any((Track t) => t.id == track.id)) return; // de-dupe
    tracks.add(track.toCompact());
    all[idx] = all[idx].copyWith(
      tracks: tracks,
      trackCount: tracks.length,
      updatedAt: DateTime.now(),
    );
    await _persistPlaylists(all);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final List<Playlist> all = getPlaylists();
    final int idx = all.indexWhere((Playlist p) => p.id == playlistId);
    if (idx < 0) return;
    final List<Track> tracks =
        all[idx].tracks.where((Track t) => t.id != trackId).toList();
    all[idx] = all[idx].copyWith(
      tracks: tracks,
      trackCount: tracks.length,
      updatedAt: DateTime.now(),
    );
    await _persistPlaylists(all);
  }

  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex) async {
    final List<Playlist> all = getPlaylists();
    final int idx = all.indexWhere((Playlist p) => p.id == playlistId);
    if (idx < 0) return;
    final List<Track> tracks = <Track>[...all[idx].tracks];
    if (oldIndex < 0 || oldIndex >= tracks.length) return;
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final Track t = tracks.removeAt(oldIndex);
    tracks.insert(target.clamp(0, tracks.length), t);
    all[idx] = all[idx].copyWith(tracks: tracks, updatedAt: DateTime.now());
    await _persistPlaylists(all);
  }

  Future<void> _persistPlaylists(List<Playlist> playlists) async {
    await _writeList(_kPlaylists, playlists.map((Playlist p) => p.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Recently played
  // ---------------------------------------------------------------------------
  List<HistoryEntry> getHistory() {
    final List<dynamic> raw = _readList(_kHistory);
    final List<HistoryEntry> list = raw
        .map((dynamic e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    // Strictly deduplicate by stable track ID, preserving the latest (first) occurrence
    final Set<String> seen = <String>{};
    final List<HistoryEntry> deduped = <HistoryEntry>[];
    for (final HistoryEntry h in list) {
      if (seen.add(h.track.id)) {
        deduped.add(h);
      }
    }
    return deduped;
  }

  /// Record a play. Re-inserts at the top and increments play count.
  Future<void> recordPlay(Track track, {double completion = 0.0}) async {
    final List<HistoryEntry> history = getHistory();
    final int idx = history.indexWhere((HistoryEntry h) => h.track.id == track.id);
    final HistoryEntry entry;
    if (idx >= 0) {
      final HistoryEntry prev = history.removeAt(idx);
      entry = prev.copyWith(
        lastPlayed: DateTime.now(),
        playCount: prev.playCount + 1,
        completion: completion,
      );
    } else {
      entry = HistoryEntry(track: track, lastPlayed: DateTime.now(), completion: completion);
    }
    history.insert(0, entry);
    if (history.length > AppConstants.recentHistoryLimit) {
      history.removeRange(AppConstants.recentHistoryLimit, history.length);
    }
    await _writeList(_kHistory, history.map((HistoryEntry h) => h.toJson()).toList());

    // Synchronize playback event to Supabase when authenticated (deduplicated by 30s)
    try {
      final SupabaseService supabase = SupabaseService();
      if (supabase.isAuthenticated) {
        final DateTime now = DateTime.now();
        if (_lastRecordedTrackId != track.id ||
            _lastRecordedAt == null ||
            now.difference(_lastRecordedAt!).inSeconds >= 30) {
          _lastRecordedTrackId = track.id;
          _lastRecordedAt = now;
          unawaited(supabase.recordRecentlyPlayed(
            trackId: track.id,
            customMetadata: track.toCompact().toJson(),
          ));
        }
      }
    } catch (_) {}
  }

  /// Update completion ratio of the currently playing track without bumping count.
  Future<void> updateCompletion(String trackId, double completion) async {
    final List<HistoryEntry> history = getHistory();
    final int idx = history.indexWhere((HistoryEntry h) => h.track.id == trackId);
    if (idx < 0) return;
    history[idx] = history[idx].copyWith(completion: completion);
    await _writeList(_kHistory, history.map((HistoryEntry h) => h.toJson()).toList());
  }

  Future<void> removeFromHistory(String trackId) async {
    final List<HistoryEntry> history = getHistory()
      ..removeWhere((HistoryEntry h) => h.track.id == trackId);
    await _writeList(_kHistory, history.map((HistoryEntry h) => h.toJson()).toList());
  }

  Future<void> clearHistory() async => _requireBox.delete(_kHistory);

  // ---------------------------------------------------------------------------
  // User Data Sync & Reset
  // ---------------------------------------------------------------------------
  Future<void> setLikedTracks(List<Track> tracks) async {
    await _writeList(_kLiked, tracks.map((Track t) => t.toJson()).toList());
  }

  Future<void> setPlaylists(List<Playlist> playlists) async {
    await _persistPlaylists(playlists);
  }

  Future<void> setHistory(List<HistoryEntry> entries) async {
    final Set<String> seen = <String>{};
    final List<HistoryEntry> deduped = <HistoryEntry>[];
    for (final HistoryEntry h in entries) {
      if (seen.add(h.track.id)) {
        deduped.add(h);
      }
    }
    await _writeList(_kHistory, deduped.map((HistoryEntry h) => h.toJson()).toList());
  }

  Future<void> clearUserData() async {
    await _requireBox.delete(_kLiked);
    await _requireBox.delete(_kPlaylists);
    await _requireBox.delete(_kHistory);
    await _requireBox.delete(_kFollowedArtists);
    await _requireBox.delete(_kSavedAlbums);
  }

  // ---------------------------------------------------------------------------
  // Recent searches
  // ---------------------------------------------------------------------------
  List<String> getRecentSearches() =>
      _readList(_kSearches).map((dynamic e) => e.toString()).toList();

  Future<void> addRecentSearch(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return;
    final List<String> list = getRecentSearches()
      ..removeWhere((String s) => s.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (list.length > 12) list.removeRange(12, list.length);
    await _writeList(_kSearches, list);
  }

  Future<void> clearRecentSearches() async => _requireBox.delete(_kSearches);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------
  List<dynamic> _readList(String key) {
    final dynamic raw = _requireBox.get(key);
    if (raw == null) return <dynamic>[];
    try {
      final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
      return decoded is List ? decoded : <dynamic>[];
    } catch (e) {
      Logger.warn('Failed to read $key', error: e);
      return <dynamic>[];
    }
  }

  Future<void> _writeList(String key, List<dynamic> value) async {
    await _requireBox.put(key, jsonEncode(value));
  }
}
