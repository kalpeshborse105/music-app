import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/utils/logger.dart';

/// Central Google AdMob manager for Kalpkrut Beats.
///
/// Debug/profile builds always use Google sample test units.
/// Release builds use Kalpkrut production units.
class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  bool _initialized = false;
  bool _initializing = false;

  static const bool _isRelease = kReleaseMode;

  /// While AdMob payment / account verify is pending, build with:
  /// `--dart-define=ADMOB_TEST=true` to confirm fill using Google sample units.
  /// Play Store AAB must ship with this OFF (production unit IDs).
  static const bool _forceTestAds = bool.fromEnvironment(
    'ADMOB_TEST',
    defaultValue: false,
  );

  // ---- Production Unit IDs (Kalpkrut Beats) ----
  static const String _prodAppId = 'ca-app-pub-4362362303618297~5047649758';
  static const String _prodBannerId = 'ca-app-pub-4362362303618297/5870078159';
  static const String _prodInterstitialId =
      'ca-app-pub-4362362303618297/3651556033';

  // ---- Google Official Test Unit IDs ----
  // Banner adaptive test unit (beats_banner_home development).
  static const String _testBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static const Duration _interstitialCooldown = Duration(minutes: 4);

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownAt;
  bool _interstitialShownThisSession = false;

  String get appId => _prodAppId;

  bool get usingTestAdUnits => _forceTestAds || !_isRelease;

  String get bannerAdUnitId {
    if (kIsWeb || !Platform.isAndroid) return '';
    return usingTestAdUnits ? _testBannerId : _prodBannerId;
  }

  String get interstitialAdUnitId {
    if (kIsWeb || !Platform.isAndroid) return '';
    return usingTestAdUnits ? _testInterstitialId : _prodInterstitialId;
  }

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isInitialized => _initialized;

  /// Privacy / consent (UMP) then one-time Mobile Ads SDK init.
  Future<void> initialize() async {
    if (!isSupported || _initialized || _initializing) return;
    _initializing = true;
    try {
      await _gatherConsentIfNeeded();
      final InitializationStatus status = await MobileAds.instance.initialize();
      _initialized = true;
      Logger.info(
        'Google Mobile Ads SDK initialized: '
        '${status.adapterStatuses.keys.join(", ")}',
      );
      loadInterstitialAd();
    } catch (e) {
      Logger.warn('Failed to initialize Google Mobile Ads SDK', error: e);
    } finally {
      _initializing = false;
    }
  }

  Future<void> _gatherConsentIfNeeded() async {
    final Completer<void> done = Completer<void>();
    final ConsentRequestParameters params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) {
              Logger.warn('UMP consent form: ${error.message}');
            }
          });
        } catch (e) {
          Logger.warn('UMP consent skipped', error: e);
        } finally {
          if (!done.isCompleted) done.complete();
        }
      },
      (FormError error) {
        Logger.warn('UMP consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  /// Preloads an interstitial for a later natural transition.
  void loadInterstitialAd() {
    if (!isSupported ||
        !_initialized ||
        _isInterstitialLoading ||
        _interstitialAd != null) {
      return;
    }
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          Logger.warn('Interstitial ad failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows a preloaded interstitial only at a suitable natural transition.
  ///
  /// Never call while audio/radio is actively playing. Frequency-capped so
  /// it does not fire on every navigation.
  bool maybeShowInterstitialAtNaturalTransition({
    required bool audioIsPlaying,
  }) {
    if (audioIsPlaying) return false;
    if (_interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }
    if (_interstitialShownThisSession) {
      final DateTime? last = _lastInterstitialShownAt;
      if (last != null &&
          DateTime.now().difference(last) < _interstitialCooldown) {
        return false;
      }
    }

    final InterstitialAd ad = _interstitialAd!;
    _interstitialAd = null;
    _interstitialShownThisSession = true;
    _lastInterstitialShownAt = DateTime.now();
    ad.show();
    return true;
  }
}
