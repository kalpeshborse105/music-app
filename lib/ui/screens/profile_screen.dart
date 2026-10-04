import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/settings_store.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/audio_quality.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/glass_card.dart';
import '../widgets/track_tile.dart';
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
    return 'EchoFlow Member';
  }

  String? _getEffectiveAvatarUrl(Map<String, dynamic>? profile, User? user) {
    final String? profileAvatar = profile?['avatar_url'] as String?;
    if (profileAvatar != null && profileAvatar.trim().isNotEmpty) return profileAvatar.trim();
    final String? metaAvatar = user?.userMetadata?['avatar_url'] as String?;
    if (metaAvatar != null && metaAvatar.trim().isNotEmpty) return metaAvatar.trim();
    return null;
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
    final String? avatarUrl = _getEffectiveAvatarUrl(_userProfile, user);
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
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
                              Icons.mark_email_read_rounded,
                              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                            ),
                            title: const Text('Registered Email',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(userEmail),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.lock_reset_rounded,
                              color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                            ),
                            title: const Text('Reset Password',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Send recovery instructions to your email'),
                            onTap: () => _confirmResetPassword(context, userEmail),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                            title: const Text('Sign Out',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, color: AppColors.error)),
                            subtitle: const Text('Return to signed-out guest session'),
                            onTap: () => _confirmSignOut(context, supabase, library),
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

                  const SizedBox(height: AppSpacing.lg),

                  // Recently Played (Authenticated Session History)
                  if (library.history.isNotEmpty) ...<Widget>[
                    _buildSectionTitle(context, 'Recently Played'),
                    EchoGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      borderRadius: AppSpacing.radiusLg,
                      backgroundColor: isDark ? null : AppColors.lightSurface,
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < library.history.take(5).length; i++) ...<Widget>[
                            TrackTile(
                              dense: true,
                              track: library.history[i].track,
                              onTap: () => TrackActions.play(context, library.history[i].track),
                              onMenu: () => showTrackActionsSheet(context, library.history[i].track),
                            ),
                            if (i < library.history.take(5).length - 1)
                              const Divider(height: 1, indent: 64),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // About & Legal Compliance
                  _buildSectionTitle(context, 'About EchoFlow'),
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
                              'EchoFlow Music v${AppConstants.appVersion}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'EchoFlow Music streams authorized Creative Commons audio, public-domain '
                          'recordings, and local device media. Privacy-first architecture without DRM circumvention.',
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
                                'EchoFlow Music respects your privacy. We collect minimal telemetry required to keep '
                                'streaming latency low. We never sell personal listener information or audio listening patterns.',
                              ),
                              child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                            ),
                            const Text('•', style: TextStyle(color: AppColors.outline)),
                            TextButton(
                              onPressed: () => _showLegalDialog(
                                context,
                                'Terms of Service',
                                'By using EchoFlow Music, you agree to stream audio strictly in accordance with copyright licenses '
                                'provided by source artists. Commercial rebroadcasting is prohibited without direct license.',
                              ),
                              child: const Text('Terms of Service', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Operations Portal Gateway (Role-Protected for authenticated users)
                  if (isAuthenticated) ...<Widget>[
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () => _handleAdminPortalEntry(context, supabase),
                        icon: Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 16,
                          color: context.textMuted,
                        ),
                        label: Text(
                          'Operations Portal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Subtle Branding Footer
                  Center(
                    child: Text(
                      'Kalpkrut Infotech',
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
            onTap: () => _promptEditProfile(context, displayName, avatarUrl),
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
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => CircleAvatar(
                                radius: 41,
                                backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                              ),
                              errorWidget: (_, __, ___) => CircleAvatar(
                                radius: 41,
                                backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 41,
                            backgroundColor:
                                isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                              ),
                            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit Profile & Picture',
                onPressed: () => _promptEditProfile(context, displayName, avatarUrl),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
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
      BuildContext context, String currentName, String? currentAvatar) {
    final TextEditingController nameCtrl =
        TextEditingController(text: currentName);
    final TextEditingController avatarCtrl =
        TextEditingController(text: currentAvatar ?? '');
    String selectedAvatar = currentAvatar ?? '';

    final List<Map<String, String>> presets = <Map<String, String>>[
      <String, String>{
        'name': 'Neon Wave',
        'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
      },
      <String, String>{
        'name': 'Cyber Glow',
        'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
      },
      <String, String>{
        'name': 'Acoustic Soul',
        'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
      },
      <String, String>{
        'name': 'Cosmic Pulse',
        'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
      },
    ];

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dCtx, StateSetter setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: <Widget>[
              Icon(Icons.badge_rounded, color: AppColors.neonCyan),
              SizedBox(width: 8),
              Text('Edit Profile & Picture', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Display Name',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your name...',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Avatar Preset',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, int i) {
                      final p = presets[i];
                      final bool isSelected = selectedAvatar == p['url'];
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedAvatar = p['url']!;
                            avatarCtrl.text = p['url']!;
                          });
                        },
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.neonCyan : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: p['url']!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Or Custom Avatar Image URL',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: avatarCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/avatar.jpg',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (String v) {
                    setDialogState(() {
                      selectedAvatar = v.trim();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.electricViolet),
              onPressed: () async {
                final String newName = nameCtrl.text.trim();
                final String newAvatar = avatarCtrl.text.trim();
                final SupabaseService supabase = SupabaseService();
                if (supabase.currentUserId != null) {
                  await supabase.updateProfile(
                    userId: supabase.currentUserId!,
                    displayName: newName.isNotEmpty ? newName : null,
                    avatarUrl: newAvatar.isNotEmpty ? newAvatar : null,
                  );
                  await _loadProfileData();
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetPassword(BuildContext context, String email) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Send Password Reset Link?'),
        content: Text(
          'A password reset link will be sent to $email. You will be able to set a new password securely.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService().resetPasswordForEmail(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reset link sent to $email'),
                      backgroundColor: AppColors.electricViolet,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
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
