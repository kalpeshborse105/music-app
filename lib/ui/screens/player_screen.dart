import 'package:flutter/material.dart' hide RepeatMode, SearchController;
import 'package:provider/provider.dart';

import '../../core/storage/settings_store.dart';
import '../../core/utils/app_messenger.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/audio_quality.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_queue.dart' as pq;
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/artwork.dart';
import '../widgets/glass_card.dart';
import 'lyrics_screen.dart';

/// Stitch Full Player Screen with Hero Vinyl Framing, Ambient Back-Glow,
/// Hi-Res Lossless Badges, Gradient Progress Scrubber, Glowing FAB, and Action Panel.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final PlaybackController pc = context.watch<PlaybackController>();
    final SettingsStore settings = context.watch<SettingsStore>();
    final Track? track = pc.currentTrack;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing is currently playing')),
      );
    }

    final DownloadsController downloads = context.watch<DownloadsController>();
    final bool liked = context.watch<LibraryController>().isLiked(track.id);
    final bool isDownloaded = downloads.isDownloaded(track.id);
    final bool isDownloading = downloads.task(track.id)?.status == DownloadStatus.downloading;
    final Duration duration =
        pc.snapshot.duration > Duration.zero ? pc.snapshot.duration : track.duration;
    final double maxMs = duration.inMilliseconds.toDouble().clamp(1, double.infinity);
    final double positionMs =
        _dragValue ?? pc.snapshot.position.inMilliseconds.toDouble().clamp(0, maxMs);

    final double screenHeight = MediaQuery.of(context).size.height;
    final double artSize = (screenHeight * 0.28).clamp(180.0, 260.0);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: <Widget>[
          // Bioluminescent Ambient Glow Orbs
          Positioned(
            top: -40,
            left: MediaQuery.of(context).size.width * 0.15,
            child: const EchoAmbientGlowOrb(
              color: AppColors.primary,
              size: 320,
              blurRadius: 120,
              opacity: 0.22,
            ),
          ),
          const Positioned(
            top: 260,
            right: -60,
            child: EchoAmbientGlowOrb(
              color: AppColors.secondary,
              size: 260,
              blurRadius: 100,
              opacity: 0.16,
            ),
          ),

          SafeArea(
            child: Column(
              children: <Widget>[
                // 1. Top Bar / Sub-Header Context Navigator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                        tooltip: 'Dismiss to miniplayer',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album?.title.isNotEmpty == true && track.album?.title != 'Single'
                                  ? track.album!.title
                                  : track.artistNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          pc.sleepTimerRemaining != null
                              ? Icons.bedtime_rounded
                              : Icons.bedtime_outlined,
                          color: pc.sleepTimerRemaining != null
                              ? AppColors.secondary
                              : Colors.white,
                          size: 22,
                        ),
                        tooltip: pc.sleepTimerRemaining != null
                            ? 'Sleep Timer: ${pc.sleepTimerRemaining!.inMinutes}m left'
                            : 'Sleep Timer',
                        onPressed: () => showSleepTimerSheet(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 21),
                        tooltip: 'Share Track',
                        onPressed: () => TrackActions.share(context, track),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
                        tooltip: 'Options',
                        onPressed: () => showTrackActionsSheet(context, track),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // 2. Hero Vinyl Framing & Artwork Centerpiece with Gestures (Swipe left/right for tracks, drag down to collapse)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (DragEndDetails details) {
                    final double? v = details.primaryVelocity;
                    if (v != null) {
                      if (v < -250) {
                        pc.next();
                      } else if (v > 250) {
                        pc.previous();
                      }
                    }
                  },
                  onVerticalDragEnd: (DragEndDetails details) {
                    final double? v = details.primaryVelocity;
                    if (v != null && v > 280) {
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Ambient outer glow
                        Container(
                          width: artSize + 16,
                          height: artSize + 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                blurRadius: 36,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Outer vinyl groove frame
                        Container(
                          width: artSize,
                          height: artSize,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0xFF353942),
                                Color(0xFF262A33),
                                Color(0xFF0A0E16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Hero(
                              tag: 'player_art_${track.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Artwork(
                                  url: track.artworkUrl,
                                  size: artSize - 12,
                                  radius: 26,
                                  fallbackIcon: Icons.music_note_rounded,
                                ),
                              ),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // 3. Track Metadata & Favorite Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () => TrackActions.openArtist(context, track.primaryArtist),
                                    child: Text(
                                      track.artistNames,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 16, color: AppColors.secondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Favorite Toggle Button
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: liked ? 'Remove from Liked' : 'Add to Liked Songs',
                          onPressed: () => TrackActions.toggleFavorite(context, track),
                          icon: Icon(
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: liked ? AppColors.tertiary : AppColors.textSecondaryDark,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Audio Format Tag
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          settings.effectiveStreamQuality.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Interactive Scrubber Slider & Timestamps
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppColors.primaryLight,
                          inactiveTrackColor: AppColors.surfaceContainerHighest,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: positionMs.clamp(0, maxMs),
                          max: maxMs,
                          onChanged: (double v) => setState(() => _dragValue = v),
                          onChangeEnd: (double v) {
                            setState(() => _dragValue = null);
                            pc.seek(Duration(milliseconds: v.round()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              Formatters.duration(Duration(milliseconds: positionMs.round())),
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 12,
                                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              '-${Formatters.duration(Duration(milliseconds: (maxMs - positionMs).round().clamp(0, maxMs.toInt())))}',
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 12,
                                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Core Playback Controls Dock
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      // Shuffle
                      IconButton(
                        tooltip: 'Shuffle',
                        iconSize: 22,
                        color: pc.queue.shuffle ? AppColors.secondary : AppColors.textSecondaryDark,
                        icon: const Icon(Icons.shuffle_rounded),
                        onPressed: pc.toggleShuffle,
                      ),
                      // -10s Seek
                      IconButton(
                        tooltip: 'Rewind 10s',
                        iconSize: 24,
                        color: AppColors.textSecondaryDark,
                        icon: const Icon(Icons.replay_10_rounded),
                        onPressed: () => pc.seek(pc.snapshot.position - const Duration(seconds: 10)),
                      ),
                      // Previous Track
                      IconButton(
                        tooltip: 'Previous',
                        iconSize: 34,
                        color: Colors.white,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: pc.previous,
                      ),
                      // Hero Play / Pause FAB
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: pc.togglePlayPause,
                            child: Center(
                              child: pc.snapshot.isBuffering
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.white),
                                    )
                                  : Icon(
                                      pc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 36,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      // Next Track
                      IconButton(
                        tooltip: 'Next',
                        iconSize: 34,
                        color: Colors.white,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: pc.next,
                      ),
                      // +10s Seek
                      IconButton(
                        tooltip: 'Forward 10s',
                        iconSize: 24,
                        color: AppColors.textSecondaryDark,
                        icon: const Icon(Icons.forward_10_rounded),
                        onPressed: () => pc.seek(pc.snapshot.position + const Duration(seconds: 10)),
                      ),
                      // Repeat
                      IconButton(
                        tooltip: 'Repeat',
                        iconSize: 22,
                        color: pc.queue.repeat == pq.RepeatMode.off
                            ? AppColors.textSecondaryDark
                            : AppColors.secondary,
                        icon: Icon(
                          pc.queue.repeat == pq.RepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                        ),
                        onPressed: pc.cycleRepeat,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 6. Bottom Quick Action Panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: EchoGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                    borderRadius: AppSpacing.radiusLg,
                    backgroundColor: AppColors.surfaceContainer.withValues(alpha: 0.70),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _ActionIcon(
                          icon: Icons.lyrics_rounded,
                          label: 'Lyrics',
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => LyricsScreen(track: track),
                            ));
                          },
                        ),
                        _ActionIcon(
                          icon: isDownloading
                              ? Icons.downloading_rounded
                              : (isDownloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded),
                          label: isDownloaded ? 'Saved' : 'Download',
                          iconColor: isDownloaded
                              ? AppColors.secondary
                              : (isDownloading ? AppColors.primary : null),
                          onTap: () async {
                            if (isDownloaded) {
                              await downloads.remove(track.id);
                              AppMessenger.show('Removed from downloads');
                            } else {
                              try {
                                await downloads.download(track);
                                AppMessenger.show('Downloaded for offline playback');
                              } catch (e) {
                                AppMessenger.showError(e);
                              }
                            }
                          },
                        ),
                        _ActionIcon(
                          icon: Icons.queue_music_rounded,
                          label: 'Up Next',
                          badgeCount: pc.queue.tracks.length,
                          onTap: () => showQueueSheet(context),
                        ),
                        _ActionIcon(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          onTap: () => TrackActions.share(context, track),
                        ),
                        _ActionIcon(
                          icon: Icons.playlist_add_rounded,
                          label: 'Save',
                          onTap: () => TrackActions.addToPlaylist(context, track),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(icon, size: 22, color: iconColor ?? AppColors.textSecondaryDark),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

