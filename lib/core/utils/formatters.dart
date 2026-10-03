/// Small formatting helpers used across the UI.
class Formatters {
  Formatters._();

  /// mm:ss or h:mm:ss.
  static String duration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);
    final String mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// "3 min ago", "2 h ago", "5 d ago".
  static String relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${(diff.inDays / 7).floor()} w ago';
  }

  /// Greeting based on the time of day.
  static String greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Compact track count, e.g. "12 songs".
  static String trackCount(int n) => n == 1 ? '1 song' : '$n songs';
}
