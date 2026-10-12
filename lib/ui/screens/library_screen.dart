import 'package:flutter/material.dart' hide SearchController;
import 'package:provider/provider.dart';

import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/history_entry.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/track.dart';
import '../../domain/providers/local_provider.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../../state/search_controller.dart';
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
import 'onboarding_auth_screen.dart';

/// Unified Library & Search Discovery Screen.
/// Combines live JioSaavn-style search, genre cards, filter tabs,
/// quick access cards (Liked Songs, Downloads, Device Audio), and user playlists.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _GenreCardData {
  final String title;
  final Color color1;
  final Color color2;
  final IconData icon;
  final String emoji;

  const _GenreCardData(this.title, this.color1, this.color2, this.icon, {this.emoji = ''});
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'All';
  String _currentSort = 'Recently Added';
  bool _isGridView = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _filters = <String>[
    'All',
    'Songs',
    'Artists',
    'Albums',
    'Playlists',
    'Liked Songs',
    'Downloaded',
    'Device Audio',
  ];

  static const List<_GenreCardData> _genres = <_GenreCardData>[
    _GenreCardData('Ambient', Color(0xFF1E3A8A), Color(0xFF2563EB), Icons.nightlight_round, emoji: '🌌'),
    _GenreCardData('Synthwave', Color(0xFF701A75), Color(0xFFA21CAF), Icons.location_city_rounded, emoji: '🌆'),
    _GenreCardData('Chill', Color(0xFF065F46), Color(0xFF059669), Icons.eco_rounded, emoji: '🍃'),
    _GenreCardData('Electronic', Color(0xFF0284C7), Color(0xFF0EA5E9), Icons.bolt_rounded, emoji: '⚡'),
    _GenreCardData('Focus', Color(0xFF4338CA), Color(0xFF6366F1), Icons.psychology_rounded, emoji: '🧠'),
    _GenreCardData('Workout', Color(0xFF991B1B), Color(0xFFDC2626), Icons.local_fire_department_rounded, emoji: '🔥'),
    _GenreCardData('Acoustic', Color(0xFFC2410C), Color(0xFFEA580C), Icons.music_note_rounded, emoji: '🎸'),
    _GenreCardData('Bollywood & Regional', Color(0xFFB45309), Color(0xFFE11D48), Icons.library_music_rounded, emoji: '🎶'),
    _GenreCardData('Punjabi Hits', Color(0xFFD97706), Color(0xFFF59E0B), Icons.speaker_group_rounded, emoji: '🥁'),
    _GenreCardData('Bhakti & Aarti', Color(0xFFEA580C), Color(0xFFEAB308), Icons.self_improvement_rounded, emoji: '🕉️'),
    _GenreCardData('Romantic & Love', Color(0xFFBE185D), Color(0xFFF43F5E), Icons.favorite_rounded, emoji: '💖'),
    _GenreCardData('Lo-Fi & Beats', Color(0xFF0369A1), Color(0xFF0D9488), Icons.coffee_rounded, emoji: '☕'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final SearchController search = context.read<SearchController>();
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (search.status == SearchStatus.loaded && search.query.isNotEmpty) {
        search.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchController search = context.watch<SearchController>();
    final LibraryController library = context.watch<LibraryController>();
    final DownloadsController downloads = context.watch<DownloadsController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync input text if search was cleared externally
    if (search.query.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    final int totalCount = library.likedTracks.length +
        library.playlists.length +
        downloads.downloads.length +
        library.localTracks.length;

    final bool isSearching = search.query.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          if (isDark) ...<Widget>[
            const Positioned(
              top: 40,
              left: -40,
              child: EchoAmbientGlowOrb(
                color: AppColors.primary,
                size: 260,
                blurRadius: 100,
                opacity: 0.12,
              ),
            ),
          ],
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
              backgroundColor: isDark ? AppColors.surfaceContainerHigh : Colors.white,
              onRefresh: () async {
                await library.syncWithSupabase();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: <Widget>[
                  // Header Bar with Brand & Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
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
                                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Library & Search',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalCount items',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              gradient: AppColors.heroGradient,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              onPressed: () => _promptCreatePlaylist(context, library),
                              tooltip: 'New Playlist',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Integrated Search Bar at Top of Library
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: search.onQueryChanged,
                        onSubmitted: (String v) {
                          search.submit(v);
                          library.addRecentSearch(v);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, albums, genres...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: isSearching
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    search.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Category Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: _filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (BuildContext ctx, int i) {
                            final String f = _filters[i];
                            final bool active = f == _selectedFilter;
                            final Color activeBg = isDark ? AppColors.primary : AppColors.lightPrimaryAccent;
                            final Color inactiveBg = isDark
                                ? AppColors.surfaceContainerHigh.withValues(alpha: 0.6)
                                : AppColors.lightElevatedSurface;
                            final Color inactiveBorder = isDark ? AppColors.borderSubtle : AppColors.lightBorder;

                            return InkWell(
                              onTap: () => setState(() => _selectedFilter = f),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: active ? AppColors.brandGradient : null,
                                  color: active ? activeBg : inactiveBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: active ? Colors.transparent : inactiveBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    f,
                                    style: TextStyle(
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
                    ),
                  ),

                  // If user is actively searching: render live search states & results
                  if (isSearching) ..._buildSearchSlivers(context, search)
                  // Otherwise: render JioSaavn Discovery Cards + User's Personal Library
                  else ..._buildLibrarySlivers(context, library, downloads, isDark, search),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search Results Slivers (with Category Filter applied)
  // ---------------------------------------------------------------------------
  List<Widget> _buildSearchSlivers(BuildContext context, SearchController search) {
    if (search.status == SearchStatus.loading) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingView(message: 'Searching music catalog...'),
        ),
      ];
    }

    if (search.status == SearchStatus.error) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: Icons.search_off_rounded,
            title: 'Search failed',
            subtitle: search.errorMessage(),
            actionLabel: 'Retry',
            onAction: () => search.submit(search.query),
          ),
        ),
      ];
    }

    final SearchResult r = search.result;
    if (r.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: Icons.music_off_rounded,
            title: 'No music found',
            subtitle: 'Try searching with a different song or artist name.',
          ),
        ),
      ];
    }

    final bool showAll = _selectedFilter == 'All';
    final List<Widget> slivers = <Widget>[];

    // Artists Row
    if ((showAll || _selectedFilter == 'Artists') && r.artists.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Artists'),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: r.artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext c, int i) {
                final a = r.artists[i];
                return MediaCard.forArtist(
                  artist: a,
                  onTap: () => TrackActions.openArtist(context, a),
                );
              },
            ),
          ),
        ),
      );
    }

    // Albums Row
    if ((showAll || _selectedFilter == 'Albums') && r.albums.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Albums'),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: r.albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext c, int i) {
                final al = r.albums[i];
                return MediaCard.forAlbum(
                  album: al,
                  onTap: () => TrackActions.openAlbum(context, al),
                );
              },
            ),
          ),
        ),
      );
    }

    // Tracks / Songs
    if ((showAll || _selectedFilter == 'Songs') && r.tracks.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Tracks & Songs'),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final t = r.tracks[i];
                return TrackTile(
                  track: t,
                  onTap: () => TrackActions.play(context, t, queue: r.tracks),
                  onMenu: () => showTrackActionsSheet(context, t),
                );
              },
              childCount: r.tracks.length,
            ),
          ),
        ),
      );
    }

    // Playlists Row
    if ((showAll || _selectedFilter == 'Playlists') && r.playlists.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Playlists'),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: r.playlists.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext c, int i) {
                final p = r.playlists[i];
                return MediaCard.forPlaylist(
                  playlist: p,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                  )),
                );
              },
            ),
          ),
        ),
      );
    }

    if (search.loadingMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return slivers;
  }

  // ---------------------------------------------------------------------------
  // Personal Library & Discovery Slivers
  // ---------------------------------------------------------------------------
  List<Widget> _buildLibrarySlivers(
    BuildContext context,
    LibraryController library,
    DownloadsController downloads,
    bool isDark,
    SearchController search,
  ) {
    final List<Widget> slivers = <Widget>[];

    // Recent search tags (if available)
    if (library.recentSearches.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'RECENT SEARCHES',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.secondary,
                  ),
                ),
                TextButton(
                  onPressed: library.clearRecentSearches,
                  child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: library.recentSearches.map((String q) {
                return ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15, color: AppColors.secondary),
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _searchController.text = q;
                    search.submit(q);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    // Top Discovery & Genres Bento Cards (Explore Genres & Moods)
    if (_selectedFilter == 'All') {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                SizedBox(width: 6),
                Text(
                  'Explore Genres & Moods',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.62,
              ),
              itemCount: _genres.length,
              itemBuilder: (BuildContext ctx, int i) {
                final g = _genres[i];
                return InkWell(
                  onTap: () {
                    _searchController.text = g.title;
                    search.submit(g.title);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[g.color1, g.color2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: g.color1.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: g.emoji.isNotEmpty
                              ? Text(g.emoji, style: const TextStyle(fontSize: 19))
                              : Icon(g.icon, color: Colors.white, size: 20),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                g.title,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Browse →',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Pinned Quick Access Bento Cards (Liked Songs, Downloads, Device Audio)
    if (_selectedFilter == 'All') {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Text(
                      'QUICK ACCESS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.outline,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.push_pin_rounded, size: 14, color: AppColors.outline),
                  ],
                ),
                const SizedBox(height: 8),

                // Liked Songs Primary Bento Card
                EchoGlassCard(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(
                        title: 'Liked Songs',
                        tracks: library.likedTracks,
                      ),
                    ));
                  },
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppSpacing.radiusLg,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          gradient: AppColors.likedSongsGradient,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Row(
                              children: <Widget>[
                                Text(
                                  'Liked Songs',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.secondary),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-playlist • ${library.likedTracks.length} tracks',
                              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryLight, size: 28),
                        onPressed: library.likedTracks.isNotEmpty
                            ? () => TrackActions.play(context, library.likedTracks.first, queue: library.likedTracks)
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 2-card sub-grid: Downloaded & Device Audio
                Row(
                  children: <Widget>[
                    Expanded(
                      child: EchoGlassCard(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const DownloadsDetailScreen(),
                          ));
                        },
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderRadius: AppSpacing.radiusLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.download_done_rounded, color: AppColors.secondary, size: 20),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    downloads.humanSize(downloads.totalBytes),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Downloaded',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              '${downloads.downloads.length} offline tracks',
                              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: EchoGlassCard(
                        onTap: () {
                          final provider = context.read<LocalMusicProvider?>();
                          if (provider != null) {
                            library.scanLocal(provider);
                          }
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const LocalMusicScreen(),
                          ));
                        },
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderRadius: AppSpacing.radiusLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.folder_special_rounded, color: AppColors.primaryLight, size: 20),
                                ),
                                const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.outline),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Device Audio',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              library.localScanning
                                  ? 'Scanning...'
                                  : '${library.localTracks.length} files found',
                              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Specific filter handling: Liked Songs
    if (_selectedFilter == 'Liked Songs') {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final t = library.likedTracks[i];
                return TrackTile(
                  track: t,
                  onTap: () => TrackActions.play(context, t, queue: library.likedTracks),
                  onMenu: () => showTrackActionsSheet(context, t),
                );
              },
              childCount: library.likedTracks.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Specific filter handling: Downloaded
    if (_selectedFilter == 'Downloaded') {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final t = downloads.downloads[i].track;
                return TrackTile(
                  track: t,
                  onTap: () => TrackActions.play(context, t),
                  onMenu: () => showTrackActionsSheet(context, t),
                );
              },
              childCount: downloads.downloads.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Specific filter handling: Device Audio
    if (_selectedFilter == 'Device Audio') {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final t = library.localTracks[i];
                return TrackTile(
                  track: t,
                  onTap: () => TrackActions.play(context, t, queue: library.localTracks),
                  onMenu: () => showTrackActionsSheet(context, t),
                );
              },
              childCount: library.localTracks.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Specific filter handling: Artists (Followed Artists)
    if (_selectedFilter == 'Artists') {
      final List<Artist> artists = library.followedArtists;
      if (artists.isEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 48),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Icon(Icons.person_add_alt_1_rounded, size: 48, color: AppColors.outline),
                    SizedBox(height: 12),
                    Text(
                      'No followed artists yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tap "+ Follow" on any artist page to see them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext c, int i) {
                  final Artist a = artists[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryContainer,
                      child: ClipOval(
                        child: Artwork(
                          url: a.imageUrl,
                          size: 52,
                          radius: 26,
                          fallbackIcon: Icons.person_rounded,
                        ),
                      ),
                    ),
                    title: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            a.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 14, color: AppColors.secondary),
                      ],
                    ),
                    subtitle: const Text(
                      'Verified Artist • Following',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => TrackActions.openArtist(context, a),
                      child: const Text('View Profile'),
                    ),
                    onTap: () => TrackActions.openArtist(context, a),
                  );
                },
                childCount: artists.length,
              ),
            ),
          ),
        );
      }
      return slivers;
    }

    // Specific filter handling: Albums
    if (_selectedFilter == 'Albums') {
      final List<Album> albums = library.savedAlbums;
      if (albums.isEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 48),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Icon(Icons.album_rounded, size: 48, color: AppColors.outline),
                    SizedBox(height: 12),
                    Text(
                      'No saved albums yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext c, int i) => MediaCard.forAlbum(
                  album: albums[i],
                  onTap: () => TrackActions.openAlbum(context, albums[i]),
                ),
                childCount: albums.length,
              ),
            ),
          ),
        );
      }
      return slivers;
    }

    // Specific filter handling: Songs
    if (_selectedFilter == 'Songs') {
      final List<Track> songs = <Track>[...library.likedTracks, ...library.localTracks];
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final Track t = songs[i];
                return TrackTile(
                  track: t,
                  onTap: () => TrackActions.play(context, t, queue: songs),
                  onMenu: () => showTrackActionsSheet(context, t),
                );
              },
              childCount: songs.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Collections & Playlists Section
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'COLLECTIONS & PLAYLISTS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.secondary,
                ),
              ),
              Row(
                children: <Widget>[
                  InkWell(
                    onTap: () => _pickSortOption(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            _currentSort,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: !_isGridView ? AppColors.primaryLight : AppColors.outline,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _isGridView = false),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: _isGridView ? AppColors.primaryLight : AppColors.outline,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _isGridView = true),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: _buildCollectionsList(library),
      ),
    );

    // Recently Played Tracks Section
    if (library.history.isNotEmpty && _selectedFilter == 'All') {
      slivers.add(
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Recently Played',
            subtitle: 'Ordered by most recent playback',
            actionLabel: 'Clear',
            onAction: library.clearHistory,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext ctx, int i) {
                final HistoryEntry h = library.history[i];
                return TrackTile(
                  track: h.track,
                  dense: true,
                  onTap: () => TrackActions.play(context, h.track),
                  onMenu: () => showTrackActionsSheet(context, h.track),
                );
              },
              childCount: library.history.length.clamp(0, 8),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildCollectionsList(LibraryController library) {
    final List<Playlist> playlists = library.playlists;

    if (playlists.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: <Widget>[
                const Icon(Icons.queue_music_rounded, size: 36, color: AppColors.outline),
                const SizedBox(height: 8),
                const Text(
                  'No custom playlists yet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                TextButton(
                  onPressed: () => _promptCreatePlaylist(context, library),
                  child: const Text('Create your first playlist'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isGridView) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext ctx, int i) {
            final Playlist p = playlists[i];
            return MediaCard.forPlaylist(
              playlist: p,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                ));
              },
            );
          },
          childCount: playlists.length,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext ctx, int i) {
          final Playlist p = playlists[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EchoGlassCard(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                ));
              },
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderRadius: AppSpacing.radiusMd,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.trackCount} tracks • User Playlist',
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryDark, size: 20),
                    tooltip: 'Playlist options',
                    onPressed: () => _showPlaylistActions(context, p, library),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: playlists.length,
      ),
    );
  }

  void _showPlaylistActions(
      BuildContext context, Playlist p, LibraryController library) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: AppColors.secondary),
              title: const Text('Play Playlist', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                if (p.tracks.isNotEmpty) {
                  TrackActions.playAll(context, p.tracks);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playlist is empty')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Open Playlist'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Playlist'),
              onTap: () {
                Navigator.pop(ctx);
                _promptRenamePlaylist(context, p, library);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete Playlist', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletePlaylist(context, p, library);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _promptRenamePlaylist(
      BuildContext context, Playlist p, LibraryController library) {
    final TextEditingController nameCtrl = TextEditingController(text: p.title);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New playlist title...'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final String newTitle = nameCtrl.text.trim();
              if (newTitle.isNotEmpty && newTitle != p.title) {
                await library.renamePlaylist(p.id, newTitle);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(
      BuildContext context, Playlist p, LibraryController library) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete “${p.title}”?'),
        content: const Text(
          'This will permanently delete this playlist from your library.',
          style: TextStyle(fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await library.deletePlaylist(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _pickSortOption(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String s in <String>['Recently Added', 'Alphabetical', 'Most Played'])
              ListTile(
                leading: Icon(
                  s == _currentSort ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: s == _currentSort ? AppColors.secondary : AppColors.textSecondaryDark,
                ),
                title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  setState(() => _currentSort = s);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _promptCreatePlaylist(BuildContext context, LibraryController library) {
    if (!library.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in to create and sync playlists across devices'),
          action: SnackBarAction(
            label: 'Sign In',
            textColor: AppColors.secondary,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => OnboardingAuthScreen(
                  initialShowAuthForm: true,
                  initialSignUp: false,
                  onComplete: () => Navigator.pop(context),
                ),
              ));
            },
          ),
        ),
      );
      return;
    }

    final TextEditingController nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Create New Playlist'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist title...'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await library.createPlaylist(nameCtrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Offline downloads screen.
class DownloadsDetailScreen extends StatelessWidget {
  const DownloadsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DownloadsController downloads = context.watch<DownloadsController>();
    final records = downloads.downloads;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Offline'),
        actions: <Widget>[
          if (records.isNotEmpty)
            IconButton(
              tooltip: 'Remove all',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: downloads.removeAll,
            ),
        ],
      ),
      body: records.isEmpty
          ? const MessageView(
              icon: Icons.download_outlined,
              title: 'No downloads yet',
              subtitle:
                  'Tracks downloaded for offline listening appear here. Only '
                  'sources that allow offline copies offer this.',
            )
          : Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.sd_storage_rounded, color: AppColors.secondary),
                  title: const Text('Storage used', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${downloads.humanSize(downloads.totalBytes)} • ${records.length} tracks'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (BuildContext c, int i) {
                      final t = records[i].track;
                      return TrackTile(
                        track: t,
                        onTap: () => TrackActions.play(context, t),
                        onMenu: () => showTrackActionsSheet(context, t),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
