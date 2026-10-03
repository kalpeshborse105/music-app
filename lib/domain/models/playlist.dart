import 'track.dart';

/// Where a playlist came from. Provider-owned playlists must stay provider
/// owned; only user playlists are stored locally.
enum PlaylistSource { user, provider, system }

class Playlist {
  final String id;
  final String title;
  final String? description;
  final String? artworkUrl;
  final PlaylistSource source;
  final String? providerId;
  final List<Track> tracks;
  final int trackCount;
  final DateTime? updatedAt;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.artworkUrl,
    this.source = PlaylistSource.user,
    this.providerId,
    this.tracks = const <Track>[],
    this.trackCount = 0,
    this.updatedAt,
  });

  Playlist copyWith({
    String? title,
    String? description,
    String? artworkUrl,
    List<Track>? tracks,
    int? trackCount,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      source: source,
      providerId: providerId,
      tracks: tracks ?? this.tracks,
      trackCount: trackCount ?? this.trackCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'artworkUrl': artworkUrl,
        'source': source.name,
        'providerId': providerId,
        'tracks': tracks.map((Track t) => t.toJson()).toList(),
        'trackCount': trackCount,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Playlist',
        description: json['description'] as String?,
        artworkUrl: json['artworkUrl'] as String?,
        source: PlaylistSource.values.firstWhere(
          (PlaylistSource s) => s.name == json['source'],
          orElse: () => PlaylistSource.user,
        ),
        providerId: json['providerId'] as String?,
        tracks: ((json['tracks'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => Track.fromJson(e as Map<String, dynamic>))
            .toList(),
        trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}
