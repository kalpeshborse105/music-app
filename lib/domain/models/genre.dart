/// A browsable genre / mood with optional cover art.
class Genre {
  final String id;
  final String name;
  final String? imageUrl;

  const Genre({required this.id, required this.name, this.imageUrl});
}
