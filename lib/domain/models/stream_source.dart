/// A playable audio source resolved for a specific quality request.
///
/// The raw [url] is an internal detail and is never surfaced to the user in UI;
/// it is only handed to the playback engine.
class StreamSource {
  /// The direct stream URL (provider-authorized).
  final String url;

  /// Headers required by the provider (e.g. auth). Kept out of logs.
  final Map<String, String> headers;

  /// Actual bitrate of the returned stream, if the provider reports it.
  final int? bitrateKbps;

  /// Container/codec hint, e.g. `mp3`, `aac`, `ogg`.
  final String? codec;

  /// The tier this stream satisfies (best-effort mapping).
  final String? qualityTier;

  /// Whether the source supports HTTP range seeking.
  final bool supportsSeek;

  const StreamSource({
    required this.url,
    this.headers = const <String, String>{},
    this.bitrateKbps,
    this.codec,
    this.qualityTier,
    this.supportsSeek = true,
  });

  /// Estimated MB per hour for this specific stream (uses real bitrate).
  double? get estimatedMbPerHour {
    final int? kbps = bitrateKbps;
    if (kbps == null) return null;
    return (kbps * 1000 * 3600) / 8 / (1024 * 1024);
  }
}
