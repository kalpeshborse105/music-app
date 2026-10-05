import 'package:flutter/material.dart';

/// UI labels/icons per provider id, kept in one place so the UI never hardcodes
/// provider specifics (spec §46).
String providerShortLabel(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return 'Jamendo';
    case 'audius':
      return 'Audius';
    case 'archive':
      return 'Archive';
    case 'local':
      return 'Device Audio';
    case 'licensed':
      return 'Licensed';
    case 'regional_indian':
      return 'Regional Indic';
    case 'demo':
      return 'EchoFlow Masters';
    case 'custom_api':
      return 'Cloud Catalog';
    default:
      return providerId;
  }
}

IconData providerIcon(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return Icons.public_rounded;
    case 'audius':
      return Icons.album_rounded;
    case 'archive':
      return Icons.account_balance_rounded;
    case 'local':
      return Icons.smartphone_rounded;
    case 'licensed':
      return Icons.verified_rounded;
    case 'regional_indian':
      return Icons.translate_rounded;
    case 'demo':
      return Icons.graphic_eq_rounded;
    case 'custom_api':
      return Icons.cloud_sync_rounded;
    default:
      return Icons.cloud_queue_rounded;
  }
}

/// A longer, human explanation of the source used on detail pages.
String providerDescription(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return 'Creative-Commons licensed global catalog via Jamendo';
    case 'audius':
      return 'High-fidelity streaming catalog via Audius';
    case 'archive':
      return 'Public-domain & openly-licensed audio archives';
    case 'local':
      return 'Local audio tracks stored on this device';
    case 'licensed':
      return 'Licensed partner audio catalog';
    case 'regional_indian':
      return 'Regional Indian-language catalog (Hindi, Marathi, Khandeshi & Indic languages)';
    case 'demo':
      return 'EchoFlow Studio Master recordings (ambient & electronic archives)';
    case 'custom_api':
      return 'High-performance cloud audio gateway with cached lossless streaming';
    default:
      return 'Music provider';
  }
}
