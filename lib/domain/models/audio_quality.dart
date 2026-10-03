/// Requested/available audio quality tiers.
///
/// These are *requests*, not guarantees. A provider maps them onto the stream
/// qualities it actually offers; the UI never claims a level the source cannot
/// deliver (see [Track.qualityOptions]).
enum AudioQuality {
  auto,
  low,
  normal,
  high,
  veryHigh,
}

extension AudioQualityX on AudioQuality {
  /// Human label shown in settings / the player.
  String get label {
    switch (this) {
      case AudioQuality.auto:
        return 'Auto';
      case AudioQuality.low:
        return 'Low';
      case AudioQuality.normal:
        return 'Normal';
      case AudioQuality.high:
        return 'High';
      case AudioQuality.veryHigh:
        return 'Very High';
    }
  }

  /// Representative bitrate (kbps) used to estimate data consumption and to
  /// map onto provider stream tiers. `auto` has no fixed bitrate.
  int? get approxBitrateKbps {
    switch (this) {
      case AudioQuality.auto:
        return null;
      case AudioQuality.low:
        return 64;
      case AudioQuality.normal:
        return 128;
      case AudioQuality.high:
        return 256;
      case AudioQuality.veryHigh:
        return 320;
    }
  }

  /// Estimated megabytes consumed per hour at this tier.
  /// Follows the spec's "~X MB/hour" data-consumption warning.
  double? get estimatedMbPerHour {
    final int? kbps = approxBitrateKbps;
    if (kbps == null) return null;
    // kbps * 1000 bits/s * 3600 s / 8 bits-per-byte / 1024*1024 bytes-per-MB
    return (kbps * 1000 * 3600) / 8 / (1024 * 1024);
  }

  /// Estimated data warning string, e.g. "~28 MB/hour".
  String get dataEstimateLabel {
    final double? mb = estimatedMbPerHour;
    if (mb == null) return 'Adapts to your connection';
    return '~${mb.toStringAsFixed(0)} MB/hour';
  }

  String get _id => name;

  static AudioQuality fromId(String? id) {
    return AudioQuality.values.firstWhere(
      (AudioQuality q) => q.name == id,
      orElse: () => AudioQuality.auto,
    );
  }
}

/// Expose the private id for persistence without leaking it publicly.
extension AudioQualityId on AudioQuality {
  String get storageId => _id;
}
