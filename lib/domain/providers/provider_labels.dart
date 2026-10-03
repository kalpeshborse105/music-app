import 'package:flutter/material.dart';

/// UI labels/icons per provider id, kept in one place so the UI never hardcodes
/// provider specifics (spec §46).
String providerShortLabel(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return 'Jamendo';
    case 'archive':
      return 'Archive';
    case 'local':
      return 'Local';
    case 'licensed':
      return 'Licensed';
    case 'demo':
      return 'Demo';
    default:
      return providerId;
  }
}

IconData providerIcon(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return Icons.public_rounded;
    case 'archive':
      return Icons.account_balance_rounded;
    case 'local':
      return Icons.smartphone_rounded;
    case 'licensed':
      return Icons.verified_rounded;
    case 'demo':
      return Icons.science_rounded;
    default:
      return Icons.cloud_queue_rounded;
  }
}

/// A longer, human explanation of the source used on detail pages.
String providerDescription(String providerId) {
  switch (providerId) {
    case 'jamendo':
      return 'Creative-Commons licensed catalogue via Jamendo';
    case 'archive':
      return 'Public-domain & openly-licensed audio from the Internet Archive';
    case 'local':
      return 'Your own files stored on this device';
    case 'licensed':
      return 'A commercial provider (not configured)';
    case 'demo':
      return 'Royalty-free demo tracks bundled for offline testing';
    default:
      return 'Music provider';
  }
}
