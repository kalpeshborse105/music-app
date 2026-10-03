import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Glassmorphic container with translucent background, backdrop blur,
/// and subtle specular border highlight matching the Stitch design system.
class EchoGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blurSigma;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Gradient? gradient;

  const EchoGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppSpacing.radiusLg,
    this.backgroundColor,
    this.borderColor,
    this.blurSigma = 16.0,
    this.onTap,
    this.width,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color defaultBg = isDark
        ? AppColors.surfaceContainerHigh.withValues(alpha: 0.65)
        : AppColors.lightSurface.withValues(alpha: 0.85);
    final Color defaultBorder = isDark
        ? AppColors.borderHighlight
        : AppColors.lightBorder;

    final Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? defaultBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? defaultBorder, width: 1),
      ),
      child: child,
    );

    Widget result = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );

    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: result,
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}

/// Ambient glow backdrop orbs for hero screens and playback.
class EchoAmbientGlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double blurRadius;
  final double opacity;

  const EchoAmbientGlowOrb({
    super.key,
    required this.color,
    this.size = 280,
    this.blurRadius = 90,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: blurRadius,
              spreadRadius: blurRadius * 0.4,
            ),
          ],
        ),
      ),
    );
  }
}
