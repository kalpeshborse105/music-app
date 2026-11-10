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

/// Statuses that mean the API intentionally returned no usable tracks.
/// Do not resurrect older disk Mix/playlist clones over these.
bool catalogFreshStatusBlocksTrackRestore(String providerStatus) {
  final String s = providerStatus.trim().toLowerCase();
  return s == 'unresolved_mix' || s == 'unavailable' || s == 'error';
}

/// Admin refresh snackbar severity derived from API refresh payload fields.
enum CatalogRefreshSnackSeverity { success, warning, error }

/// Message + severity for a single-section Admin refresh result.
class CatalogRefreshSnackFeedback {
  const CatalogRefreshSnackFeedback({
    required this.severity,
    required this.message,
  });

  final CatalogRefreshSnackSeverity severity;
  final String message;
}

/// Build honest Admin refresh snackbar copy from provider fields.
///
/// Success only when the shelf is live (`ok`), not mock, and has tracks.
CatalogRefreshSnackFeedback catalogRefreshSnackFeedback({
  required String displayTitle,
  required String providerStatus,
  required bool isMock,
  required int trackCount,
  String? lastError,
}) {
  final String title = displayTitle.trim().isEmpty ? 'Section' : displayTitle.trim();
  final String status = providerStatus.trim().toLowerCase();
  final String err = (lastError ?? '').trim();
  final String errSuffix =
      err.isNotEmpty && !err.startsWith('{') ? ' — $err' : '';

  if (isMock || status == 'offline_mock') {
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.warning,
      message:
          'Refresh returned mock/offline data for "$title" (0 reliable tracks).',
    );
  }
  if (status == 'unresolved_mix') {
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.warning,
      message:
          'Mix unresolved for "$title" — no tracks substituted$errSuffix',
    );
  }
  if (status == 'unavailable' || status == 'error') {
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.error,
      message:
          'Refresh failed for "$title" (${status.toUpperCase()})$errSuffix',
    );
  }
  if (status == 'stale') {
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.warning,
      message:
          'Refresh incomplete for "$title" — serving stale cache ($trackCount tracks)$errSuffix',
    );
  }
  if (status == 'pending' || status == 'provisional') {
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.warning,
      message: 'Refresh still pending for "$title"',
    );
  }
  // Treat blank/ok as success path only when tracks were returned.
  if (status.isEmpty || status == 'ok') {
    if (trackCount <= 0) {
      return CatalogRefreshSnackFeedback(
        severity: CatalogRefreshSnackSeverity.warning,
        message: 'Refreshed "$title" but found 0 tracks',
      );
    }
    return CatalogRefreshSnackFeedback(
      severity: CatalogRefreshSnackSeverity.success,
      message: 'Refreshed "$title" ($trackCount tracks)',
    );
  }
  return CatalogRefreshSnackFeedback(
    severity: CatalogRefreshSnackSeverity.warning,
    message:
        'Refreshed "$title" with status ${status.toUpperCase()} ($trackCount tracks)$errSuffix',
  );
}

/// When network returns empty items, keep prior live tracks unless the
/// source URL changed or the API reported an honest failure / unresolved Mix.
/// Trusted stale Mixes that still include track payloads are unchanged
/// (`fresh.items.isNotEmpty` returns [fresh] immediately).
CatalogSection mergeCatalogSectionTracks({
  required CatalogSection fresh,
  required CatalogSection? cached,
}) {
  if (fresh.items.isNotEmpty) return fresh;
  if (cached == null || cached.items.isEmpty || cached.isMock) return fresh;
  if (cached.providerStatus == 'offline_mock') return fresh;
  // Honor API Mix trust / upstream failure — never restore untrusted disk clones.
  if (catalogFreshStatusBlocksTrackRestore(fresh.providerStatus)) {
    return fresh;
  }
  if (fresh.sourceUrl.isNotEmpty &&
      cached.sourceUrl.isNotEmpty &&
      fresh.sourceUrl != cached.sourceUrl) {
    return fresh;
  }
  return fresh.copyWith(
    items: cached.items,
    itemCount: cached.items.length,
    isMock: false,
    providerStatus: fresh.isMock
        ? (cached.providerStatus == 'ok' ? 'ok' : cached.providerStatus)
        : fresh.providerStatus,
  );
}
