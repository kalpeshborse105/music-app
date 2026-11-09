import '../../domain/models/catalog_section.dart';

/// Pure cache-health rules for catalogue track payloads (R8).
///
/// Metadata-only lists (many sections, zero items) must not be treated as a
/// healthy track cache — that poisoned Home disk and showed empty shelves.
bool catalogTrackCacheLooksHealthy(List<CatalogSection> sections) {
  if (sections.isEmpty) return false;
  final int filled =
      sections.where((CatalogSection s) => s.items.isNotEmpty).length;
  if (filled < 1) return false;
  if (sections.length >= 5) {
    return filled >= (sections.length / 5).ceil();
  }
  return true;
}

/// When network returns empty items, keep prior live tracks unless the
/// source URL changed. Failed/unavailable Jio must not wipe good shelves.
CatalogSection mergeCatalogSectionTracks({
  required CatalogSection fresh,
  required CatalogSection? cached,
}) {
  if (fresh.items.isNotEmpty) return fresh;
  if (cached == null || cached.items.isEmpty || cached.isMock) return fresh;
  if (cached.providerStatus == 'offline_mock') return fresh;
  if (fresh.sourceUrl.isNotEmpty &&
      cached.sourceUrl.isNotEmpty &&
      fresh.sourceUrl != cached.sourceUrl) {
    return fresh;
  }
  return fresh.copyWith(
    items: cached.items,
    itemCount: cached.items.length,
    isMock: false,
    providerStatus:
        (fresh.providerStatus == 'unavailable' ||
                fresh.providerStatus == 'offline_mock' ||
                fresh.isMock)
            ? (cached.providerStatus == 'ok' ? 'ok' : cached.providerStatus)
            : fresh.providerStatus,
  );
}
