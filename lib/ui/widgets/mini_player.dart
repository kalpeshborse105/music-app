import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/playback/playback_controller.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'glass_card.dart';
import 'now_playing_bars.dart';

/// Stitch Nocturnal Floating MiniPlayer with glassmorphism, animated soundbars,
/// and gradient micro-progress bar.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaybackController pc = context.watch<PlaybackController>();
    final track = pc.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final Duration duration =
        pc.snapshot.duration > Duration.zero ? pc.snapshot.duration : track.duration;
    final double progress = duration.inMilliseconds > 0
        ? (pc.snapshot.position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      child: EchoGlassCard(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, Animation<double> a, Animation<double> sa) => const PlayerScreen(),
            transitionsBuilder: (_, Animation<double> a, Animation<double> sa, Widget child) {
              return FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        ),
        padding: EdgeInsets.zero,
        borderRadius: AppSpacing.radiusLg,
        blurSigma: 24,
        backgroundColor: isDark
            ? AppColors.surfaceContainerHigh.withValues(alpha: 0.88)
            : AppColors.lightSurface.withValues(alpha: 0.92),
        borderColor: isDark ? AppColors.borderHighlight : AppColors.lightBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  // Artwork Thumbnail
                  Hero(
                    tag: 'player_art_${track.id}',
                    child: Artwork(
                      url: track.artworkUrl,
                      size: 42,
                      radius: AppSpacing.radiusSm,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Title and Artist
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (pc.isPlaying) ...<Widget>[
                              const SizedBox(width: 6),
                              const NowPlayingBars(size: 13, color: AppColors.secondary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          track.artistNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Previous Track
                  IconButton(
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.skip_previous_rounded, color: AppColors.textSecondaryDark),
                    onPressed: pc.previous,
                    tooltip: 'Previous track',
                  ),
                  const SizedBox(width: 2),
                  // Play/Pause Hero Circle
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: pc.togglePlayPause,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          pc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Next Track
                  IconButton(
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.skip_next_rounded, color: AppColors.textSecondaryDark),
                    onPressed: pc.next,
                    tooltip: 'Next track',
                  ),
                ],
              ),
            ),
            // Bottom Edge Gradient Micro Progress Bar
            Container(
              height: 2.2,
              width: double.infinity,
              color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightBorder,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
