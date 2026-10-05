import 'package:flutter/material.dart' hide SearchController;
import 'package:provider/provider.dart';

import '../../state/library_controller.dart';
import '../../state/search_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';
import 'list_screen.dart';

/// Stitch Search & Explore Screen with genre bento discovery cards,
/// filter pills, recent query tags, and responsive search result lists.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _exploreScroll = ScrollController();
  final ScrollController _resultsScroll = ScrollController();
  String _selectedFilter = 'All';

  static const List<String> _filters = <String>[
    'All',
    'Songs',
    'Artists',
    'Albums',
    'Playlists',
  ];

  static const List<_GenreCardData> _genres = <_GenreCardData>[
    _GenreCardData('Bollywood Hits', Color(0xFFE11D48), Color(0xFFF97316), Icons.movie_filter_rounded),
    _GenreCardData('Punjabi Hits', Color(0xFFF59E0B), Color(0xFFD97706), Icons.speaker_group_rounded),
    _GenreCardData('Bhojpuri Top', Color(0xFF8B5CF6), Color(0xFFEC4899), Icons.star_rounded),
    _GenreCardData('Haryanvi Hits', Color(0xFF10B981), Color(0xFF059669), Icons.graphic_eq_rounded),
    _GenreCardData('Marathi Hits', Color(0xFF3B82F6), Color(0xFF06B6D4), Icons.audiotrack_rounded),
    _GenreCardData('Gujarati Garba', Color(0xFFEF4444), Color(0xFFF97316), Icons.celebration_rounded),
    _GenreCardData('Tamil Hits', Color(0xFFA855F7), Color(0xFF6366F1), Icons.queue_music_rounded),
    _GenreCardData('Telugu Hits', Color(0xFF06B6D4), Color(0xFF3B82F6), Icons.library_music_rounded),
    _GenreCardData('Bengali Melodies', Color(0xFFEC4899), Color(0xFFF43F5E), Icons.music_note_rounded),
    _GenreCardData('Bhakti & Aarti', Color(0xFFF97316), Color(0xFFEAB308), Icons.self_improvement_rounded),
    _GenreCardData('Romantic & Love', Color(0xFFEC4899), Color(0xFFF43F5E), Icons.favorite_rounded),
    _GenreCardData('Lo-Fi & Chill', Color(0xFF06B6D4), Color(0xFF0D9488), Icons.coffee_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _resultsScroll.addListener(_onResultsScroll);
  }

  void _onResultsScroll() {
    if (_resultsScroll.hasClients &&
        _resultsScroll.position.pixels >= _resultsScroll.position.maxScrollExtent - 400) {
      context.read<SearchController>().loadMore();
    }
  }

  @override
  void dispose() {
    _resultsScroll.removeListener(_onResultsScroll);
    _controller.dispose();
    _exploreScroll.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchController search = context.watch<SearchController>();
    if (search.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
    final LibraryController library = context.watch<LibraryController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          if (isDark) ...<Widget>[
            const Positioned(
              top: -30,
              right: -50,
              child: EchoAmbientGlowOrb(
                color: AppColors.secondary,
                size: 260,
                blurRadius: 90,
                opacity: 0.12,
              ),
            ),
          ],
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                // Header & Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                  child: Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            'Kalpkrut Beats',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Search & Explore',
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

                // Search Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onChanged: search.onQueryChanged,
                    onSubmitted: (String v) {
                      search.submit(v);
                      library.addRecentSearch(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Songs, artists, albums, genres…',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                      ),
                      suffixIcon: search.query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _controller.clear();
                                search.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Filter Chips
                if (search.status == SearchStatus.loaded && !search.result.isEmpty)
                  SizedBox(
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
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

                Expanded(
                  child: _buildBody(search, library),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SearchController search, LibraryController library) {
    switch (search.status) {
      case SearchStatus.idle:
        return _buildExploreAndRecent(library, search);
      case SearchStatus.loading:
        return const LoadingView(message: 'Searching music...');
      case SearchStatus.error:
        return MessageView(
          icon: Icons.search_off_rounded,
          title: 'Search failed',
          subtitle: search.errorMessage(),
          actionLabel: 'Retry',
          onAction: () => search.submit(search.query),
        );
      case SearchStatus.loaded:
        if (search.result.isEmpty) {
          return const MessageView(
            icon: Icons.music_off_rounded,
            title: 'No music found',
            subtitle: 'Try searching with a different song or artist name.',
          );
        }
        return _buildResults(search);
    }
  }

  Widget _buildExploreAndRecent(LibraryController library, SearchController search) {
    final recent = library.recentSearches;

    return ListView(
      controller: _exploreScroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        // Recent searches section
        if (recent.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'RECENT SEARCHES',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.secondary,
                  ),
                ),
                TextButton(
                  onPressed: library.clearRecentSearches,
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recent.map((String q) {
                return ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16, color: AppColors.secondary),
                  label: Text(q),
                  onPressed: () {
                    _controller.text = q;
                    search.submit(q);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Browse Genres & Moods Bento Grid
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Text(
            'BROWSE ALL GENRES',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.secondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _genres.length,
            itemBuilder: (BuildContext ctx, int i) {
              final g = _genres[i];
              return InkWell(
                onTap: () {
                  _controller.text = g.title;
                  search.submit(g.title);
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[g.color1, g.color2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: g.color1.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          g.title,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(g.icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(SearchController search) {
    final r = search.result;
    final showAll = _selectedFilter == 'All';

    return ListView(
      controller: _resultsScroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        // Artists Section
        if ((showAll || _selectedFilter == 'Artists') && r.artists.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Artists'),
          SizedBox(
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
        ],

        // Albums Section
        if ((showAll || _selectedFilter == 'Albums') && r.albums.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Albums'),
          SizedBox(
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
        ],

        // Songs Section
        if ((showAll || _selectedFilter == 'Songs') && r.tracks.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Tracks & Songs'),
          for (int i = 0; i < r.tracks.length; i++)
            TrackTile(
              track: r.tracks[i],
              onTap: () => TrackActions.play(context, r.tracks[i], queue: r.tracks),
              onMenu: () => showTrackActionsSheet(context, r.tracks[i]),
            ),
        ],

        // Playlists Section
        if ((showAll || _selectedFilter == 'Playlists') && r.playlists.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Playlists'),
          SizedBox(
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
        ],

        if (search.loadingMore)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _GenreCardData {
  final String title;
  final Color color1;
  final Color color2;
  final IconData icon;

  const _GenreCardData(this.title, this.color1, this.color2, this.icon);
}
