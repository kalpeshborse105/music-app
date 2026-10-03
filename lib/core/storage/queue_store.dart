import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/models/track.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Persists the last playback queue + index + position so playback can be
/// restored after the app is killed unexpectedly (spec §8/§37).
class QueueStore {
  static const String _boxName = AppConstants.libraryBox;
  static const String _kQueue = 'saved_queue';
  static const String _kIndex = 'saved_queue_index';
  static const String _kPosition = 'saved_queue_position';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requireBox {
    final Box<dynamic>? box = _box;
    if (box == null) throw StateError('QueueStore not initialized');
    return box;
  }

  Future<void> save({
    required List<Track> queue,
    required int index,
    required Duration position,
  }) async {
    try {
      await _requireBox.put(
        _kQueue,
        jsonEncode(queue.map((Track t) => t.toJson()).toList()),
      );
      await _requireBox.put(_kIndex, index);
      await _requireBox.put(_kPosition, position.inMilliseconds);
    } catch (e) {
      Logger.warn('Failed to persist queue', error: e);
    }
  }

  ({List<Track> queue, int index, Duration position})? restore() {
    try {
      final dynamic raw = _requireBox.get(_kQueue);
      if (raw == null) return null;
      final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List || decoded.isEmpty) return null;
      final List<Track> queue = decoded
          .map((dynamic e) => Track.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final int index = (_requireBox.get(_kIndex) as num?)?.toInt() ?? 0;
      final int posMs = (_requireBox.get(_kPosition) as num?)?.toInt() ?? 0;
      return (
        queue: queue,
        index: index.clamp(0, queue.length - 1),
        position: Duration(milliseconds: posMs),
      );
    } catch (e) {
      Logger.warn('Failed to restore queue', error: e);
      return null;
    }
  }

  Future<void> clear() async {
    await _requireBox.delete(_kQueue);
    await _requireBox.delete(_kIndex);
    await _requireBox.delete(_kPosition);
  }
}
