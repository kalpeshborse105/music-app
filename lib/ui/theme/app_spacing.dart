import 'package:flutter/widgets.dart';

/// Consistent spacing + corner-radius scale (spec §47).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Screen padding
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets screenVertical =
      EdgeInsets.symmetric(horizontal: lg, vertical: lg);

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(radiusPill));
}

/// Minimum accessible touch target (spec §34).
const double kMinTouchTarget = 48.0;
