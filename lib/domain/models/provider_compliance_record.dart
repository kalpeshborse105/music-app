import 'provider_status.dart';

/// Compliance record describing rights, capabilities, licensing, and
/// distribution terms for an audio provider in EchoFlow Music.
class ProviderComplianceRecord {
  final String provider;
  final String displayName;
  final bool enabled;
  final bool searchSupported;
  final bool streamSupported;
  final bool downloadSupported;
  final String commercialUseStatus;
  final String backgroundPlaybackStatus;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
  final bool attributionRequired;
  final ProviderStatus status;

  const ProviderComplianceRecord({
    required this.provider,
    required this.displayName,
    required this.enabled,
    required this.searchSupported,
    required this.streamSupported,
    required this.downloadSupported,
    required this.commercialUseStatus,
    required this.backgroundPlaybackStatus,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
    required this.attributionRequired,
    required this.status,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'provider': provider,
        'displayName': displayName,
        'enabled': enabled,
        'searchSupported': searchSupported,
        'streamSupported': streamSupported,
        'downloadSupported': downloadSupported,
        'commercialUseStatus': commercialUseStatus,
        'backgroundPlaybackStatus': backgroundPlaybackStatus,
        'license': license,
        'licenseUrl': licenseUrl,
        'sourceUrl': sourceUrl,
        'attributionRequired': attributionRequired,
        'status': status.code,
      };
}
