/// Describes what a provider can and cannot do. The UI reads these flags to
/// decide which controls to show — it never assumes every provider supports
/// every feature.
class ProviderCapabilities {
  final bool streaming;
  final bool downloading;
  final bool backgroundPlayback;
  final bool lyrics;
  final bool syncedLyrics;
  final bool playlists;
  final bool favorites;
  final bool radio;
  final bool search;
  final bool browse;
  final bool recommendations;
  final bool explicitContentMetadata;
  final bool localOnly;
  final bool requiresApiKey;

  /// Quality tiers the provider can actually deliver (never faked).
  final List<String> qualityTiers;

  const ProviderCapabilities({
    this.streaming = true,
    this.downloading = false,
    this.backgroundPlayback = true,
    this.lyrics = false,
    this.syncedLyrics = false,
    this.playlists = false,
    this.favorites = false,
    this.radio = false,
    this.search = true,
    this.browse = true,
    this.recommendations = false,
    this.explicitContentMetadata = false,
    this.localOnly = false,
    this.requiresApiKey = false,
    this.qualityTiers = const <String>[],
  });
}
