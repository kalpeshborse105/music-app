import 'package:flutter/material.dart';

/// UI labels/icons per provider id, kept in one place so the UI never hardcodes
/// provider specifics (spec §46).
String providerShortLabel(String providerId) {
  switch (providerId) {
    case 'local':
      return 'Device Audio';
    case 'custom_api':
    case 'jamendo':
    case 'audius':
    case 'archive':
    case 'licensed':
    case 'regional_indian':
    case 'demo':
    default:
      return 'Kalpkrut Stream';
  }
}

IconData providerIcon(String providerId) {
  switch (providerId) {
    case 'local':
      return Icons.smartphone_rounded;
    case 'custom_api':
    case 'jamendo':
    case 'audius':
    case 'archive':
    case 'licensed':
    case 'regional_indian':
    case 'demo':
    default:
      return Icons.graphic_eq_rounded;
  }
}

/// A longer, human explanation of the source used on detail pages.
String providerDescription(String providerId) {
  switch (providerId) {
    case 'local':
      return 'Local audio tracks stored on this device';
    case 'custom_api':
    case 'jamendo':
    case 'audius':
    case 'archive':
    case 'licensed':
    case 'regional_indian':
    case 'demo':
    default:
      return 'High-fidelity audio stream powered by Kalpkrut Beats Cloud Engine';
  }
}
