/// A single timed lyric line.
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

/// Lyrics returned by a provider or a licensed lyrics service.
///
/// Only provider-supplied / properly licensed lyrics are ever shown — we never
/// scrape lyrics from random websites.
class Lyrics {
  final String trackId;
  final String? plain;
  final List<LyricLine> synced;

  /// True when [synced] contains usable timings.
  final bool isSynced;

  final String? source;

  const Lyrics({
    required this.trackId,
    this.plain,
    this.synced = const <LyricLine>[],
    this.isSynced = false,
    this.source,
  });

  bool get isEmpty => (plain == null || plain!.trim().isEmpty) && synced.isEmpty;

  static const Lyrics unavailable = Lyrics(trackId: '', plain: null);
}
