import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/music_repository.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/search_result.dart';
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
import 'artist_screen.dart';
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
    'Trending',
    'Bollywood',
    'Chill',
    'Workout',
    'Pop',
    'Focus',
    'Devotional',
    'Party',
    'Acoustic',
  ];

  late Future<List<Track>> _trendingFuture;
  late Future<List<Track>> _newReleasesFuture;
  late Future<List<Track>> _spotlightFuture;
  Future<List<Track>>? _categoryTracksFuture;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final MusicRepository repo = context.read<MusicRepository>();
      _trendingFuture = repo.trending(limit: 8);
      _newReleasesFuture = repo.newReleases(limit: 8);
      _spotlightFuture = repo.trending(limit: 1);
    }
  }

  void _onMoodSelected(String mood, MusicRepository repo) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
      if (mood != 'All') {
        _categoryTracksFuture = _fetchCategoryTracks(mood, repo);
      } else {
        _categoryTracksFuture = null;
      }
    });
  }

  Future<List<Track>> _fetchCategoryTracks(String category, MusicRepository repo) async {
    try {
      final SearchResult res = await repo.search(category, limit: 16);
      if (res.tracks.isNotEmpty) {
        return res.tracks;
      }
    } catch (_) {}
    return repo.trending(limit: 16);
  }

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
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                // 1. Header with Brand Mark and Actions
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // 2. Greeting & Mood Filter Carousel
                SliverToBoxAdapter(
                  child: _buildGreetingAndMoods(context, repo),
                ),

                // Dynamic Category View or Standard Discovery Soundscape
                if (_selectedMood != 'All') ...<Widget>[
                  SliverToBoxAdapter(
                    child: _buildCategoryView(context, repo, playback),
                  ),
                ] else ...<Widget>[
                  // 3. Recently Played (if history exists) or Trending Right Now (no dead space!)
                  SliverToBoxAdapter(
                    child: _buildRecentlyPlayedOrTrending(context, library, repo),
                  ),

                  // 4. Jump Back In / Fresh Releases Carousel
                  SliverToBoxAdapter(
                    child: _buildJumpBackInSection(context, repo),
                  ),

                  // 5. Featured Release Spotlight Banner
                  SliverToBoxAdapter(
                    child: _buildFeaturedSpotlight(context),
                  ),

                  // 6. Made For You Curated Algorithmic Mixes
                  SliverToBoxAdapter(
                    child: _buildMadeForYouSection(context, repo),
                  ),

                  // 7. Trending Now & Fresh Picks (Ranked 1..5)
                  SliverToBoxAdapter(
                    child: _buildTrendingRankedSection(context, playback),
                  ),

                  // 8. Featured Artists & Curators
                  SliverToBoxAdapter(
                    child: _buildFeaturedCuratorsSection(context),
                  ),
                ],

                // Clean subtle branding footer
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 28),
                    child: Center(
                      child: Text(
                        'Kalpkrut Infotech',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.textMuted.withValues(alpha: 0.7),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
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
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
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
                      color: context.textSecondary,
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
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
                tooltip: 'Notifications',
                onPressed: () => _showNotificationCenter(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationCenter(BuildContext context) {
    final bool isDark = context.isDarkMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_rounded,
                              color: AppColors.secondary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Notification Center',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNotificationTile(
                  context,
                  title: 'Welcome to EchoFlow Music',
                  message: 'Stream millions of tracks in Hi-Res Lossless quality anytime, anywhere.',
                  timestamp: 'Just now',
                  icon: Icons.graphic_eq_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 10),
                _buildNotificationTile(
                  context,
                  title: 'Your Daily Mix is Ready',
                  message: 'Personalized recommendations and trending hits curated for your mood.',
                  timestamp: '1h ago',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 10),
                _buildNotificationTile(
                  context,
                  title: 'Offline Music Ready',
                  message: 'Download your favorite songs and playlists to listen seamlessly without internet.',
                  timestamp: 'Today',
                  icon: Icons.download_done_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context, {
    required String title,
    required String message,
    required String timestamp,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? AppColors.surfaceContainer
            : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      timestamp,
                      style: TextStyle(color: context.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: context.textSecondary, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingAndMoods(BuildContext context, MusicRepository repo) {
    final bool isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DISCOVER & STREAM',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${Formatters.greeting()}, ${context.watch<LibraryController>().displayName}',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Mood filter carousel pills
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext ctx, int i) {
                final String mood = _moods[i];
                final bool active = mood == _selectedMood;
                final Color inactiveBg = isDark
                    ? AppColors.surfaceContainerHigh.withValues(alpha: 0.65)
                    : AppColors.lightElevatedSurface;
                final Color inactiveBorder = isDark ? AppColors.borderSubtle : AppColors.lightBorder;

                return InkWell(
                  onTap: () => _onMoodSelected(mood, repo),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.brandGradient : null,
                      color: active ? null : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? Colors.transparent : inactiveBorder,
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
                          color: active ? Colors.white : context.textSecondary,
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

  Widget _buildRecentlyPlayedOrTrending(
    BuildContext context,
    LibraryController library,
    MusicRepository repo,
  ) {
    final bool hasHistory = library.history.isNotEmpty;

    if (hasHistory) {
      final List<Track> historyTracks =
          library.history.map((h) => h.track).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Recently Played',
            subtitle: 'Continue your personal listening session',
            topPadding: AppSpacing.sm,
            actionLabel: 'See all',
            onAction: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TrackListScreen(
                  title: 'Recently Played',
                  tracks: historyTracks,
                ),
              ));
            },
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: historyTracks.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext ctx, int i) {
                final Track track = historyTracks[i];
                return MediaCard.forTrack(
                  track: track,
                  onTap: () => TrackActions.play(context, track, queue: historyTracks),
                  onPlay: () => TrackActions.play(context, track, queue: historyTracks),
                  width: 136,
                );
              },
            ),
          ),
        ],
      );
    }

    // Fallback when no history exists: Compact Trending Charts (prevents any dead space)
    return FutureBuilder<List<Track>>(
      future: _trendingFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
        final List<Track> tracks = snapshot.data ?? <Track>[];
        if (tracks.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: 'Trending Right Now',
              subtitle: 'Top global charts and viral hits',
              topPadding: AppSpacing.sm,
              actionLabel: 'See all',
              onAction: () async {
                final List<Track> all = await repo.trending(limit: 30);
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TrackListScreen(title: 'Trending Charts', tracks: all),
                  ));
                }
              },
            ),
            SizedBox(
              height: 196,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, __) => _buildTrackSkeletonCard(context),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (BuildContext ctx, int i) {
                        final Track track = tracks[i];
                        return MediaCard.forTrack(
                          track: track,
                          badgeText: '#${i + 1}',
                          badgeColor: i < 3 ? AppColors.secondary : null,
                          onTap: () => TrackActions.play(context, track, queue: tracks),
                          onPlay: () => TrackActions.play(context, track, queue: tracks),
                          width: 136,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryView(
    BuildContext context,
    MusicRepository repo,
    PlaybackController playback,
  ) {
    return FutureBuilder<List<Track>>(
      future: _categoryTracksFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final List<Track> tracks = snapshot.data ?? <Track>[];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 12),
              // Category Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_selectedMood SOUNDSCAPE'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (tracks.isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => TrackActions.play(context, tracks.first, queue: tracks),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Curated $_selectedMood',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Streaming tracks in $_selectedMood category',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tracks List
              if (isLoading)
                Column(
                  children: List<Widget>.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.isDarkMode
                              ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
                              : AppColors.lightElevatedSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              else if (tracks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No tracks found in this category'),
                  ),
                )
              else
                Column(
                  children: <Widget>[
                    for (int i = 0; i < tracks.length; i++) ...<Widget>[
                      TrackTile(
                        track: tracks[i],
                        dense: false,
                        isPlaying: playback.currentTrack?.id == tracks[i].id && playback.isPlaying,
                        onTap: () => TrackActions.play(context, tracks[i], queue: tracks),
                        onMenu: () => showTrackActionsSheet(context, tracks[i]),
                      ),
                      if (i < tracks.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJumpBackInSection(BuildContext context, MusicRepository repo) {
    return FutureBuilder<List<Track>>(
      future: _newReleasesFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Track>> snap) {
        final bool isLoading = snap.connectionState == ConnectionState.waiting;
        final List<Track> tracks = snap.data ?? <Track>[];
        if (!isLoading && tracks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: 'Fresh Releases',
              subtitle: 'Latest tracks and singles hot off the press',
              topPadding: AppSpacing.sm,
              actionLabel: 'See all',
              onAction: () async {
                final List<Track> all = await repo.newReleases(limit: 20);
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TrackListScreen(title: 'Fresh Releases', tracks: all),
                  ));
                }
              },
            ),
            SizedBox(
              height: 204,
              child: isLoading
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, __) => _buildTrackSkeletonCard(context),
                    )
                  : ListView.separated(
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
                          width: 136,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackSkeletonCard(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final Color baseColor = isDark
        ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
        : AppColors.lightElevatedSurface;

    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: isDark ? Colors.white12 : Colors.black12,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 65,
            height: 10,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSpotlight(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: FutureBuilder<List<Track>>(
        future: _spotlightFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
          final Track? track = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
          return EchoGlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppSpacing.radiusXl,
            backgroundColor: isDark
                ? null
                : AppColors.lightSurface,
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
                      AppColors.surfaceContainer.withValues(alpha: 0.8),
                      AppColors.primary.withValues(alpha: 0.15),
                    ],
                  )
                : null,
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
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FEATURED SPOTLIGHT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceContainerLowest.withValues(alpha: 0.6)
                            : AppColors.lightElevatedSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, color: context.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Artwork(
                      url: track?.artworkUrl,
                      size: 68,
                      radius: AppSpacing.radiusMd,
                      showGlow: isDark,
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
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track?.artistNames ?? 'Hyperion Drive • Featured Stream',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceContainerHighest : AppColors.lightElevatedSurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Spatial Audio',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lossless 24-bit',
                                style: TextStyle(fontSize: 11, color: context.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 16,
                          color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '48k Hi-Res Lossless',
                          style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppColors.primary : AppColors.lightPrimaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () {
                        if (track != null) {
                          TrackActions.play(context, track);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Listen Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
          height: 236,
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
              color: context.isDarkMode ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDarkMode ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.trending_up_rounded,
                  size: 14,
                  color: context.isDarkMode ? AppColors.secondary : AppColors.lightSecondaryAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  'Live Chart',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.isDarkMode ? AppColors.secondary : AppColors.lightSecondaryAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Track>>(
          future: _trendingFuture,
          builder: (BuildContext context, AsyncSnapshot<List<Track>> snapshot) {
            final List<Track> tracks = (snapshot.data ?? <Track>[]).take(5).toList();
            if (tracks.isEmpty) {
              return const SizedBox.shrink();
            }
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

  Widget _buildFeaturedCuratorsSection(BuildContext context) {
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
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const ArtistScreen(
                      artist: Artist(
                        id: 'curator:kaelen_vance',
                        providerId: 'curated',
                        providerArtistId: 'kaelen_vance',
                        name: 'Kaelen Vance',
                        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
                      ),
                    ),
                  ));
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Lyra Nova',
                followerCount: '5.8M fans',
                imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const ArtistScreen(
                      artist: Artist(
                        id: 'curator:lyra_nova',
                        providerId: 'curated',
                        providerArtistId: 'lyra_nova',
                        name: 'Lyra Nova',
                        imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
                      ),
                    ),
                  ));
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Nox Theory',
                followerCount: '1.2M fans',
                imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const ArtistScreen(
                      artist: Artist(
                        id: 'curator:nox_theory',
                        providerId: 'curated',
                        providerArtistId: 'nox_theory',
                        name: 'Nox Theory',
                        imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                      ),
                    ),
                  ));
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Echo Editorial',
                followerCount: 'Official Flow',
                imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const ArtistScreen(
                      artist: Artist(
                        id: 'curator:echo_editorial',
                        providerId: 'curated',
                        providerArtistId: 'echo_editorial',
                        name: 'Echo Editorial',
                        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
                      ),
                    ),
                  ));
                },
              ),
              const SizedBox(width: AppSpacing.md),
              EchoCuratorCard(
                name: 'Cora Chen',
                followerCount: '890K fans',
                imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const ArtistScreen(
                      artist: Artist(
                        id: 'curator:cora_chen',
                        providerId: 'curated',
                        providerArtistId: 'cora_chen',
                        name: 'Cora Chen',
                        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                      ),
                    ),
                  ));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
