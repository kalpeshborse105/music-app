import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/models/track.dart';
import '../../domain/providers/provider_labels.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'now_playing_bars.dart';
import 'source_badge.dart';
import '../services/track_actions.dart';

/// Stitch Nocturnal Track Tile supporting ranking, live soundbars, lossless tags,
/// and smooth pressed / hover states.
class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final bool isCurrent;
  final bool isPlaying;
  final int? index;
  final bool showSource;
  final bool dense;
  final Widget? trailing;

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onMenu,
    this.isCurrent = false,
    this.isPlaying = false,
    this.index,
    this.showSource = false,
    this.dense = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color rankColor = index == 0
        ? AppColors.secondary
        : (index == 1
            ? AppColors.primaryLight
            : (index != null && index! < 3 ? AppColors.tertiaryLight : AppColors.outline));

    return Material(
      color: isCurrent
          ? (isDark
              ? AppColors.surfaceContainerHigh.withValues(alpha: 0.8)
              : AppColors.lightSurfaceAlt)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: dense ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              // Index / Rank or Soundbar
              if (index != null)
                Container(
                  width: 30,
                  alignment: Alignment.centerLeft,
                  child: isCurrent && isPlaying
                      ? const NowPlayingBars(size: 16, color: AppColors.secondary)
                      : Text(
                          '${index! + 1}',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: rankColor,
                          ),
                        ),
                ),
              // Artwork with overlay
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Artwork(
                    url: track.artworkUrl,
                    size: dense ? 44 : 50,
                    radius: AppSpacing.radiusSm,
                  ),
                  if (isCurrent && index == null)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Center(
                          child: NowPlayingBars(
                            playing: isPlaying,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Track Title & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                              color: isCurrent
                                  ? (isDark ? AppColors.secondaryLight : AppColors.primary)
                                  : null,
                            ),
                          ),
                        ),
                        if (index == 0) ...<Widget>[
                          const SizedBox(width: 6),
                          _HotTag(),
                        ],
                        if (track.explicit) ...<Widget>[
                          const SizedBox(width: 6),
                          _ExplicitTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            track.artistNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (showSource) ...<Widget>[
                          const SizedBox(width: 6),
                          SourceBadge(
                            label: providerShortLabel(track.providerId),
                            icon: providerIcon(track.providerId),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Duration or Trailing Menu
              if (track.duration > Duration.zero && trailing == null)
                Text(
                  Formatters.duration(track.duration),
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              if (trailing != null)
                trailing!
              else
                PopupMenuButton<String>(
                  onSelected: (String v) async {
                    if (v == 'share') {
                      await TrackActions.share(context, track);
                    } else if (v == 'copy_link') {
                      await TrackActions.copySongLink(context, track);
                    } else if (v == 'favorite') {
                      await TrackActions.toggleFavorite(context, track);
                    } else if (v == 'add_to_playlist') {
                      await TrackActions.addToPlaylist(context, track);
                    } else if (v == 'more' && onMenu != null) {
                      onMenu!();
                    }
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('Share'))),
                    const PopupMenuItem<String>(value: 'copy_link', child: ListTile(leading: Icon(Icons.link), title: Text('Copy link'))),
                    const PopupMenuItem<String>(value: 'favorite', child: ListTile(leading: Icon(Icons.favorite_border), title: Text('Add / Remove Favorite'))),
                    const PopupMenuItem<String>(value: 'add_to_playlist', child: ListTile(leading: Icon(Icons.playlist_add), title: Text('Add to playlist'))),
                    if (onMenu != null) const PopupMenuItem<String>(value: 'more', child: ListTile(leading: Icon(Icons.more_horiz), title: Text('More'))),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMutedDark),
                  tooltip: 'More options',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'HOT',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: AppColors.secondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ExplicitTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.outlineVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
