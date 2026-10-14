import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
import '../../domain/models/radio_station.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/artwork.dart';
import '../widgets/glass_card.dart';

/// Live radio stations are read from the shared API/Supabase catalogue.
/// This screen deliberately has no hardcoded station or test-stream fallback.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late Future<List<RadioStation>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _loadStations();
  }

  Future<List<RadioStation>> _loadStations() async {
    final MusicRepository repository = context.read<MusicRepository>();
    final List<Map<String, dynamic>> rows = await repository.fetchRadioStations();
    return rows
        .map(RadioStation.fromJson)
        .where((RadioStation station) =>
            station.isLive && station.streamUrl.trim().isNotEmpty)
        .toList();
  }

  void _refresh() {
    setState(() => _stationsFuture = _loadStations());
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackController playback = context.watch<PlaybackController>();
    final Track? currentTrack = playback.snapshot.track;
    final bool isPlaying = playback.snapshot.playing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
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
            child: FutureBuilder<List<RadioStation>>(
              future: _stationsFuture,
              builder: (BuildContext context, AsyncSnapshot<List<RadioStation>> snapshot) {
                final List<RadioStation> stations = snapshot.data ?? <RadioStation>[];
                return CustomScrollView(
                  slivers: <Widget>[
                    SliverAppBar(
                      floating: true,
                      pinned: false,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
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
                            'Live Radio',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                      actions: <Widget>[
                        IconButton(
                          tooltip: 'Refresh stations',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        ),
                      ],
                    ),
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
                                  gradient: AppColors.heroGradient,
                                ),
                                child: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'LIVE ONLINE STREAMS',
                                      style: TextStyle(color: AppColors.neonCyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Radio stations',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Stations published by the administrator appear here.',
                                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (snapshot.hasError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: EchoGlassCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: 16,
                            child: Column(
                              children: <Widget>[
                                const Icon(Icons.cloud_off_rounded, color: AppColors.onSurfaceVariant, size: 36),
                                const SizedBox(height: 10),
                                const Text('Radio stations could not be loaded', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                const Text('Check the connection and retry. No demo stations are shown.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                                const SizedBox(height: 12),
                                FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (stations.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: EchoGlassCard(
                            padding: EdgeInsets.all(22),
                            borderRadius: 16,
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.radio_outlined, color: AppColors.onSurfaceVariant, size: 38),
                                SizedBox(height: 10),
                                Text('No live stations configured', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                SizedBox(height: 6),
                                Text('An administrator must add and publish a verified station stream.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final RadioStation station = stations[index];
                              final bool isThisPlaying = currentTrack?.id == 'radio:${station.id}' && isPlaying;
                              final bool isThisLoaded = currentTrack?.id == 'radio:${station.id}';
                              final String detail = <String>[
                                if (station.frequency.trim().isNotEmpty) station.frequency.trim(),
                                if (station.state.trim().isNotEmpty) station.state.trim(),
                              ].join(' • ');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: EchoGlassCard(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 16,
                                  borderColor: isThisLoaded ? AppColors.neonCyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
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
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: SizedBox(
                                            width: 58,
                                            height: 58,
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: <Widget>[
                                                Artwork(url: station.artworkUrl, size: 58, radius: 12),
                                                if (isThisPlaying)
                                                  Container(
                                                    color: Colors.black.withValues(alpha: 0.45),
                                                    child: const Center(
                                                      child: Icon(Icons.graphic_eq_rounded, color: AppColors.neonCyan, size: 26),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                station.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: isThisLoaded ? AppColors.neonCyan : Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                              ),
                                              if (detail.isNotEmpty) ...<Widget>[
                                                const SizedBox(height: 3),
                                                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10.5)),
                                              ],
                                              if (station.tagline.trim().isNotEmpty) ...<Widget>[
                                                const SizedBox(height: 3),
                                                Text(station.tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isThisPlaying ? AppColors.neonCyan : AppColors.surfaceContainerHighest,
                                          ),
                                          child: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: isThisPlaying ? Colors.black : Colors.white, size: 24),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: stations.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
