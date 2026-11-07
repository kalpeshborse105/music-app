import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';

/// Lightweight anonymous product pulse (install + session time).
///
/// Fire-and-forget only — never throws into UI. True uninstall counts come from
/// Play Console; we approximate churn via stale [last_seen] on the API.
class UsagePulseService with WidgetsBindingObserver {
  UsagePulseService._();
  static final UsagePulseService instance = UsagePulseService._();

  static const String _kDeviceId = 'usage_pulse_device_id';
  static const String _kInstallSent = 'usage_pulse_install_sent';
  static const String _kMemberSince = 'usage_pulse_member_since';

  bool _started = false;
  String? _deviceId;
  DateTime? _sessionStartedAt;
  Timer? _heartbeat;
  int _sessionSeconds = 0;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_kDeviceId);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = _newDeviceId();
        await prefs.setString(_kDeviceId, _deviceId!);
      }
      if (!prefs.containsKey(_kMemberSince)) {
        await prefs.setInt(
          _kMemberSince,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }

      WidgetsBinding.instance.addObserver(this);
      await _onSessionStart(prefs);
      _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) {
        unawaited(_sendHeartbeat());
      });
    } catch (e) {
      Logger.warn('UsagePulse start skipped', error: e);
    }
  }

  Future<void> dispose() async {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _flushSessionEnd();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onForeground());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushSessionEnd());
    }
  }

  Future<void> _onSessionStart(SharedPreferences prefs) async {
    _sessionStartedAt = DateTime.now();
    _sessionSeconds = 0;
    final bool first = prefs.getBool(_kInstallSent) != true;
    if (first) {
      await _post('install', <String, dynamic>{'first_open': true});
      await prefs.setBool(_kInstallSent, true);
    }
    await _post('session_start', <String, dynamic>{});
  }

  Future<void> _onForeground() async {
    if (_sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      await _post('session_start', <String, dynamic>{});
    }
  }

  Future<void> _sendHeartbeat() async {
    _accumulate();
    await _post('heartbeat', <String, dynamic>{
      'session_seconds': _sessionSeconds,
    });
  }

  Future<void> _flushSessionEnd() async {
    _accumulate();
    if (_sessionSeconds <= 0 && _sessionStartedAt == null) return;
    await _post('session_end', <String, dynamic>{
      'session_seconds': _sessionSeconds,
    });
    _sessionStartedAt = null;
    _sessionSeconds = 0;
  }

  void _accumulate() {
    final DateTime? start = _sessionStartedAt;
    if (start == null) return;
    final int add = DateTime.now().difference(start).inSeconds;
    _sessionSeconds += add;
    _sessionStartedAt = DateTime.now();
  }

  Future<void> _post(String event, Map<String, dynamic> extra) async {
    final String base = AppConfig.customApiUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty || _deviceId == null) return;
    try {
      await http
          .post(
            Uri.parse('$base/api/analytics/event'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'event': event,
              'device_id': _deviceId,
              'platform': defaultTargetPlatform.name,
              'app_version': '1.0.28+29',
              'ts': DateTime.now().toUtc().toIso8601String(),
              ...extra,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Never surface to UI — offline / API blips are fine.
      Logger.debug('UsagePulse $event skipped: $e');
    }
  }

  String _newDeviceId() {
    final Random r = Random.secure();
    final String hex = List<String>.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'kb_$hex';
  }

  /// Stable local member-since unix for Profile when profile has no created_at.
  static Future<int?> localMemberSinceUnix() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kMemberSince);
    } catch (_) {
      return null;
    }
  }
}
