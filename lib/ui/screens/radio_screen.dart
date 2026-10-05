import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/radio_station.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/artwork.dart';
import '../widgets/glass_card.dart';

/// Akashvani / All India Radio live stations screen.
class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaybackController playback = context.watch<PlaybackController>();
    final Track? currentTrack = playback.snapshot.track;
    final bool isPlaying = playback.snapshot.playing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          // Ambient glow orbs
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.electricViolet.withValues(alpha: 0.20),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonCyan.withValues(alpha: 0.15),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.radio_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Akashvani Live Radio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hero Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: EchoGlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 20,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: <Color>[Color(0xFFFF9933), Color(0xFF138808)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFFFF9933).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'ALL INDIA RADIO',
                                      style: TextStyle(
                                        color: AppColors.neonCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 10),
                                    SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Akashvani Public Broadcasts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Free 24/7 National, News & Regional Cultural Streams',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Station Cards
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final RadioStation station = RadioStation.stations[index];
                        final bool isThisPlaying =
                            currentTrack?.id == 'radio:${station.id}' && isPlaying;
                        final bool isThisLoaded =
                            currentTrack?.id == 'radio:${station.id}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EchoGlassCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: 16,
                            borderColor: isThisLoaded
                                ? AppColors.neonCyan.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (isThisPlaying) {
                                  playback.pause();
                                } else {
                                  playback.playTrack(station.toTrack());
                                }
                              },
                              child: Row(
                                children: <Widget>[
                                  // Station Artwork
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 58,
                                      height: 58,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: <Widget>[
                                          Artwork(
                                            url: station.artworkUrl,
                                            size: 58,
                                            radius: 12,
                                          ),
                                          if (isThisPlaying)
                                            Container(
                                              color: Colors.black.withValues(alpha: 0.45),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.graphic_eq_rounded,
                                                  color: AppColors.neonCyan,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Station Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Flexible(
                                              child: Text(
                                                station.name,
                                                style: TextStyle(
                                                  color: isThisLoaded
                                                      ? AppColors.neonCyan
                                                      : Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                station.frequency,
                                                style: const TextStyle(
                                                  color: AppColors.onSurfaceVariant,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          station.tagline,
                                          style: const TextStyle(
                                            color: AppColors.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          station.state,
                                          style: TextStyle(
                                            color: isThisLoaded
                                                ? AppColors.electricViolet
                                                : AppColors.outline,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Play/Pause Action Button
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isThisPlaying
                                          ? AppColors.neonCyan
                                          : AppColors.surfaceContainerHighest,
                                      boxShadow: isThisPlaying
                                          ? <BoxShadow>[
                                              BoxShadow(
                                                color: AppColors.neonCyan
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      isThisPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isThisPlaying ? Colors.black : Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: RadioStation.stations.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
