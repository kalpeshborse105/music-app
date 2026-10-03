import 'album.dart';
import 'artist.dart';
import 'playlist.dart';
import 'track.dart';

/// Aggregated, grouped search results across a provider.
class SearchResult {
  final String query;
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  const SearchResult({
    required this.query,
    this.tracks = const <Track>[],
    this.artists = const <Artist>[],
    this.albums = const <Album>[],
    this.playlists = const <Playlist>[],
  });

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;

  static const SearchResult empty = SearchResult(query: '');

  /// Merge another provider's results into this one.
  SearchResult merge(SearchResult other) => SearchResult(
        query: query,
        tracks: <Track>[...tracks, ...other.tracks],
        artists: <Artist>[...artists, ...other.artists],
        albums: <Album>[...albums, ...other.albums],
        playlists: <Playlist>[...playlists, ...other.playlists],
      );
}
