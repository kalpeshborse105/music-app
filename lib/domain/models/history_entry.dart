import 'track.dart';

/// A single "recently played" record (privacy-first: stays on device).
class HistoryEntry {
  final Track track;
  final DateTime lastPlayed;
  final int playCount;

  /// 0.0..1.0 completion ratio of the most recent play (for Continue Listening
  /// and the recommendation engine).
  final double completion;

  const HistoryEntry({
    required this.track,
    required this.lastPlayed,
    this.playCount = 1,
    this.completion = 0.0,
  });

  HistoryEntry copyWith({
    DateTime? lastPlayed,
    int? playCount,
    double? completion,
  }) {
    return HistoryEntry(
      track: track,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      playCount: playCount ?? this.playCount,
      completion: completion ?? this.completion,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'track': track.toJson(),
        'lastPlayed': lastPlayed.toIso8601String(),
        'playCount': playCount,
        'completion': completion,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        track: Track.fromJson(json['track'] as Map<String, dynamic>),
        lastPlayed:
            DateTime.tryParse(json['lastPlayed'] as String? ?? '') ?? DateTime.now(),
        playCount: (json['playCount'] as num?)?.toInt() ?? 1,
        completion: (json['completion'] as num?)?.toDouble() ?? 0.0,
      );
}
