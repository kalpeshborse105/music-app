import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/settings_store.dart';
import '../../domain/models/audio_quality.dart';
import '../../state/downloads_controller.dart';
import '../theme/app_spacing.dart';

/// Settings: account, playback, downloads, appearance, privacy, about
/// (spec §25).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = context.watch<SettingsStore>();
    final DownloadsController downloads = context.watch<DownloadsController>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Settings',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            _section(context, 'Playback'),
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: const Text('Streaming quality'),
              subtitle: Text(
                  '${settings.streamQuality.label} · ${settings.streamQuality.dataEstimateLabel}'),
              onTap: () => _pickQuality(
                context,
                current: settings.streamQuality,
                onPick: (AudioQuality q) => settings.streamQuality = q,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.data_saver_on_rounded),
              title: const Text('Data Saver'),
              subtitle: const Text('Lower bitrate, lighter artwork, fewer requests'),
              value: settings.dataSaver,
              onChanged: (bool v) => settings.dataSaver = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Autoplay radio'),
              subtitle: const Text('Continue with similar music when the queue ends'),
              value: settings.autoplayRadio,
              onChanged: (bool v) => settings.autoplayRadio = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Normalise volume'),
              subtitle: const Text('On supported devices'),
              value: settings.normalizeVolume,
              onChanged: (bool v) => settings.normalizeVolume = v,
            ),
            _section(context, 'Downloads'),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download quality'),
              subtitle: Text(settings.downloadQuality.label),
              onTap: () => _pickQuality(
                context,
                current: settings.downloadQuality,
                onPick: (AudioQuality q) => settings.downloadQuality = q,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_rounded),
              title: const Text('Wi-Fi only'),
              value: settings.wifiOnlyDownload,
              onChanged: (bool v) => settings.wifiOnlyDownload = v,
            ),
            ListTile(
              leading: const Icon(Icons.sd_storage_rounded),
              title: const Text('Storage used'),
              subtitle: Text(downloads.humanSize(downloads.totalBytes)),
            ),
            _section(context, 'Appearance'),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('Theme'),
              subtitle: Text(settings.themeMode.name),
              onTap: () => _pickTheme(context, settings),
            ),
            _section(context, 'Privacy'),
            SwitchListTile(
              secondary: const Icon(Icons.history_rounded),
              title: const Text('Save listening history'),
              subtitle: const Text('Kept only on this device'),
              value: settings.saveHistory,
              onChanged: (bool v) => settings.saveHistory = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.insights_rounded),
              title: const Text('Personalisation'),
              subtitle: const Text('Use history for recommendations'),
              value: settings.personalizationEnabled,
              onChanged: (bool v) => settings.personalizationEnabled = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.analytics_outlined),
              title: const Text('Usage analytics'),
              subtitle: const Text('Off by default'),
              value: settings.analyticsEnabled,
              onChanged: (bool v) => settings.analyticsEnabled = v,
            ),
            _section(context, 'About'),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Kalpkrut Beats'),
              subtitle: Text('Version ${AppConstants.appVersion}'),
            ),
            const ListTile(
              leading: Icon(Icons.gavel_rounded),
              title: Text('Licences & notices'),
              subtitle: Text('Open-source acknowledgements'),
            ),
            Padding(
              padding: AppSpacing.screen,
              child: Text(
                'Kalpkrut Beats streams authorized Creative Commons audio, '
                'public-domain recordings, and local device media. '
                'Privacy-first architecture.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Developed by Kalpkrut Infotech',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  void _pickQuality(
    BuildContext context, {
    required AudioQuality current,
    required ValueChanged<AudioQuality> onPick,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final AudioQuality q in AudioQuality.values)
              ListTile(
                leading: Icon(
                  q == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: q == current ? Theme.of(ctx).colorScheme.primary : null,
                ),
                title: Text(q.label),
                subtitle: Text(q.dataEstimateLabel),
                onTap: () {
                  onPick(q);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _pickTheme(BuildContext context, SettingsStore settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ThemeMode mode in <ThemeMode>[
              ThemeMode.dark,
              ThemeMode.light,
            ])
              ListTile(
                leading: Icon(
                  mode == settings.themeMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: mode == settings.themeMode ? Theme.of(ctx).colorScheme.primary : null,
                ),
                title: Text(
                  mode == ThemeMode.dark ? 'Nocturnal Dark' : 'Alabaster Light',
                ),
                onTap: () {
                  settings.themeMode = mode;
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
