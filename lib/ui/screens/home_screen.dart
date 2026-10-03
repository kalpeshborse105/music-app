import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/music_repository.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/artwork.dart';
import '../widgets/cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';
import 'list_screen.dart';
import 'search_screen.dart';

/// Stitch Nocturnal Home Screen combining ambient glowing background, mood filters,
/// 6-card bento grid, Jump Back In carousel, Featured Spotlight, Made For You mixes,
/// ranked trending tracks with live soundbars, and featured curator avatars.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMood = 'All';

  static const List<String> _moods = <String>[
    'All',
    'Workout',
    'Chill',
    'Focus',
    'Electronic',
    'Acoustic',
  ];

  @override
  Widget build(BuildContext context) {
    final MusicRepository repo = context.read<MusicRepository>();
    final LibraryController library = context.watch<LibraryController>();
    final PlaybackController playback = context.watch<PlaybackController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Bioluminescent ambient glow orbs in dark mode
          if (isDark) ...<Widget>[
            const Positioned(
              top: -40,
              left: -60,
              child: EchoAmbientGlowOrb(
                color: AppColors.primary,
                size: 280,
                blurRadius: 100,
                opacity: 0.16,
              ),
            ),
            const Positioned(
              top: 240,
              right: -80,
              child: EchoAmbientGlowOrb(
                color: AppColors.secondary,
                size: 300,
                blurRadius: 110,
                opacity: 0.14,
              ),
            ),
          ],

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: <Widget>[
                // 1. Header with Brand Mark and Actions
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // 2. Greeting & Mood Filter Carousel
                SliverToBoxAdapter(
                  child: _buildGreetingAndMoods(context),
                ),

                // 3. Quick Access 6-Card Bento Grid
                SliverToBoxAdapter(
                  child: _buildQuickAccessGrid(context, library, repo),
                ),

                // 4. Jump Back In / Recent & New Releases Carousel
                SliverToBoxAdapter(
                  child: _buildJumpBackInSection(context, repo),
                ),

                // 5. Featured Release Spotlight Banner
                SliverToBoxAdapter(
                  child: _buildFeaturedSpotlight(context, repo),
                ),

                // 6. Made For You Curated Algorithmic Mixes
                SliverToBoxAdapter(
                  child: _buildMadeForYouSection(context, repo),
                ),

                // 7. Trending Now & Fresh Picks (Ranked 1..5)
                SliverToBoxAdapter(
                  child: _buildTrendingRankedSection(context, repo, playback),
                ),

                // 8. Featured Artists & Curators
                SliverToBoxAdapter(
                  child: _buildFeaturedCuratorsSection(context, repo),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'Home',
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
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 22),
                tooltip: 'Search',
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SearchScreen(),
                  ));
                },
              ),
              Stack(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 22),
                    tooltip: 'Notifications',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No new notifications')),
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingAndMoods(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'NOCTURNAL SOUNDSCAPE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${Formatters.greeting()}, Listener',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Mood filter carousel pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext ctx, int i) {
                final String mood = _moods[i];
                final bool active = mood == _selectedMood;
                return InkWell(
                  onTap: () => setState(() => _selectedMood = mood),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.brandGradient : null,
                      color: active ? null : AppColors.surfaceContainerHigh.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? Colors.transparent : AppColors.borderSubtle,
                      ),
                      boxShadow: active
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        mood,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppColors.onPrimaryContainer : AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(
    BuildContext context,
    LibraryController library,
    MusicRepository repo,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: FutureBuilder<List<Track>>(
        future: repo.trending(limit: 6),
        builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
          final List<Track> tracks = snapshot.data ?? <Track>[];
          final String trackCount = '${library.likedTracks.length} tracks';

          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.7,
            children: <Widget>[
              EchoBentoCard(
                title: 'Liked Songs',
                subtitle: trackCount,
                icon: Icons.favorite_rounded,
                iconGradient: AppColors.likedSongsGradient,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TrackListScreen(
                      title: 'Liked Songs',
                      tracks: library.likedTracks,
                    ),
                  ));
                },
                onPlay: library.likedTracks.isNotEmpty
                    ? () => TrackActions.play(context, library.likedTracks.first, queue: library.likedTracks)
                    : null,
              ),
              EchoBentoCard(
                title: 'Heavy Rotation',
                subtitle: 'Updated today',
                imageUrl: tracks.isNotEmpty ? tracks[0].artworkUrl : null,
                icon: Icons.repeat_rounded,
                onTap: () {
                  if (tracks.isNotEmpty) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Heavy Rotation', tracks: tracks),
                    ));
                  }
                },
                onPlay: tracks.isNotEmpty ? () => TrackActions.play(context, tracks[0], queue: tracks) : null,
              ),
              EchoBentoCard(
                title: 'Daily Mix 01',
                subtitle: 'Sonn, Tycho, ODESZA',
                imageUrl: tracks.length > 1 ? tracks[1].artworkUrl : null,
                icon: Icons.auto_awesome_rounded,
                onTap: () {
                  if (tracks.length > 1) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Daily Mix 01', tracks: tracks),
                    ));
                  }
                },
                onPlay: tracks.length > 1 ? () => TrackActions.play(context, tracks[1], queue: tracks) : null,
              ),
              EchoBentoCard(
                title: 'Cyber Chill',
                subtitle: 'Ambient & Glitch',
                imageUrl: tracks.length > 2 ? tracks[2].artworkUrl : null,
                icon: Icons.headphones_rounded,
                onTap: () {
                  if (tracks.length > 2) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Cyber Chill', tracks: tracks),
                    ));
                  }
                },
                onPlay: tracks.length > 2 ? () => TrackActions.play(context, tracks[2], queue: tracks) : null,
              ),
              EchoBentoCard(
                title: 'Synth Nights',
                subtitle: 'Retro Electro',
                imageUrl: tracks.length > 3 ? tracks[3].artworkUrl : null,
                icon: Icons.graphic_eq_rounded,
                onTap: () {
                  if (tracks.length > 3) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Synth Nights', tracks: tracks),
                    ));
                  }
                },
                onPlay: tracks.length > 3 ? () => TrackActions.play(context, tracks[3], queue: tracks) : null,
              ),
              EchoBentoCard(
                title: 'Acoustic Soul',
                subtitle: 'Warm Raw Chords',
                imageUrl: tracks.length > 4 ? tracks[4].artworkUrl : null,
                icon: Icons.music_note_rounded,
                onTap: () {
                  if (tracks.length > 4) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Acoustic Soul', tracks: tracks),
                    ));
                  }
                },
                onPlay: tracks.length > 4 ? () => TrackActions.play(context, tracks[4], queue: tracks) : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJumpBackInSection(BuildContext context, MusicRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Jump Back In',
          subtitle: 'Continue your sonic journey',
          actionLabel: 'See all',
          onAction: () async {
            final List<Track> tracks = await repo.newReleases(limit: 20);
            if (context.mounted) {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TrackListScreen(title: 'Jump Back In', tracks: tracks),
              ));
            }
          },
        ),
        SizedBox(
          height: 204,
          child: FutureBuilder<List<Track>>(
            future: repo.newReleases(limit: 8),
            builder: (BuildContext context, AsyncSnapshot<List<Track>> snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<Track> tracks = snap.data!;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (BuildContext ctx, int i) {
                  final Track track = tracks[i];
                  return MediaCard.forTrack(
                    track: track,
                    onTap: () => TrackActions.play(context, track, queue: tracks),
                    onPlay: () => TrackActions.play(context, track, queue: tracks),
                    width: 144,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSpotlight(BuildContext context, MusicRepository repo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: FutureBuilder<List<Track>>(
        future: repo.trending(limit: 1),
        builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
          final Track? track = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
          return EchoGlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppSpacing.radiusXl,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
                AppColors.surfaceContainer.withValues(alpha: 0.8),
                AppColors.primary.withValues(alpha: 0.15),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'FEATURED SPOTLIGHT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Artwork(
                      url: track?.artworkUrl,
                      size: 72,
                      radius: AppSpacing.radiusMd,
                      showGlow: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            track?.title ?? 'Overdrive Horizon',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track?.artistNames ?? 'Hyperion Drive • Featured Stream',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Spatial Audio',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Lossless 24-bit',
                                style: TextStyle(fontSize: 11, color: AppColors.outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text('48k Hi-Res Lossless', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        if (track != null) {
                          TrackActions.play(context, track);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Listen Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMadeForYouSection(BuildContext context, MusicRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Made For You',
          subtitle: 'Tuned specifically to your acoustic habits',
        ),
        SizedBox(
          height: 244,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
              EchoMixCard(
                title: 'Discover Weekly',
                subtitle: 'Every Monday refreshed deep cuts and debuts.',
                stats: '30 songs',
                icon: Icons.auto_awesome_rounded,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF8B5CF6), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  final List<Track> tracks = await repo.recommendations(limit: 30);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Discover Weekly', tracks: tracks),
                    ));
                  }
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoMixCard(
                title: 'Release Radar',
                subtitle: 'Catch brand-new singles from artists you love.',
                stats: '24 songs',
                icon: Icons.radar_rounded,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF06B6D4), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  final List<Track> tracks = await repo.newReleases(limit: 24);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Release Radar', tracks: tracks),
                    ));
                  }
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoMixCard(
                title: 'Flow Chillout',
                subtitle: 'Downtempo lo-fi and gentle dream pop.',
                stats: '50 songs',
                icon: Icons.spa_rounded,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFEC4899), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  final List<Track> tracks = await repo.trending(limit: 50);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(title: 'Flow Chillout', tracks: tracks),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingRankedSection(
    BuildContext context,
    MusicRepository repo,
    PlaybackController pc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Trending Now & Fresh Picks',
          subtitle: 'Global top streams this week',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.trending_up_rounded, size: 14, color: AppColors.secondary),
                SizedBox(width: 4),
                Text('Live Chart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary)),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Track>>(
          future: repo.trending(limit: 5),
          builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }
            final List<Track> tracks = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < tracks.length; i++) ...<Widget>[
                    TrackTile(
                      index: i,
                      track: tracks[i],
                      isCurrent: pc.currentTrack?.id == tracks[i].id,
                      isPlaying: pc.isPlaying && pc.currentTrack?.id == tracks[i].id,
                      onTap: () => TrackActions.play(context, tracks[i], queue: tracks),
                      onMenu: () => showTrackActionsSheet(context, tracks[i]),
                    ),
                    if (i < tracks.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedCuratorsSection(BuildContext context, MusicRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Featured Artists & Curators',
          subtitle: 'Creators shaping your daily sound',
          actionLabel: 'Explore',
          onAction: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SearchScreen(),
            ));
          },
        ),
        SizedBox(
          height: 136,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
              EchoCuratorCard(
                name: 'Kaelen Vance',
                followerCount: '3.4M fans',
                imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
                onTap: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Lyra Nova',
                followerCount: '5.8M fans',
                imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
                onTap: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Nox Theory',
                followerCount: '1.2M fans',
                imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                onTap: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Echo Editorial',
                followerCount: 'Official Flow',
                imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
                onTap: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Cora Chen',
                followerCount: '890K fans',
                imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
