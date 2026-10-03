import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/audio_quality.dart';

/// User settings backed by shared_preferences. Exposes a [ChangeNotifier] so
/// theme + data-saver changes propagate instantly through the app.
class SettingsStore extends ChangeNotifier {
  static const String _kQuality = 'set_quality';
  static const String _kStreamQuality = 'set_stream_quality';
  static const String _kDownloadQuality = 'set_download_quality';
  static const String _kDataSaver = 'set_data_saver';
  static const String _kAutoplay = 'set_autoplay';
  static const String _kCrossfade = 'set_crossfade';
  static const String _kNormalize = 'set_normalize';
  static const String _kThemeMode = 'set_theme_mode';
  static const String _kWifiOnlyDownload = 'set_wifi_only';
  static const String _kAnalytics = 'set_analytics';
  static const String _kPersonalization = 'set_personalization';
  static const String _kSaveHistory = 'set_save_history';
  static const String _kAutoplayRadio = 'set_autoplay_radio';
  static const String _kArtistLabels = 'set_show_artist_labels';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final SharedPreferences? p = _prefs;
    if (p == null) throw StateError('SettingsStore not initialized');
    return p;
  }

  // ---- Playback ----
  AudioQuality get streamQuality =>
      AudioQualityX.fromId(_p.getString(_kStreamQuality));

  set streamQuality(AudioQuality value) {
    _p.setString(_kStreamQuality, value.storageId);
    notifyListeners();
  }

  AudioQuality get downloadQuality =>
      AudioQualityX.fromId(_p.getString(_kDownloadQuality));

  set downloadQuality(AudioQuality value) {
    _p.setString(_kDownloadQuality, value.storageId);
    notifyListeners();
  }

  /// Legacy combined quality getter (falls back to stream quality).
  AudioQuality get quality => AudioQualityX.fromId(_p.getString(_kQuality));

  bool get dataSaver => _p.getBool(_kDataSaver) ?? false;

  set dataSaver(bool value) {
    _p.setBool(_kDataSaver, value);
    notifyListeners();
  }

  bool get autoplay => _p.getBool(_kAutoplay) ?? true;

  set autoplay(bool value) {
    _p.setBool(_kAutoplay, value);
    notifyListeners();
  }

  /// Only meaningful when the engine + provider both support crossfade.
  bool get crossfade => _p.getBool(_kCrossfade) ?? false;

  set crossfade(bool value) {
    _p.setBool(_kCrossfade, value);
    notifyListeners();
  }

  bool get normalizeVolume => _p.getBool(_kNormalize) ?? false;

  set normalizeVolume(bool value) {
    _p.setBool(_kNormalize, value);
    notifyListeners();
  }

  /// When a track ends, continue with artist/similar radio.
  bool get autoplayRadio => _p.getBool(_kAutoplayRadio) ?? true;

  set autoplayRadio(bool value) {
    _p.setBool(_kAutoplayRadio, value);
    notifyListeners();
  }

  // ---- Downloads ----
  bool get wifiOnlyDownload => _p.getBool(_kWifiOnlyDownload) ?? true;

  set wifiOnlyDownload(bool value) {
    _p.setBool(_kWifiOnlyDownload, value);
    notifyListeners();
  }

  // ---- Appearance ----
  ThemeMode get themeMode {
    final String? raw = _p.getString(_kThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  set themeMode(ThemeMode mode) {
    _p.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  // ---- Privacy ----
  bool get analyticsEnabled => _p.getBool(_kAnalytics) ?? false;

  set analyticsEnabled(bool value) {
    _p.setBool(_kAnalytics, value);
    notifyListeners();
  }

  bool get personalizationEnabled => _p.getBool(_kPersonalization) ?? true;

  set personalizationEnabled(bool value) {
    _p.setBool(_kPersonalization, value);
    notifyListeners();
  }

  bool get saveHistory => _p.getBool(_kSaveHistory) ?? true;

  set saveHistory(bool value) {
    _p.setBool(_kSaveHistory, value);
    notifyListeners();
  }

  bool get showArtistLabels => _p.getBool(_kArtistLabels) ?? true;

  set showArtistLabels(bool value) {
    _p.setBool(_kArtistLabels, value);
    notifyListeners();
  }

  /// Effective quality to request given data-saver mode.
  AudioQuality get effectiveStreamQuality {
    if (dataSaver && streamQuality == AudioQuality.auto) {
      return AudioQuality.low;
    }
    if (dataSaver && (streamQuality.index > AudioQuality.normal.index)) {
      return AudioQuality.normal;
    }
    return streamQuality;
  }
}
