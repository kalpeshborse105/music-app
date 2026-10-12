import 'package:flutter/material.dart';

/// Kalpkrut Beats brand palette matching the Stitch design system.
/// Nocturnal depth, bioluminescent violet & cyan accents, and glassmorphic surfaces.
class AppColors {
  AppColors._();

  // Chromatic Accents (Stitch Design System)
  static const Color primary = Color(0xFF8B5CF6); // Electric Violet
  static const Color electricViolet = primary;
  static const Color primaryLight = Color(0xFFD0BCFF);
  static const Color primaryFixedDim = primaryLight;
  static const Color primaryDark = Color(0xFF5516BE);
  static const Color primaryContainer = Color(0xFFA078FF);
  static const Color onPrimary = Color(0xFF3C0091);
  static const Color onPrimaryContainer = Color(0xFF340080);

  static const Color secondary = Color(0xFF06B6D4); // Neon Cyan
  static const Color neonCyan = secondary;
  static const Color secondaryLight = Color(0xFF4CD7F6);
  static const Color secondaryContainer = Color(0xFF03B5D3);
  static const Color onSecondary = Color(0xFF003640);
  static const Color onSecondaryContainer = Color(0xFF00424E);

  static const Color tertiary = Color(0xFFEC4899); // Hyper Magenta
  static const Color hyperMagenta = tertiary;
  static const Color tertiaryLight = Color(0xFFFFB0CD);
  static const Color tertiaryContainer = Color(0xFFF751A1);
  static const Color onTertiary = Color(0xFF640039);

  // Surface Aliases
  static const Color background = Color(0xFF0F131C);
  static const Color onSurface = Color(0xFFDFE2EE);
  static const Color onSurfaceVariant = Color(0xFFCBC3D7);

  // Dark Nocturnal Surfaces (Stitch Hierarchy)
  static const Color darkBg = Color(0xFF0F131C);
  static const Color darkCanvas = Color(0xFF0B0F17);
  static const Color surfaceDim = Color(0xFF0F131C);
  static const Color surfaceBright = Color(0xFF353942);

  static const Color surfaceContainerLowest = Color(0xFF0A0E16);
  static const Color surfaceContainerLow = Color(0xFF181C24);
  static const Color surfaceContainer = Color(0xFF1C2028);
  static const Color surfaceContainerHigh = Color(0xFF262A33);
  static const Color surfaceContainerHighest = Color(0xFF31353E);

  // Dark Borders & Outlines
  static const Color outline = Color(0xFF958EA0);
  static const Color outlineVariant = Color(0xFF494454);
  static const Color borderSubtle = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const Color borderHighlight = Color(0x26FFFFFF); // rgba(255,255,255,0.15)

  // Light Surfaces & Elevated Tokens (Stitch Dedicated Light Theme)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFF1F5F9);
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFCBD5E1);
  static const Color lightDivider = Color(0xFFE2E8F0);

  // Dedicated Light Accents (Optimized contrast for light backgrounds)
  static const Color lightPrimaryAccent = Color(0xFF7C3AED);
  static const Color lightSecondaryAccent = Color(0xFF0891B2);
  static const Color lightTertiaryAccent = Color(0xFFDB2777);
  static const Color lightPlayerSurface = Color(0xF7FFFFFF);
  static const Color lightNavSurface = Color(0xF7F8FAFC);
  static const Color lightSelectedNav = Color(0xFF7C3AED);
  static const Color lightInputBackground = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFDFE2EE);
  static const Color textSecondaryDark = Color(0xFFCBC3D7);
  static const Color textMutedDark = Color(0xFF958EA0);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF64748B);

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color emerald = success;
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFFFB4AB);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightSuccess = Color(0xFF059669);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);

  // Glassmorphic Surface Tints
  static const Color glassSurfaceDark = Color(0xCC1C2028); // 80% opacity
  static const Color glassSurfaceHigh = Color(0xE6262A33); // 90% opacity
  static const Color glassSurfacePill = Color(0xD9181C24); // 85% opacity

  // Stitch Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF8B5CF6), Color(0xFF06B6D4)],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFA078FF), Color(0xFF03B5D3)],
  );

  static const LinearGradient likedSongsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF751A1), Color(0xFFA078FF), Color(0xFF06B6D4)],
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x338B5CF6), Color(0x1A06B6D4), Color(0x00000000)],
  );

  static const LinearGradient subtleGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x268B5CF6), Color(0x00000000)],
  );
}

/// Helper extension on [BuildContext] for responsive and accessible theme colors.
extension EchoThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get textPrimary => isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary => isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textMuted => isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;
  Color get surfaceColor => isDarkMode ? AppColors.surfaceContainer : AppColors.lightSurface;
  Color get cardColor => isDarkMode ? AppColors.surfaceContainerHigh : AppColors.lightCard;
  Color get borderColor => isDarkMode ? AppColors.borderSubtle : AppColors.lightBorder;
}
