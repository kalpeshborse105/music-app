import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/utils/logger.dart';
import '../../data/services/admob_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Non-intrusive AdMob adaptive banner for the Home feed.
///
/// Collapses to [SizedBox.shrink] while loading or on no-fill (no layout jump).
/// Never overlays the mini-player or bottom navigation.
class AdMobBannerCard extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const AdMobBannerCard({
    super.key,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  State<AdMobBannerCard> createState() => _AdMobBannerCardState();
}

class _AdMobBannerCardState extends State<AdMobBannerCard> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    final AdMobService admob = AdMobService.instance;
    if (!admob.isSupported) return;

    if (!admob.isInitialized) {
      await admob.initialize();
    }
    if (!mounted) return;

    final String adUnitId = admob.bannerAdUnitId;
    if (adUnitId.isEmpty) return;

    // Standard banner (320x50) — stays in the feed, never covers mini-player /
    // nav, and does not push the home catalogue off-screen like large adaptive.
    final BannerAd banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          Logger.warn(
            'AdMob banner failed to load: ${error.message} (code ${error.code})',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );

    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceContainerHigh.withValues(alpha: 0.40)
            : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'SPONSORED',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      ),
    );
  }
}
