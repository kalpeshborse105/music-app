import 'package:flutter/foundation.dart';

import '../core/storage/library_store.dart';
import '../core/utils/logger.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/history_entry.dart';
import '../domain/models/playlist.dart';
import '../domain/models/track.dart';
import '../domain/providers/local_provider.dart';

/// UI-facing facade over [LibraryStore] plus the device music scan.
/// Notifies listeners so Library/Favorites screens update instantly.
class LibraryController extends ChangeNotifier {
  LibraryController({required LibraryStore store}) : _store = store;

  final LibraryStore _store;

  // ---- Favorites ----
  List<Track> get likedTracks => _store.getLikedTracks();
  bool isLiked(String trackId) => _store.isLiked(trackId);

  Future<void> toggleLike(Track track) async {
    await _store.toggleLiked(track);
    notifyListeners();
  }

  Future<void> setLiked(Track track, bool liked) async {
    await _store.setLiked(track, liked);
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
    final Playlist p = await _store.createPlaylist(title, description: description);
    notifyListeners();
    return p;
  }

  Future<void> renamePlaylist(String id, String title) async {
    await _store.renamePlaylist(id, title);
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _store.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await _store.addTrackToPlaylist(playlistId, track);
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _store.removeTrackFromPlaylist(playlistId, trackId);
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
    notifyListeners();
  }

  Future<void> removeFromHistory(String trackId) async {
    await _store.removeFromHistory(trackId);
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
}
