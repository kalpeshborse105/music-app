import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/settings_store.dart';
import '../../core/utils/auth_utils.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/audio_quality.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import 'admin_screen.dart';
import 'library_screen.dart';
import 'list_screen.dart';
import 'onboarding_auth_screen.dart';

/// Production Profile & Settings Screen with separate authenticated vs guest
/// experiences, real Supabase cloud data, role-based Admin Operations portal,
/// and full dark/light theme support.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
    _loadProfileData();
  }

  void _initAuthListener() {
    try {
      _authSubscription = SupabaseService().authStateChanges.listen((AuthState state) {
        if (mounted) {
          setState(() {});
          if (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.userUpdated) {
            _loadProfileData();
          } else if (state.event == AuthChangeEvent.signedOut) {
            setState(() {
              _userProfile = null;
            });
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadProfileData() async {
    final SupabaseService supabase = SupabaseService();
    if (!supabase.isAuthenticated || supabase.currentUserId == null) {
      if (mounted) setState(() => _userProfile = null);
      return;
    }

    try {
      final Map<String, dynamic>? profile =
          await supabase.getProfile(supabase.currentUserId!);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  static const String defaultAnimeAvatar =
      'https://api.dicebear.com/7.x/bottts/png?seed=EchoAnimeProfile';

  static const List<Map<String, String>> _animePresets = <Map<String, String>>[
    <String, String>{
      'name': 'Neon Cyber',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=NeonCyber',
    },
    <String, String>{
      'name': 'Astra Glow',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=AstraGlow',
    },
    <String, String>{
      'name': 'Synth Wave',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=SynthWave',
    },
    <String, String>{
      'name': 'Cosmic Beat',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=CosmicBeat',
    },
    <String, String>{
      'name': 'Vibe Pulse',
      'url': 'https://api.dicebear.com/7.x/bottts/png?seed=VibePulse',
    },
  ];

  String _getEffectiveDisplayName(Map<String, dynamic>? profile, User? user) {
    if (profile != null) {
      final String? name = profile['display_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    if (user != null && user.userMetadata != null) {
      final String? fullName = user.userMetadata?['full_name'] as String?;
      if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
      final String? name = user.userMetadata?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      final String? disp = user.userMetadata?['display_name'] as String?;
      if (disp != null && disp.trim().isNotEmpty) return disp.trim();
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'Kalpkrut Beats Member';
  }

  String _getEffectiveAvatarUrl(Map<String, dynamic>? profile, User? user) {
    final String? profileAvatar = profile?['avatar_url'] as String?;
    if (profileAvatar != null && profileAvatar.trim().isNotEmpty) return profileAvatar.trim();
    final String? metaAvatar = user?.userMetadata?['avatar_url'] as String?;
    if (metaAvatar != null && metaAvatar.trim().isNotEmpty) return metaAvatar.trim();
    return defaultAnimeAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = context.watch<SettingsStore>();
    final DownloadsController downloads = context.watch<DownloadsController>();
    final LibraryController library = context.watch<LibraryController>();
    final SupabaseService supabase = SupabaseService();

    final bool isDark = context.isDarkMode;
    final User? user = supabase.currentUser;
    final bool isAuthenticated = supabase.isAuthenticated && user != null;

    final String displayName = _getEffectiveDisplayName(_userProfile, user);
    final String avatarUrl = _getEffectiveAvatarUrl(_userProfile, user);
    final String userEmail = user?.email ?? 'Verified Account';

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // Header App Bar with Brand Mark
          SliverAppBar(
            pinned: true,
            expandedHeight: 64,
            backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightNavSurface)
                .withValues(alpha: 0.94),
            title: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Kalpkrut Beats',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      'Profile & Settings',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.sm),

                  // Profile Header Card
                  _buildAuthenticatedHeaderCard(
                    context,
                    isDark: isDark,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    email: userEmail,
                    library: library,
                    downloads: downloads,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Account & Security (Only if signed in)
                  if (isAuthenticated) ...<Widget>[
                    _buildSectionTitle(context, 'Account & Security'),
                    EchoGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: AppSpacing.radiusLg,
                      backgroundColor: isDark ? null : AppColors.lightSurface,
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: Icon(
                              Icons.key_rounded,
                              color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                            ),
                            title: const Text('Change Password',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Update your account password directly in app'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_forever_rounded,
                              color: AppColors.error,
                            ),
                            title: const Text('Delete Account',
                                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                            subtitle: const Text('Permanently remove account and data'),
                            onTap: () => _confirmDeleteAccount(context, supabase, library),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Audio & Playback Section
                  _buildSectionTitle(context, 'Audio & Playback'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    backgroundColor: isDark ? null : AppColors.lightSurface,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(
                            Icons.graphic_eq_rounded,
                            color: isDark
                                ? AppColors.secondary
                                : AppColors.lightSecondaryAccent,
                          ),
                          title: const Text('Streaming Quality',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${settings.streamQuality.label} • ${settings.streamQuality.dataEstimateLabel}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _pickQuality(
                            context,
                            current: settings.streamQuality,
                            onPick: (AudioQuality q) => settings.streamQuality = q,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.language_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimaryAccent,
                          ),
                          title: const Text('Preferred Music Language',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            ((_userProfile?['preferred_language'] as String?)?.isNotEmpty == true)
                                ? (_userProfile!['preferred_language'] as String).toUpperCase()
                                : 'HINDI',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _pickPreferredLanguage(context),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(
                            Icons.data_saver_on_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimaryAccent,
                          ),
                          title: const Text('Data Saver',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Lower bitrate, reduced mobile data usage'),
                          value: settings.dataSaver,
                          onChanged: (bool v) => settings.dataSaver = v,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(
                            Icons.auto_awesome_rounded,
                            color: isDark
                                ? AppColors.secondaryLight
                                : AppColors.lightSecondaryAccent,
                          ),
                          title: const Text('Autoplay Radio',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Continue with related songs when queue finishes'),
                          value: settings.autoplayRadio,
                          onChanged: (bool v) => settings.autoplayRadio = v,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(
                            Icons.volume_up_rounded,
                            color: isDark
                                ? AppColors.tertiaryLight
                                : AppColors.lightTertiaryAccent,
                          ),
                          title: const Text('Normalize Volume',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Consistent loudness across all tracks'),
                          value: settings.normalizeVolume,
                          onChanged: (bool v) => settings.normalizeVolume = v,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Downloads & Storage
                  _buildSectionTitle(context, 'Downloads & Storage'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    backgroundColor: isDark ? null : AppColors.lightSurface,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(
                            Icons.download_rounded,
                            color: isDark
                                ? AppColors.secondary
                                : AppColors.lightSecondaryAccent,
                          ),
                          title: const Text('Download Quality',
                              style: TextStyle(fontWeight: FontWeight.w600)),
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
                          secondary: Icon(
                            Icons.wifi_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimaryAccent,
                          ),
                          title: const Text('Download Over Wi-Fi Only',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          value: settings.wifiOnlyDownload,
                          onChanged: (bool v) => settings.wifiOnlyDownload = v,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.sd_storage_rounded,
                            color: isDark
                                ? AppColors.tertiaryLight
                                : AppColors.lightTertiaryAccent,
                          ),
                          title: const Text('Offline Storage Cache',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${downloads.humanSize(downloads.totalBytes)} (${downloads.downloads.length} tracks cached)'),
                          trailing: TextButton(
                            onPressed: downloads.downloads.isNotEmpty
                                ? () => _confirmClearDownloads(context, downloads)
                                : null,
                            child: const Text('Clear',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Appearance & Theme
                  _buildSectionTitle(context, 'Appearance & Theme'),
                  EchoGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: AppSpacing.radiusLg,
                    backgroundColor: isDark ? null : AppColors.lightSurface,
                    child: ListTile(
                      leading: Icon(
                        Icons.palette_outlined,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.lightPrimaryAccent,
                      ),
                      title: const Text('Theme Mode',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        settings.themeMode == ThemeMode.system
                            ? 'System Default'
                            : (settings.themeMode == ThemeMode.dark
                                ? 'Nocturnal Dark'
                                : 'Alabaster Light'),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickTheme(context, settings),
                    ),
                  ),

                  // About & Legal Compliance
                  _buildSectionTitle(context, 'About Kalpkrut Beats'),
                  EchoGlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppSpacing.radiusLg,
                    backgroundColor: isDark ? null : AppColors.lightSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.verified_user_rounded,
                              color: isDark
                                  ? AppColors.secondary
                                  : AppColors.lightSecondaryAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kalpkrut Beats',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kalpkrut Beats streams authorized Creative Commons audio, public-domain '
                          'recordings, and local device media. Developed by Kalpkrut Infotech.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            TextButton(
                              onPressed: () => _showLegalDialog(
                                context,
                                'Privacy Policy',
                                'Kalpkrut Beats respects your privacy. We collect minimal telemetry required to keep '
                                'streaming latency low. We never sell personal listener information or audio listening patterns.',
                              ),
                              child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                            ),
                            const Text('•', style: TextStyle(color: AppColors.outline)),
                            TextButton(
                              onPressed: () => _showLegalDialog(
                                context,
                                'Terms of Service',
                                'By using Kalpkrut Beats, you agree to stream audio strictly in accordance with copyright licenses '
                                'provided by source artists. Commercial rebroadcasting is prohibited without direct license.',
                              ),
                              child: const Text('Terms of Service', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Dedicated Admin / Operations Section (Exclusively for profiles.role == 'admin')
                  if (isAuthenticated && (library.isAdmin || _userProfile?['role'] == 'admin')) ...<Widget>[
                    _buildSectionTitle(context, 'Operations & Management'),
                    EchoGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: AppSpacing.radiusLg,
                      backgroundColor: isDark ? null : AppColors.lightSurface,
                      child: ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.secondary,
                        ),
                        title: const Text(
                          'Operations Portal',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Access platform metrics, provider center, and moderation'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => _handleAdminPortalEntry(context, supabase),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Sign Out as the final action at the bottom
                  if (isAuthenticated) ...<Widget>[
                    EchoGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: AppSpacing.radiusLg,
                      backgroundColor: isDark ? null : AppColors.lightSurface,
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                        subtitle: const Text('Safely log out of your session'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.error),
                        onTap: () => _confirmSignOut(context, supabase, library),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Subtle Branding Footer
                  Center(
                    child: Text(
                      'Powered by Kalpkrut Infotech',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.textMuted.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage({
    required String? url,
    required double size,
    required String fallbackLetter,
    required bool isDark,
  }) {
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
        child: Text(
          fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : 'E',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
          ),
        ),
      );
    }

    final String cleanUrl = url.trim();

    // Base64 Data URI
    if (cleanUrl.startsWith('data:image/')) {
      try {
        final int commaIdx = cleanUrl.indexOf(',');
        if (commaIdx != -1) {
          final Uint8List bytes = base64Decode(cleanUrl.substring(commaIdx + 1));
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
      } catch (_) {}
    }

    // Network Image
    return ClipOval(
      child: CachedNetworkImage(
        key: ValueKey<String>(cleanUrl),
        imageUrl: cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => CircleAvatar(
          radius: size / 2,
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
          child: Text(
            fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : 'E',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: size * 0.4,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedHeaderCard(
    BuildContext context, {
    required bool isDark,
    required String displayName,
    required String? avatarUrl,
    required String email,
    required LibraryController library,
    required DownloadsController downloads,
  }) {
    return EchoGlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppSpacing.radiusXl,
      backgroundColor: isDark ? null : AppColors.lightSurface,
      gradient: isDark
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.primary.withValues(alpha: 0.20),
                AppColors.surfaceContainerHigh.withValues(alpha: 0.65),
                AppColors.secondary.withValues(alpha: 0.12),
              ],
            )
          : null,
      child: Column(
        children: <Widget>[
          GestureDetector(
            onTap: () => _promptEditProfile(context, displayName, avatarUrl, email),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.heroGradient,
                  ),
                  child: Center(
                    child: _buildAvatarImage(
                      url: avatarUrl,
                      size: 82,
                      fallbackLetter: displayName,
                      isDark: isDark,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBg : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Profile & Picture',
                    onPressed: () => _promptEditProfile(context, displayName, avatarUrl, email),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _StatItem(
                label: 'Liked',
                value: '${library.likedTracks.length}',
                icon: Icons.favorite_rounded,
                color: AppColors.tertiary,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TrackListScreen(
                      title: 'Liked Songs',
                      tracks: library.likedTracks,
                    ),
                  ));
                },
              ),
              Container(
                width: 1,
                height: 32,
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
              _StatItem(
                label: 'Playlists',
                value: '${library.playlists.length}',
                icon: Icons.queue_music_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const PlaylistsScreen(),
                  ));
                },
              ),
              Container(
                width: 1,
                height: 32,
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
              _StatItem(
                label: 'Offline',
                value: '${downloads.downloads.length}',
                icon: Icons.download_done_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const DownloadsDetailScreen(),
                  ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final bool isDark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
          ),
        ),
      ),
    );
  }

  Future<void> _handleAdminPortalEntry(
      BuildContext context, SupabaseService supabase) async {
    if (!supabase.isAuthenticated) {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, color: AppColors.outline),
              SizedBox(width: 8),
              Text('Authentication Required'),
            ],
          ),
          content: const Text(
            'Admin operations requires an active administrator account. Please sign in to continue.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => OnboardingAuthScreen(
                    initialShowAuthForm: true,
                    initialSignUp: false,
                    onComplete: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                  ),
                ));
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    // Real Supabase role check
    final bool isAdmin = await supabase.isUserAdmin();
    if (!context.mounted) return;

    if (isAdmin) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const AdminScreen(),
      ));
    } else {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.gavel_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Access Denied'),
            ],
          ),
          content: const Text(
            'Your account does not have administrator privileges. Operations Center is restricted to authorized personnel.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    }
  }

  void _promptEditProfile(
      BuildContext context, String currentName, String? currentAvatar, String currentEmail) {
    final TextEditingController nameCtrl =
        TextEditingController(text: currentName);
    String selectedAvatar = currentAvatar ?? defaultAnimeAvatar;
    bool isUploading = false;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dCtx, StateSetter setDialogState) {
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: <Widget>[
                Icon(Icons.badge_rounded, color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Edit Profile & Avatar',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Current Selected Preview
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.heroGradient,
                          ),
                          child: Center(
                            child: _buildAvatarImage(
                              url: selectedAvatar,
                              size: 74,
                              fallbackLetter: currentName,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        if (isUploading)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Display Name',
                    style: TextStyle(
                      color: isDark ? AppColors.onSurfaceVariant : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter your name...',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Registered Email (Read Only)',
                    style: TextStyle(
                      color: isDark ? AppColors.onSurfaceVariant : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: currentEmail),
                    readOnly: true,
                    enabled: false,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? AppColors.surfaceContainerLowest.withValues(alpha: 0.5)
                          : AppColors.lightElevatedSurface.withValues(alpha: 0.5),
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upload from Device Button (jpg, jpeg, png only)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? AppColors.secondary.withValues(alpha: 0.5) : AppColors.lightSecondaryAccent,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Upload Photo (JPG, PNG)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      onPressed: (isUploading || isSaving)
                          ? null
                          : () async {
                              try {
                                final ImagePicker picker = ImagePicker();
                                final XFile? file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 800,
                                  maxHeight: 800,
                                  imageQuality: 85,
                                );
                                if (file != null) {
                                  final String ext = file.name.split('.').last.toLowerCase();
                                  if (ext != 'jpg' && ext != 'jpeg' && ext != 'png' && ext != 'webp') {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Invalid format. Please select an image file (.jpg, .jpeg, .png).'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  setDialogState(() => isUploading = true);
                                  final SupabaseService supabase = SupabaseService();
                                  if (supabase.currentUserId != null) {
                                    final String? uploadedUrl = await supabase.uploadAvatar(
                                      userId: supabase.currentUserId!,
                                      file: file,
                                    );
                                    if (uploadedUrl != null) {
                                      final String finalUrl = uploadedUrl.startsWith('data:')
                                          ? uploadedUrl
                                          : (uploadedUrl.contains('?')
                                              ? '$uploadedUrl&t=${DateTime.now().millisecondsSinceEpoch}'
                                              : '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}');
                                      setDialogState(() {
                                        selectedAvatar = finalUrl;
                                        isUploading = false;
                                      });
                                    } else {
                                      setDialogState(() => isUploading = false);
                                    }
                                  } else {
                                    setDialogState(() => isUploading = false);
                                  }
                                }
                              } catch (e) {
                                setDialogState(() => isUploading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Upload failed: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Or Pick an Anime Profile Avatar',
                    style: TextStyle(
                      color: isDark ? AppColors.onSurfaceVariant : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _animePresets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, int i) {
                        final Map<String, String> p = _animePresets[i];
                        final bool isSelected = selectedAvatar == p['url'];
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedAvatar = p['url']!;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? AppColors.secondary : AppColors.lightSecondaryAccent)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: p['url']!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.onSurfaceVariant : AppColors.textSecondaryLight)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                ),
                onPressed: (isUploading || isSaving)
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          final String newName = nameCtrl.text.trim();
                          final String finalName = newName.isNotEmpty ? newName : currentName;
                          final String? finalAvatar = selectedAvatar.isNotEmpty ? selectedAvatar : currentAvatar;
                          final LibraryController library = context.read<LibraryController>();
                          await library.updateProfile(
                            displayName: finalName,
                            avatarUrl: finalAvatar,
                          );
                          if (mounted) {
                            setState(() {
                              _userProfile = <String, dynamic>{
                                ...?_userProfile,
                                'display_name': finalName,
                                'avatar_url': finalAvatar,
                              };
                            });
                          }
                          await _loadProfileData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Couldn\'t save your profile. Please try again.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                child: isSaving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    SupabaseService supabase,
    LibraryController library,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This permanently deletes your Kalpkrut Beats account and associated data (favorites, playlists, and history). This action cannot be undone.\n\nFor external deletion requests or Play Store data compliance, you can also visit our account deletion portal at https://beats.kalpkrutinfotech.com/delete-account.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );
      final bool ok = await supabase.deleteAccount();
      await library.onSignedOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Account permanently deleted'
                : 'Account data cleared and logged out'),
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController pwdController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool isSubmitting = false;
    bool obscure1 = true;
    bool obscure2 = true;
    String? localError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: <Widget>[
                  Icon(Icons.key_rounded, color: AppColors.electricViolet),
                  SizedBox(width: 10),
                  Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Enter a new secure password for your account.',
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),
                  if (localError != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(localError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: pwdController,
                    obscureText: obscure1,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.electricViolet, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscure1 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                        onPressed: () => setModalState(() => obscure1 = !obscure1),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.electricViolet, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscure2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                        onPressed: () => setModalState(() => obscure2 = !obscure2),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.electricViolet),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final String p1 = pwdController.text.trim();
                          final String p2 = confirmController.text.trim();
                          if (p1.isEmpty || p1.length < 6) {
                            setModalState(() => localError = 'Password must be at least 6 characters long.');
                            return;
                          }
                          if (p1 != p2) {
                            setModalState(() => localError = 'Passwords do not match.');
                            return;
                          }
                          setModalState(() {
                            isSubmitting = true;
                            localError = null;
                          });
                          try {
                            await SupabaseService().updateUserPassword(p1);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully!'),
                                  backgroundColor: AppColors.emerald,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              localError = AuthUtils.getFriendlyErrorMessage(e);
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pickPreferredLanguage(BuildContext context) {
    const List<String> languages = <String>[
      'Hindi', 'Marathi', 'Punjabi', 'Bhojpuri', 'Haryanvi', 'Gujarati', 'Tamil', 'Telugu', 'Bengali', 'English'
    ];
    final String current = (_userProfile?['preferred_language'] as String?)?.toUpperCase() ?? 'HINDI';

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Preferred Music Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (BuildContext _, int idx) {
                    final String lang = languages[idx];
                    final bool isSelected = lang.toUpperCase() == current;
                    return ListTile(
                      title: Text(lang, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.electricViolet) : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final String newLang = lang.toLowerCase();
                        final SupabaseService supabase = SupabaseService();
                        if (supabase.currentUser != null) {
                          await supabase.updateProfile(userId: supabase.currentUser!.id, preferredLanguage: newLang);
                          await _loadProfileData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Music language updated to $lang'), backgroundColor: AppColors.electricViolet),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmSignOut(
      BuildContext context, SupabaseService supabase, LibraryController library) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'Your synchronized favorites and playlists will be hidden until you sign in again.',
          style: TextStyle(fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await supabase.signOut();
              await library.onSignedOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
                setState(() {
                  _userProfile = null;
                });
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(BuildContext context, String title, String content) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _pickQuality(
    BuildContext context, {
    required AudioQuality current,
    required ValueChanged<AudioQuality> onPick,
  }) {
    final bool isDark = context.isDarkMode;
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
                  color: q == current
                      ? (isDark ? AppColors.secondary : AppColors.lightSecondaryAccent)
                      : context.textSecondary,
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
    final bool isDark = context.isDarkMode;
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
                  color: mode == settings.themeMode
                      ? (isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent)
                      : context.textSecondary,
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
  final VoidCallback onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: context.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
