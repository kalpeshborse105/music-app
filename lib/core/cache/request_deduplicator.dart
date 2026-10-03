import 'dart:async';

/// Coalesces identical in-flight requests so a slow provider call is only made
/// once even if several widgets ask for the same data (spec §27/§38).
class RequestDeduplicator {
  final Map<String, Future<dynamic>> _inflight = <String, Future<dynamic>>{};

  Future<T> run<T>(String key, Future<T> Function() task) {
    final Future<dynamic>? existing = _inflight[key];
    if (existing != null) {
      return existing.then((dynamic v) => v as T);
    }
    final Future<T> future = task();
    _inflight[key] = future;
    future.whenComplete(() {
      _inflight.remove(key);
    });
    return future;
  }
}
