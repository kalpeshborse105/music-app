import 'artist.dart';

/// A normalized album / single / EP.
class Album {
  final String id;
  final String providerId;
  final String providerAlbumId;
  final String title;
  final List<Artist> artists;
  final String? artworkUrl;
  final int? year;
  final int? trackCount;

  const Album({
    required this.id,
    required this.providerId,
    required this.providerAlbumId,
    required this.title,
    this.artists = const <Artist>[],
    this.artworkUrl,
    this.year,
    this.trackCount,
  });

  String get artistNames =>
      artists.isEmpty ? 'Unknown artist' : artists.map((Artist a) => a.name).join(', ');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'providerAlbumId': providerAlbumId,
        'title': title,
        'artists': artists.map((Artist a) => a.toJson()).toList(),
        'artworkUrl': artworkUrl,
        'year': year,
        'trackCount': trackCount,
      };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String? ?? '',
        providerId: json['providerId'] as String? ?? '',
        providerAlbumId: json['providerAlbumId'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown album',
        artists: ((json['artists'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => Artist.fromJson(e as Map<String, dynamic>))
            .toList(),
        artworkUrl: json['artworkUrl'] as String?,
        year: (json['year'] as num?)?.toInt(),
        trackCount: (json['trackCount'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) => other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
