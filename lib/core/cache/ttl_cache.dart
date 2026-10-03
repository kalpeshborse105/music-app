/// A small in-memory TTL cache (per-process, fast).
///
/// Used for hot data (recent search results, discovery sections) to avoid
/// refetching during a session.
class TtlCache<K, V> {
  final Duration ttl;
  final int maxEntries;
  final Map<K, _Entry<V>> _store = <K, _Entry<V>>{};

  TtlCache({this.ttl = const Duration(minutes: 5), this.maxEntries = 100});

  V? get(K key) {
    final _Entry<V>? entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(K key, V value, {Duration? ttl}) {
    if (_store.length >= maxEntries && !_store.containsKey(key)) {
      // Evict the oldest entry (insertion order preserved by LinkedHashMap).
      _store.remove(_store.keys.first);
    }
    _store[key] = _Entry<V>(value, ttl ?? this.ttl);
  }

  bool containsKey(K key) => get(key) != null;

  void remove(K key) => _store.remove(key);

  void clear() => _store.clear();

  void prune() {
    _store.removeWhere((_, _Entry<V> e) => e.isExpired);
  }
}

class _Entry<V> {
  final V value;
  final DateTime expiry;
  _Entry(this.value, Duration ttl) : expiry = DateTime.now().add(ttl);
  bool get isExpired => DateTime.now().isAfter(expiry);
}
