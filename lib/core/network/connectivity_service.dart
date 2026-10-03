import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Tracks connectivity so the UI can show offline states without hammering the
/// network with probe requests (spec §28).
///
/// Treats the connection as online when the platform reports anything other
/// than [ConnectivityResult.none]. Actual failures are still surfaced by
/// [AppException]s from real requests.
class ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;
  bool _initialized = false;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      _apply(results);
      _sub = _connectivity.onConnectivityChanged.listen(_apply);
    } catch (_) {
      // If connectivity cannot be determined, assume online and rely on the
      // real request outcomes. Never block app startup on this.
      _isOnline = true;
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final bool online = results.any((ConnectivityResult r) =>
        r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      if (!_controller.isClosed) _controller.add(online);
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
