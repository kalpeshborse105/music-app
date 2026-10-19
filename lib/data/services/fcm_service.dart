import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import 'supabase_service.dart';

/// Registers device FCM tokens with the music-api and handles push taps.
/// Safe when Firebase / google-services.json is not configured yet.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _ready = false;
  String? _token;

  /// Optional callback when user taps a push (target_type / target_id / image).
  void Function(Map<String, dynamic> data)? onNotificationOpen;

  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      final RemoteMessage? initial = await messaging.getInitialMessage();
      if (initial != null) {
        _onOpened(initial);
      }
      _token = await messaging.getToken();
      messaging.onTokenRefresh.listen((String t) {
        _token = t;
        _registerToken(t);
      });
      if (_token != null && _token!.isNotEmpty) {
        await _registerToken(_token!);
      }
      _ready = true;
      Logger.info('FCM ready (token registered=${_token != null})');
    } catch (e) {
      // Missing google-services.json / Firebase Android app — app still runs.
      Logger.warn('FCM init skipped (add Android Firebase + google-services.json)', error: e);
      _ready = false;
    }
  }

  bool get isReady => _ready;
  String? get token => _token;

  void _onForeground(RemoteMessage message) {
    Logger.info('FCM foreground: ${message.notification?.title}');
  }

  void _onOpened(RemoteMessage message) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);
    onNotificationOpen?.call(data);
  }

  Future<void> _registerToken(String token) async {
    final String base = AppConfig.customApiUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return;
    final String? userId = SupabaseService().currentUser?.id;
    try {
      await http
          .post(
            Uri.parse('$base/api/fcm/token'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'token': token,
              'user_id': userId ?? '',
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      Logger.warn('FCM token register failed', error: e);
    }
  }

  /// Re-bind token after login so admin can target this user.
  Future<void> syncUser() async {
    if (_token == null || _token!.isEmpty) return;
    await _registerToken(_token!);
  }
}
