import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import 'supabase_service.dart';

const String _kPushChannelId = 'kalpkrut_beats_push';
const String _kPushChannelName = 'Kalpkrut Beats';

/// Top-level background handler (must be a top-level or static function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Registers device FCM tokens with the music-api and handles push taps.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _ready = false;
  String? _token;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Optional callback when user taps a push (target_type / target_id / image).
  void Function(Map<String, dynamic> data)? onNotificationOpen;

  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();
      await _ensureAndroidChannel();

      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
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
      Logger.warn(
        'FCM init skipped (check google-services.json / Firebase)',
        error: e,
      );
      _ready = false;
    }
  }

  bool get isReady => _ready;
  String? get token => _token;

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_stat_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings init = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final dynamic decoded = jsonDecode(payload);
          if (decoded is Map) {
            onNotificationOpen?.call(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
    );
  }

  Future<void> _ensureAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _kPushChannelId,
      _kPushChannelName,
      description: 'Song alerts, admin broadcasts, and app updates',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _onForeground(RemoteMessage message) async {
    Logger.info('FCM foreground: ${message.notification?.title}');
    final RemoteNotification? n = message.notification;
    if (n == null) return;
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _kPushChannelId,
      _kPushChannelName,
      channelDescription: 'Song alerts, admin broadcasts, and app updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notification',
    );
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: android),
      payload: jsonEncode(message.data),
    );
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
