/// Generic cursor/offset paginated result. Supports cursor-based pagination
/// where a provider offers it, and offset pagination otherwise.
class PagedResult<T> {
  final List<T> items;

  /// Opaque cursor to fetch the next page, if the provider supports cursors.
  final String? nextCursor;

  /// Offset to request next when cursors are not available.
  final int? nextOffset;

  final int total;
  final bool hasMore;

  const PagedResult({
    required this.items,
    this.nextCursor,
    this.nextOffset,
    this.total = 0,
    this.hasMore = false,
  });

  const PagedResult.empty()
      : items = const <Never>[],
        nextCursor = null,
        nextOffset = null,
        total = 0,
        hasMore = false;
}
