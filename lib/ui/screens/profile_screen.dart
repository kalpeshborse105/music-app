import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/settings_store.dart';
import '../../data/provider_registry.dart';
import '../../domain/models/audio_quality.dart';
import '../../domain/providers/music_provider.dart';
import '../../domain/providers/provider_labels.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

/// Stitch Profile & Account Screen featuring listener stats, audio settings,
/// storage breakdown, theme configuration, and legal disclosures.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = context.watch<SettingsStore>();
    final DownloadsController downloads = context.watch<DownloadsController>();
    final LibraryController library = context.watch<LibraryController>();
    final ProviderRegistry registry = context.read<ProviderRegistry>();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // Header App Bar with Brand Mark and Notification Icon
          SliverAppBar(
            pinned: true,
            expandedHeight: 64,
            backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightBg).withValues(alpha: 0.90),
            title: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'EchoFlow',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Profile & Account',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.sm),

                  // Profile Header Card
                  EchoGlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    borderRadius: AppSpacing.radiusXl,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.primary.withValues(alpha: 0.20),
                        AppColors.surfaceContainerHigh.withValues(alpha: 0.65),
                        AppColors.secondary.withValues(alpha: 0.12),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.heroGradient,
                              ),
                              child: const Center(
                                child: CircleAvatar(
                                  radius: 41,
                                  backgroundColor: AppColors.darkBg,
                                  child: Icon(Icons.person_rounded, size: 48, color: AppColors.primaryLight),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'EchoFlow Explorer',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'listener@echoflow.stream',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _StatItem(
                              label: 'Liked',
                              value: '${library.likedTracks.length}',
                              icon: Icons.favorite_rounded,
                              color: AppColors.tertiary,
                            ),
                            Container(width: 1, height: 32, color: AppColors.borderSubtle),
                            _StatItem(
                              label: 'Playlists',
                              value: '${library.playlists.length}',
                              icon: Icons.queue_music_rounded,
                              color: AppColors.primaryLight,
                            ),
                            Container(width: 1, height: 32, color: AppColors.borderSubtle),
                            _StatItem(
                              label: 'Downloaded',
                              value: '${downloads.downloads.length}',
                              icon: Icons.download_done_rounded,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Section 1: Audio Playback & Streaming
                  _buildSectionTitle('Audio & Playback'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.graphic_eq_rounded, color: AppColors.secondary),
                          title: const Text('Streaming Quality', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${settings.streamQuality.label} • ${settings.streamQuality.dataEstimateLabel}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _pickQuality(
                            context,
                            current: settings.streamQuality,
                            onPick: (AudioQuality q) => settings.streamQuality = q,
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.data_saver_on_rounded, color: AppColors.primaryLight),
                          title: const Text('Data Saver', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Lower bitrate, lighter requests on mobile'),
                          value: settings.dataSaver,
                          onChanged: (bool v) => settings.dataSaver = v,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.auto_awesome_rounded, color: AppColors.secondaryLight),
                          title: const Text('Autoplay Radio', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Keep the flow going when the queue ends'),
                          value: settings.autoplayRadio,
                          onChanged: (bool v) => settings.autoplayRadio = v,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.volume_up_rounded, color: AppColors.tertiaryLight),
                          title: const Text('Normalize Volume', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Consistent loudness across tracks'),
                          value: settings.normalizeVolume,
                          onChanged: (bool v) => settings.normalizeVolume = v,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Section 2: Downloads & Storage
                  _buildSectionTitle('Downloads & Storage'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.download_rounded, color: AppColors.secondary),
                          title: const Text('Download Quality', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(settings.downloadQuality.label),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _pickQuality(
                            context,
                            current: settings.downloadQuality,
                            onPick: (AudioQuality q) => settings.downloadQuality = q,
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.wifi_rounded, color: AppColors.primaryLight),
                          title: const Text('Download Over Wi-Fi Only', style: TextStyle(fontWeight: FontWeight.w600)),
                          value: settings.wifiOnlyDownload,
                          onChanged: (bool v) => settings.wifiOnlyDownload = v,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.sd_storage_rounded, color: AppColors.tertiaryLight),
                          title: const Text('Offline Cache Used', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${downloads.humanSize(downloads.totalBytes)} (${downloads.downloads.length} songs)'),
                          trailing: TextButton(
                            onPressed: downloads.downloads.isNotEmpty
                                ? () => _confirmClearDownloads(context, downloads)
                                : null,
                            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Section 3: Appearance & Theme
                  _buildSectionTitle('Appearance & Theme'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined, color: AppColors.primaryLight),
                      title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        settings.themeMode == ThemeMode.system
                            ? 'System Default'
                            : (settings.themeMode == ThemeMode.dark ? 'Nocturnal Dark' : 'Alabaster Light'),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickTheme(context, settings),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Section 4: Privacy & Sources
                  _buildSectionTitle('Music Sources & Transparency'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    child: Column(
                      children: <Widget>[
                        for (final MusicProvider p in registry.all)
                          ListTile(
                            leading: Icon(providerIcon(p.id), color: AppColors.primaryLight),
                            title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              registry.isAvailable(p.id) ? 'Active & connected' : 'Optional / Standby',
                            ),
                            trailing: registry.isAvailable(p.id)
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20)
                                : const Icon(Icons.info_outline_rounded, size: 20),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Section 5: Legal & Disclosures
                  _buildSectionTitle('About & Legal Compliance'),
                  EchoGlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppSpacing.radiusLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.verified_user_rounded, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'EchoFlow Music v${AppConstants.appVersion}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'EchoFlow Music streams only verified Creative Commons, public-domain archives, '
                          'and authorized local device audio. No unauthorized streams or DRM circumvention.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }

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
                  color: q == current ? AppColors.secondary : AppColors.textSecondaryDark,
                ),
                title: Text(q.label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            for (final ThemeMode mode in ThemeMode.values)
              ListTile(
                leading: Icon(
                  mode == settings.themeMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: mode == settings.themeMode ? AppColors.primary : AppColors.textSecondaryDark,
                ),
                title: Text(
                  mode == ThemeMode.system
                      ? 'System Default'
                      : (mode == ThemeMode.dark ? 'Nocturnal Dark' : 'Alabaster Light'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
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

  void _confirmClearDownloads(BuildContext context, DownloadsController downloads) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear Downloads?'),
        content: const Text('All offline tracks will be removed from device storage.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              downloads.removeAll();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}
