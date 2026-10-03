/// A normalized artist, independent of any specific provider.
class Artist {
  /// Globally unique id, namespaced by provider: `jamendo:12345`.
  final String id;

  /// The provider that owns this record.
  final String providerId;

  /// The id within the owning provider.
  final String providerArtistId;

  final String name;
  final String? imageUrl;

  /// Optional follower/popularity hint (0-100), provider dependent.
  final int? popularity;

  const Artist({
    required this.id,
    required this.providerId,
    required this.providerArtistId,
    required this.name,
    this.imageUrl,
    this.popularity,
  });

  factory Artist.local(String name) => Artist(
        id: 'local:artist:$name',
        providerId: 'local',
        providerArtistId: name,
        name: name,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'providerArtistId': providerArtistId,
        'name': name,
        'imageUrl': imageUrl,
        'popularity': popularity,
      };

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] as String? ?? '',
        providerId: json['providerId'] as String? ?? '',
        providerArtistId: json['providerArtistId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown artist',
        imageUrl: json['imageUrl'] as String?,
        popularity: (json['popularity'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) => other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
