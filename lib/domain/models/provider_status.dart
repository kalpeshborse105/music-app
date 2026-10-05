/// Formal compliance lifecycle state for every music provider in Kalpkrut Beats.
///
/// Only [ProviderStatus.active] providers appear in the production catalog.
enum ProviderStatus {
  /// Fully authorized, operational, and active in production catalog.
  active,

  /// Restricted to local/internal development or testing.
  developmentOnly,

  /// Explicitly disabled by configuration or operational status.
  disabled,

  /// Evaluation or integration pending.
  pending,

  /// Provider abstraction in place, pending signed partner rights & licenses.
  licensePending;

  String get code {
    switch (this) {
      case ProviderStatus.active:
        return 'ACTIVE';
      case ProviderStatus.developmentOnly:
        return 'DEVELOPMENT_ONLY';
      case ProviderStatus.disabled:
        return 'DISABLED';
      case ProviderStatus.pending:
        return 'PENDING';
      case ProviderStatus.licensePending:
        return 'LICENSE_PENDING';
    }
  }

  bool get isProductionActive => this == ProviderStatus.active;
}
