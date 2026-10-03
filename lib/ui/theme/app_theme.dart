import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds the Stitch-compliant light/dark [ThemeData].
///
/// Configures nocturnal color layers, Plus Jakarta Sans headline typography,
/// Inter body typography, glass card styling, and accessible touch targets.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE9DDFF),
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFACEDFF),
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFD9E4),
      onTertiaryContainer: AppColors.onTertiary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFCBD5E1),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
    );
    return _buildTheme(scheme, isDark: false);
  }

  static ThemeData dark() {
    final ColorScheme scheme = const ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiaryLight,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Color(0xFF570032),
      surface: AppColors.darkBg,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: Color(0xFFFFDAD6),
    );
    return _buildTheme(scheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme scheme, {required bool isDark}) {
    final Color bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final Color surface = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;
    final Color surfaceHigh = isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurfaceAlt;
    final Color border = isDark ? AppColors.borderSubtle : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final TextTheme textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg.withValues(alpha: 0.85),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brLg,
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brXl,
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightBg).withValues(alpha: 0.90),
        indicatorColor: AppColors.primary.withValues(alpha: 0.20),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.primaryLight : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primaryLight : textSecondary,
            size: 24,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: BorderSide(color: border),
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.brMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, kMinTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.brPill),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, kMinTouchTarget),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.brPill),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          minimumSize: const Size(0, 40),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: surfaceHigh,
        thumbColor: Colors.white,
        overlayColor: AppColors.primary.withValues(alpha: 0.20),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.brMd),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceContainerHighest : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brMd,
          side: BorderSide(color: border),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w800,
        color: primary,
        fontSize: 34,
        letterSpacing: -0.025,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w800,
        color: primary,
        fontSize: 28,
        letterSpacing: -0.02,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        color: primary,
        fontSize: 24,
        letterSpacing: -0.02,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        color: primary,
        fontSize: 22,
        letterSpacing: -0.015,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        color: primary,
        fontSize: 18,
        letterSpacing: -0.01,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        color: primary,
        fontSize: 20,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w600,
        color: primary,
        fontSize: 16,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w600,
        color: primary,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        color: secondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 0.06,
        color: secondary,
      ),
    );
  }
}
