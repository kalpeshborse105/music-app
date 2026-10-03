import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/models/track.dart';
import '../utils/logger.dart';

/// Metadata for a provider-authorized offline track.
class DownloadRecord {
  final Track track;
  final String filePath;
  final int sizeBytes;
  final String qualityTier;
  final DateTime downloadedAt;

  const DownloadRecord({
    required this.track,
    required this.filePath,
    required this.sizeBytes,
    required this.qualityTier,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'track': track.toJson(),
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'qualityTier': qualityTier,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
        track: Track.fromJson(json['track'] as Map<String, dynamic>),
        filePath: json['filePath'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        qualityTier: json['qualityTier'] as String? ?? '',
        downloadedAt:
            DateTime.tryParse(json['downloadedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Persists which tracks have been downloaded for offline playback.
///
/// Only providers that explicitly permit downloading (per [ProviderCapabilities])
/// ever reach this store — the UI hides the download action otherwise (spec §12).
class DownloadStore {
  static const String _boxName = 'echoflow_downloads';
  Box<dynamic>? _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requireBox {
    final Box<dynamic>? box = _box;
    if (box == null) throw StateError('DownloadStore not initialized');
    return box;
  }

  List<DownloadRecord> all() {
    final List<DownloadRecord> out = <DownloadRecord>[];
    for (final dynamic raw in _requireBox.values) {
      try {
        final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is Map) {
          out.add(DownloadRecord.fromJson(decoded.cast<String, dynamic>()));
        }
      } catch (e) {
        Logger.warn('Skipping corrupt download record', error: e);
      }
    }
    out.sort((DownloadRecord a, DownloadRecord b) =>
        b.downloadedAt.compareTo(a.downloadedAt));
    return out;
  }

  DownloadRecord? get(String trackId) {
    final dynamic raw = _requireBox.get(trackId);
    if (raw == null) return null;
    try {
      final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        return DownloadRecord.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  bool contains(String trackId) => _requireBox.containsKey(trackId);

  Future<void> put(DownloadRecord record) =>
      _requireBox.put(record.track.id, jsonEncode(record.toJson()));

  Future<void> remove(String trackId) => _requireBox.delete(trackId);

  Future<void> clear() => _requireBox.clear();

  int totalBytes() =>
      all().fold<int>(0, (int sum, DownloadRecord r) => sum + r.sizeBytes);
}
