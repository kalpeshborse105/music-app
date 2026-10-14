import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Renders track/album/artist artwork with memory + disk caching, a graceful
/// shimmer placeholder, deterministic gradient fallback, and Stitch aesthetics.
class Artwork extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final IconData fallbackIcon;
  final String? semanticsLabel;
  final BoxFit fit;
  final bool showGlow;
  final Color? glowColor;

  /// Cache of URLs that have previously failed or are known to lack CORS on Web.
  /// Prevents console flooding and infinite retry loops.
  static final Set<String> _failedUrls = <String>{};

  static bool isCorsBlockedOnWeb(String? u) {
    if (!kIsWeb || u == null) return false;
    if (u.contains('archive.org/services/img')) return true;
    return _failedUrls.contains(u);
  }

  const Artwork({
    super.key,
    required this.url,
    this.size = 48,
    this.radius = AppSpacing.radiusSm,
    this.fallbackIcon = Icons.music_note_rounded,
    this.semanticsLabel,
    this.fit = BoxFit.cover,
    this.showGlow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBlocked = isCorsBlockedOnWeb(url);
    final bool isRemote = !isBlocked &&
        url != null && (url!.startsWith('http://') || url!.startsWith('https://'));

    final Widget imageWidget = !isRemote
        ? _fallback()
        : CachedNetworkImage(
            imageUrl: url!,
            width: size,
            height: size,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 200),
            memCacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
            placeholder: (BuildContext c, String? _) => _placeholder(c),
            errorWidget: (BuildContext c, String? failedUrl, Object __) {
              if (failedUrl != null && failedUrl.isNotEmpty) {
                _failedUrls.add(failedUrl);
              }
              return _fallback();
            },
          );

    final Widget clippedChild = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageWidget,
      ),
    );

    if (!showGlow) {
      return Semantics(
        label: semanticsLabel,
        image: true,
        child: clippedChild,
      );
    }

    final Color glow = glowColor ?? AppColors.primary;

    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius * 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glow.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          clippedChild,
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: SizedBox(
            width: size * 0.35,
            height: size * 0.35,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.secondaryLight.withValues(alpha: 0.7),
            ),
          ),
        ),
      );

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF2A2A3E),
            Color(0xFF141420),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: Colors.white.withValues(alpha: 0.75),
        size: (size * 0.42).clamp(16.0, 72.0),
      ),
    );
  }
}
