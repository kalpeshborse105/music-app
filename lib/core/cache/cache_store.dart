import 'dart:convert';

import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Persistent TTL cache backed by Hive (metadata, search, provider responses).
///
/// Stores JSON-encoded values with an expiry timestamp. Respects per-entry TTLs
/// (short for search, medium for entities) — see spec §11. It must never be used
/// to store restricted provider content; only metadata we are allowed to cache.
class CacheStore {
  static const String _boxName = AppConstants.cacheBox;
  Box<dynamic>? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
    await prune();
  }

  Box<dynamic> get _requireBox {
    final Box<dynamic>? box = _box;
    if (box == null) {
      throw StateError('CacheStore not initialized. Call init() first.');
    }
    return box;
  }

  /// Read a cached JSON map (returns null on miss/expiry).
  Map<String, dynamic>? getJson(String key) {
    final Map<String, dynamic>? entry = _readEntry(key);
    if (entry == null) return null;
    final String? raw = entry['v'] as String?;
    if (raw == null) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (e) {
      Logger.warn('Cache decode failed for $key', error: e);
      _requireBox.delete(key);
      return null;
    }
  }

  /// Read a cached JSON list.
  List<dynamic>? getList(String key) {
    final Map<String, dynamic>? entry = _readEntry(key);
    if (entry == null) return null;
    final String? raw = entry['v'] as String?;
    if (raw == null) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      return null;
    } catch (_) {
      _requireBox.delete(key);
      return null;
    }
  }

  /// Store any JSON-encodable value with a TTL.
  Future<void> set(String key, Object? value, Duration ttl) async {
    final Map<String, dynamic> entry = <String, dynamic>{
      'e': DateTime.now().add(ttl).millisecondsSinceEpoch,
      'v': jsonEncode(value),
    };
    await _requireBox.put(key, entry);
  }

  Future<void> remove(String key) async => _requireBox.delete(key);

  Future<void> clear() async => _requireBox.clear();

  /// All cache keys currently stored (including expired — caller may filter).
  Iterable<dynamic> get keys => _requireBox.keys;

  /// Remove every expired entry. Cheap enough to run on startup.
  Future<void> prune() async {
    final Box<dynamic> box = _requireBox;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<dynamic> expired = <dynamic>[];
    for (final dynamic key in box.keys) {
      final dynamic raw = box.get(key);
      if (raw is Map && (raw['e'] as num?) != null) {
        if ((raw['e'] as num).toInt() < now) expired.add(key);
      }
    }
    for (final dynamic key in expired) {
      await box.delete(key);
    }
    if (expired.isNotEmpty) {
      Logger.debug('Pruned ${expired.length} expired cache entries');
    }
  }

  /// Rough size in bytes (for the settings storage screen).
  int sizeBytes() {
    final Box<dynamic> box = _requireBox;
    int bytes = 0;
    for (final dynamic value in box.values) {
      bytes += jsonEncode(value).length;
    }
    return bytes;
  }

  int get entryCount => _requireBox.length;

  Map<String, dynamic>? _readEntry(String key) {
    final dynamic raw = _requireBox.get(key);
    if (raw is! Map) return null;
    final num? expiry = raw['e'] as num?;
    if (expiry == null) return null;
    if (expiry.toInt() < DateTime.now().millisecondsSinceEpoch) {
      _requireBox.delete(key);
      return null;
    }
    return raw.cast<String, dynamic>();
  }
}
