import 'package:flutter/material.dart';

import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/audio_quality.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'glass_card.dart';

/// Square media card for albums, playlists, and featured tracks in carousels.
class MediaCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final double width;
  final bool circle;
  final String? badgeText;
  final Color? badgeColor;

  const MediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.fallbackIcon = Icons.album_rounded,
    required this.onTap,
    this.onPlay,
    this.width = 144,
    this.circle = false,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(circle ? width / 2 : AppSpacing.radiusLg),
        child: Column(
          crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                Artwork(
                  url: imageUrl,
                  size: width,
                  radius: circle ? width / 2 : AppSpacing.radiusLg,
                  fallbackIcon: fallbackIcon,
                  semanticsLabel: title,
                ),
                if (badgeText != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (badgeColor ?? AppColors.secondary).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                          color: badgeColor ?? AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                if (onPlay != null && !circle)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.90),
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        onTap: onPlay,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: circle ? TextAlign.center : TextAlign.start,
              style: text.titleSmall?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: circle ? TextAlign.center : TextAlign.start,
                style: text.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: circle
                      ? (context.isDarkMode ? AppColors.secondary : AppColors.lightSecondaryAccent)
                      : context.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  factory MediaCard.forTrack({
    required Track track,
    required VoidCallback onTap,
    VoidCallback? onPlay,
    double width = 144,
  }) {
    return MediaCard(
      title: track.title,
      subtitle: track.artistNames,
      imageUrl: track.artworkUrl,
      fallbackIcon: Icons.music_note_rounded,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
      badgeText: track.qualityOptions.isNotEmpty
          ? track.qualityOptions.first.label.toUpperCase()
          : null,
    );
  }

  factory MediaCard.forAlbum({
    required Album album,
    required VoidCallback onTap,
    VoidCallback? onPlay,
    double width = 144,
  }) {
    return MediaCard(
      title: album.title,
      subtitle: album.artistNames,
      imageUrl: album.artworkUrl,
      fallbackIcon: Icons.album_rounded,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
    );
  }

  factory MediaCard.forArtist({
    required Artist artist,
    required VoidCallback onTap,
    double width = 104,
  }) {
    return MediaCard(
      title: artist.name,
      subtitle: 'Artist',
      imageUrl: artist.imageUrl,
      fallbackIcon: Icons.person_rounded,
      onTap: onTap,
      width: width,
      circle: true,
    );
  }

  factory MediaCard.forPlaylist({
    required Playlist playlist,
    required VoidCallback onTap,
    VoidCallback? onPlay,
    double width = 144,
  }) {
    return MediaCard(
      title: playlist.title,
      subtitle: playlist.trackCount > 0 ? '${playlist.trackCount} songs' : 'Playlist',
      imageUrl: playlist.artworkUrl,
      fallbackIcon: Icons.queue_music_rounded,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
    );
  }
}

/// 2-Column Bento Quick Access Card (Liked Songs, Heavy Rotation, Daily Mixes)
class EchoBentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData? icon;
  final Gradient? iconGradient;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const EchoBentoCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.icon,
    this.iconGradient,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return EchoGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      borderRadius: AppSpacing.radiusMd,
      backgroundColor: isDark
          ? AppColors.surfaceContainerHigh.withValues(alpha: 0.60)
          : AppColors.lightSurface,
      borderColor: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
      child: Row(
        children: <Widget>[
          if (imageUrl != null)
            Artwork(
              url: imageUrl,
              size: 48,
              radius: AppSpacing.radiusSm,
            )
          else if (icon != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: iconGradient ?? AppColors.likedSongsGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: context.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (onPlay != null)
            IconButton(
              icon: Icon(
                Icons.play_arrow_rounded,
                color: context.isDarkMode ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                size: 22,
              ),
              onPressed: onPlay,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Circular Artist / Curator card with verified checkmark badge.
class EchoCuratorCard extends StatelessWidget {
  final String name;
  final String followerCount;
  final String? imageUrl;
  final bool verified;
  final VoidCallback onTap;

  const EchoCuratorCard({
    super.key,
    required this.name,
    required this.followerCount,
    this.imageUrl,
    this.verified = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.heroGradient,
                  ),
                  child: ClipOval(
                    child: Artwork(
                      url: imageUrl,
                      size: 80,
                      radius: 40,
                      fallbackIcon: Icons.person_rounded,
                    ),
                  ),
                ),
                if (verified)
                  Positioned(
                    bottom: 2,
                    right: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 13, color: AppColors.onSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimary),
            ),
            Text(
              followerCount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Algorithmic Curated Mix Card (Discover Weekly, Release Radar, Flow Chillout)
class EchoMixCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String stats;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const EchoMixCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 172,
              height: 184,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: AppColors.borderHighlight),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          stats,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Refreshed weekly',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
