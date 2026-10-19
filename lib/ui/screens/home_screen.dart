import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/music_repository.dart';
import '../../domain/models/catalog_section.dart';
import '../../domain/models/paged_result.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import 'album_screen.dart';
import 'app_shell.dart';
import 'artist_screen.dart';
import 'list_screen.dart';

/// Stitch Nocturnal Home Screen combining ambient glowing background, mood filters,
/// 6-card bento grid, Jump Back In carousel, Featured Spotlight, Made For You mixes,
/// ranked trending tracks with live soundbars, and featured curator avatars.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static _HomeScreenState? _activeState;

  static void scrollToTopAndRefresh() {
    _activeState?._onScrollToTop();
  }

  static void resetToDefaultAndRefresh() {
    _activeState?._resetToDefault();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMood = 'All';

  void _resetToDefault() {
    if (_selectedMood != 'All') {
      setState(() {
        _selectedMood = 'All';
      });
      _refreshData();
    }
    _onScrollToTop();
  }

  /// Mood chips only — language browsing lives in Library + catalog
  /// "Browse Languages" shelves (seeded from new-releases/{lang}).
  static const List<String> _moods = <String>[
    'All',
    'Devotional',
    'Romantic',
    'Chill',
  ];

  late Future<List<Track>> _trendingFuture;
  late Future<List<CatalogSection>> _catalogSectionsFuture;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  final List<Track> _infiniteTracks = <Track>[];
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  /// Mood chips map to `lang=` (backend MOOD_QUERIES). `All` → no filter.
  String? get _activeLang {
    if (_selectedMood == 'All') return null;
    return _selectedMood.toLowerCase();
  }

  static const Set<String> _moodOnlyChips = <String>{
    'Devotional',
    'Romantic',
    'Chill',
  };

  @override
  void initState() {
    super.initState();
    HomeScreen._activeState = this;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _refreshData() async {
    final MusicRepository repo = context.read<MusicRepository>();
    final LibraryController library = context.read<LibraryController>();
    final String? lang = _activeLang;
    setState(() {
      _trendingFuture = repo.trending(limit: 20, language: lang);
      _catalogSectionsFuture = repo.getCatalogSections(
        lang: lang,
        forceRefresh: true,
      );
    });
    await Future.wait(<Future<dynamic>>[
      _loadInitialTracks(),
      library.syncWithSupabase(),
    ]);
  }

  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    _refreshData();
  }

  Future<void> _loadInitialTracks() async {
    if (_isLoadingInitial) return;
    setState(() {
      _isLoadingInitial = true;
      _infiniteTracks.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final String? lang = _activeLang;
      final PagedResult<Track> paged = await repo.trendingPaged(
        limit: 20,
        offset: _currentOffset,
        language: lang,
      );
      if (mounted) {
        setState(() {
          _currentOffset += paged.items.length;
          _infiniteTracks.addAll(paged.items);
          _hasMore = paged.hasMore || paged.items.isNotEmpty;
          if (paged.items.isEmpty) _hasMore = true;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadInitialTracks error: $e');
      if (mounted) setState(() => _hasMore = true);
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final String? lang = _activeLang;
      final PagedResult<Track> paged = await repo.trendingPaged(
        limit: 20,
        offset: _currentOffset,
        language: lang,
      );
      if (mounted) {
        setState(() {
          if (paged.items.isEmpty) {
            _hasMore = false;
          } else {
            _currentOffset += paged.items.length;
            final Set<String> existingIds = _infiniteTracks
                .map((Track t) => t.id)
                .toSet();
            for (final Track t in paged.items) {
              if (existingIds.add(t.id)) {
                _infiniteTracks.add(t);
              }
            }
            _hasMore = paged.hasMore;
          }
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadMore error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    if (HomeScreen._activeState == this) {
      HomeScreen._activeState = null;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final MusicRepository repo = context.read<MusicRepository>();
      // Ensure home screen always defaults to 'All'
      _selectedMood = 'All';
      final String? lang = _activeLang;
      _trendingFuture = repo.trending(limit: 20, language: lang);
      _catalogSectionsFuture = repo.getCatalogSections(lang: lang);
      _loadInitialTracks();
    }
  }

  void _onMoodSelected(String mood, MusicRepository repo) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
      final String? lang = _activeLang;
      _trendingFuture = repo.trending(limit: 20, language: lang);
      _catalogSectionsFuture = repo.getCatalogSections(lang: lang);
    });
    _loadInitialTracks();
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
            child: RefreshIndicator(
              color: isDark
                  ? AppColors.secondary
                  : AppColors.lightSecondaryAccent,
              backgroundColor: isDark
                  ? AppColors.surfaceContainerHigh
                  : Colors.white,
              onRefresh: _refreshData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: <Widget>[
                  // 1. Header with Brand Mark and Actions
                  SliverToBoxAdapter(child: _buildHeader(context)),

                  // Global Search Redirect Bar
                  SliverToBoxAdapter(child: _buildSearchBar(context)),

                  // Akashvani Live Radio Banner
                  SliverToBoxAdapter(child: _buildLiveRadioBanner(context)),

                  // Top Festival / Special Hero Banner (if active)
                  SliverToBoxAdapter(
                    child: _buildTopFestivalPosterHero(context),
                  ),

                  // 2. Greeting & Mood Filter Carousel
                  SliverToBoxAdapter(
                    child: _buildGreetingAndMoods(context, repo),
                  ),

                  // Dynamic Mood Category View or Standard Discovery Soundscape
                  if (_moodOnlyChips.contains(_selectedMood)) ...<Widget>[
                    SliverToBoxAdapter(
                      child: _buildCategoryView(context, repo, playback),
                    ),
                  ] else ...<Widget>[
                    // 3. Recently Played (if history exists) or Trending Right Now (no dead space!)
                    SliverToBoxAdapter(
                      child: _buildRecentlyPlayedOrTrending(
                        context,
                        library,
                        repo,
                      ),
                    ),

                    // Dynamic Admin-Managed Catalogue Sections (All from DB catalogue)
                    SliverToBoxAdapter(
                      child: _buildAdminCatalogSections(context, repo),
                    ),

                    // Followed Artists Quick Shelf (auto-suggestions from followed artists)
                    if (library.followedArtists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildFollowedArtistsBar(context, library, repo),
                      ),

                    // 4. Continuous Blast of Trending & Fresh Releases (Mixture Auto Suggestion)
                    SliverToBoxAdapter(
                      child: _buildBottomTrendingBlast(context, playback),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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
                onPressed: () => AppShell.selectTab(context, 1),
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

  Widget _buildSearchBar(BuildContext context) {
    final bool isDark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => AppShell.selectTab(context, 1),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceContainerHigh.withValues(alpha: 0.8)
                : AppColors.lightElevatedSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 10),
              Text(
                'Search songs, artists, albums...',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveRadioBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AppShell.selectTab(context, 2);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF2B1842), Color(0xFF132036)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.electricViolet.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFFF9933), Color(0xFF138808)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.radio_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'BEATS RADIO LIVE',
                          style: TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.fiber_manual_record_rounded,
                          color: Colors.redAccent,
                          size: 8,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mirchi, private FM & regional live stations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationCenter(BuildContext context) async {
    final bool isDark = context.isDarkMode;
    final MusicRepository repo = context.read<MusicRepository>();
    List<Map<String, dynamic>> notes = <Map<String, dynamic>>[];
    try {
      notes = await repo.fetchNotifications(limit: 40);
    } catch (_) {}

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? AppColors.surfaceContainerHigh
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
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
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: context.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No new notifications',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext _, int i) {
                        final Map<String, dynamic> n = notes[i];
                        final int ts = (n['created_at'] as num?)?.toInt() ?? 0;
                        final String when = ts > 0
                            ? _formatNotifTime(ts)
                            : '';
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openNotificationTarget(context, n);
                          },
                          child: _buildNotificationTile(
                            context,
                            title: '${n['title'] ?? 'Update'}',
                            message: '${n['body'] ?? ''}',
                            timestamp: when,
                            icon: Icons.campaign_rounded,
                            color: AppColors.secondary,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNotifTime(int unix) {
    final DateTime dt =
        DateTime.fromMillisecondsSinceEpoch(unix * 1000).toLocal();
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openNotificationTarget(
    BuildContext context,
    Map<String, dynamic> n,
  ) {
    final String type = '${n['target_type'] ?? 'none'}'.toLowerCase();
    final String id = '${n['target_id'] ?? ''}'.trim();
    if (id.isEmpty || type == 'none') return;
    if (type == 'url' && id.startsWith('http')) {
      // leave as no-op in-app; deep links can be wired later
      return;
    }
    if (type == 'artist') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArtistScreen(
            artist: Artist(
              id: 'custom_api:artist:$id',
              providerId: 'custom_api',
              providerArtistId: id,
              name: '${n['title'] ?? 'Artist'}',
            ),
          ),
        ),
      );
      return;
    }
    if (type == 'album') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumScreen(
            album: Album(
              id: 'custom_api:album:$id',
              providerId: 'custom_api',
              providerAlbumId: id,
              title: '${n['title'] ?? 'Album'}',
            ),
          ),
        ),
      );
      return;
    }
    if (type == 'playlist' || type == 'catalog' || type == 'song') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrackListScreen(
            title: '${n['title'] ?? 'Playlist'}',
            tracks: const <Track>[],
          ),
        ),
      );
    }
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
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
              color: isDark
                  ? AppColors.secondary
                  : AppColors.lightSecondaryAccent,
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
                final Color inactiveBorder = isDark
                    ? AppColors.borderSubtle
                    : AppColors.lightBorder;

                return InkWell(
                  onTap: () => _onMoodSelected(mood, repo),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
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
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.4,
                                ),
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
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
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
      final List<Track> historyTracks = library.history
          .map((h) => h.track)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Recently Played',
            subtitle: 'Continue your personal listening session',
            topPadding: AppSpacing.sm,
            actionLabel: 'See all',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrackListScreen(
                    title: 'Recently Played',
                    tracks: historyTracks,
                  ),
                ),
              );
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
                  onTap: () =>
                      TrackActions.play(context, track, queue: historyTracks),
                  onPlay: () =>
                      TrackActions.play(context, track, queue: historyTracks),
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
        if (tracks.isEmpty &&
            snapshot.connectionState != ConnectionState.waiting) {
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
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TrackListScreen(
                        title: 'Trending Charts',
                        tracks: all,
                      ),
                    ),
                  );
                }
              },
            ),
            SizedBox(
              height: 196,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: 4,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, __) => _buildTrackSkeletonCard(context),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (BuildContext ctx, int i) {
                        final Track track = tracks[i];
                        return MediaCard.forTrack(
                          track: track,
                          badgeText: '#${i + 1}',
                          badgeColor: i < 3 ? AppColors.secondary : null,
                          onTap: () =>
                              TrackActions.play(context, track, queue: tracks),
                          onPlay: () =>
                              TrackActions.play(context, track, queue: tracks),
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
    final bool isLoading = _isLoadingInitial && _infiniteTracks.isEmpty;
    final List<Track> tracks = _infiniteTracks;

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => TrackActions.play(
                          context,
                          tracks.first,
                          queue: tracks,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text(
                          'Play All',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                          ? AppColors.surfaceContainerHigh.withValues(
                              alpha: 0.5,
                            )
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
              child: Center(child: Text('No tracks found in this category')),
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < tracks.length; i++) ...<Widget>[
                  TrackTile(
                    index: i,
                    track: tracks[i],
                    dense: false,
                    isPlaying:
                        playback.currentTrack?.id == tracks[i].id &&
                        playback.isPlaying,
                    onTap: () =>
                        TrackActions.play(context, tracks[i], queue: tracks),
                    onMenu: () => showTrackActionsSheet(context, tracks[i]),
                  ),
                  if (i < tracks.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  )
                else if (!_hasMore && tracks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'You\'ve reached the end',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopFestivalPosterHero(BuildContext context) {
    return FutureBuilder<List<CatalogSection>>(
      future: _catalogSectionsFuture,
      builder:
          (BuildContext context, AsyncSnapshot<List<CatalogSection>> snapshot) {
            final List<CatalogSection> sections =
                snapshot.data ?? <CatalogSection>[];
            final CatalogSection? festival = sections
                .cast<CatalogSection?>()
                .firstWhere(
                  (CatalogSection? s) =>
                      s != null &&
                      s.isBanner &&
                      s.isCampaignActive &&
                      s.isEnabled,
                  orElse: () => null,
                );
            if (festival == null) return const SizedBox.shrink();

            return _buildFestivalHeroBanner(context, festival);
          },
    );
  }

  Widget _buildFestivalHeroBanner(BuildContext context, CatalogSection banner) {
    final bool isDark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackListScreen(
                title: banner.displayTitle,
                tracks: banner.items,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? <Color>[
                      AppColors.primary.withValues(alpha: 0.35),
                      const Color(0xFF1B1B26),
                    ]
                  : <Color>[
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.white,
                    ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child:
                    banner.effectiveArtworkUrl != null &&
                        banner.effectiveArtworkUrl!.isNotEmpty
                    ? Image.network(
                        banner.effectiveArtworkUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.primary.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.celebration_rounded,
                            color: AppColors.primaryLight,
                            size: 36,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.celebration_rounded,
                          color: AppColors.primaryLight,
                          size: 36,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            (banner.subtitle != null &&
                                    banner.subtitle!.isNotEmpty)
                                ? banner.subtitle!.toUpperCase()
                                : (banner.displayGroup.isNotEmpty
                                      ? banner.displayGroup.toUpperCase()
                                      : 'FEATURED SPOTLIGHT'),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${banner.items.length} songs • ${banner.language.toUpperCase()} • Curated for you',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (banner.items.isNotEmpty) {
                    TrackActions.play(
                      context,
                      banner.items.first,
                      queue: banner.items,
                    );
                  }
                },
                child: const Icon(Icons.play_arrow_rounded, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickedForYouLoading(BuildContext context) {
    return const _MadeForYouSkeleton();
  }

  Widget _buildAdminCatalogSections(
    BuildContext context,
    MusicRepository repo,
  ) {
    return FutureBuilder<List<CatalogSection>>(
      future: _catalogSectionsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<CatalogSection>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildPickedForYouLoading(context);
        }
        final List<CatalogSection> sections =
            snapshot.data ?? <CatalogSection>[];
        if (sections.isEmpty) {
          return const SizedBox.shrink();
        }

        // Regular non-banner sections (Phase 4)
        final List<CatalogSection> regularSections = sections
            .where(
              (CatalogSection s) =>
                  (!s.isBanner || !s.isCampaignActive) && s.isEnabled,
            )
            .toList();

        // Group regular sections by displayGroup
        final Map<String, List<CatalogSection>> grouped =
            <String, List<CatalogSection>>{};
        for (final CatalogSection sec in regularSections) {
          grouped
              .putIfAbsent(sec.displayGroup, () => <CatalogSection>[])
              .add(sec);
        }

        void openSection(CatalogSection section) {
          if (section.sourceType == 'artist') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArtistScreen(
                  artist: Artist(
                    id: 'custom_api:artist:${section.sourceId.isNotEmpty ? section.sourceId : section.key}',
                    providerId: 'custom_api',
                    providerArtistId: section.sourceId.isNotEmpty
                        ? section.sourceId
                        : section.key,
                    name: section.displayTitle,
                    imageUrl:
                        section.effectiveArtworkUrl ??
                        (section.items.isNotEmpty
                            ? section.items.first.artworkUrl
                            : null),
                  ),
                ),
              ),
            );
          } else if (section.sourceType == 'album') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlbumScreen(
                  album: Album(
                    id: 'custom_api:album:${section.sourceId.isNotEmpty ? section.sourceId : section.key}',
                    providerId: 'custom_api',
                    providerAlbumId: section.sourceId.isNotEmpty
                        ? section.sourceId
                        : section.key,
                    title: section.displayTitle,
                    artists: section.items.isNotEmpty
                        ? section.items.first.artists
                        : const <Artist>[],
                    artworkUrl:
                        section.effectiveArtworkUrl ??
                        (section.items.isNotEmpty
                            ? section.items.first.artworkUrl
                            : null),
                    year: section.items.isNotEmpty
                        ? int.tryParse(
                            section.items.first.extra['year']?.toString() ?? '',
                          )
                        : null,
                  ),
                  initialTracks: section.items,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrackListScreen(
                  title: section.displayTitle,
                  tracks: section.items,
                ),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Dynamic Sections grouped by category (Phase 4)
            for (final MapEntry<String, List<CatalogSection>> entry
                in grouped.entries) ...<Widget>[
              Builder(
                builder: (BuildContext ctx) {
                  final String groupTitle = entry.key;
                  final List<CatalogSection> groupSections = entry.value;

                  // Check if this is a genuine track-only shelf (e.g. New Releases)
                  final bool isTrackFeed =
                      groupSections.length == 1 &&
                      (groupSections.first.sourceType == 'new_releases' ||
                          groupSections.first.sourceType == 'tracks');

                  if (isTrackFeed) {
                    final CatalogSection sec = groupSections.first;
                    if (sec.items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeader(
                          title: sec.displayTitle,
                          topPadding: AppSpacing.sm,
                          actionLabel: 'See all',
                          onAction: () => openSection(sec),
                        ),
                        _buildDoubleRowShelf(
                          context: context,
                          itemCount: sec.items.length,
                          rowHeight: 200,
                          itemWidth: 136,
                          itemBuilder: (BuildContext cardCtx, int i) {
                            final Track track = sec.items[i];
                            return MediaCard.forTrack(
                              track: track,
                              onTap: () => TrackActions.play(
                                context,
                                track,
                                queue: sec.items,
                              ),
                              onPlay: () => TrackActions.play(
                                context,
                                track,
                                queue: sec.items,
                              ),
                              width: 136,
                            );
                          },
                        ),
                      ],
                    );
                  }

                  // Entity Shelves (Playlists, Albums, Artists, Charts):
                  // Renders genuine entity cards without appending tracks into the shelf.
                  final bool isArtistGroup = groupSections.every(
                    (CatalogSection s) => s.sourceType == 'artist',
                  );
                  final double shelfHeight = isArtistGroup ? 185 : 215;
                  final double cardWidth = isArtistGroup ? 130 : 148;

                  Widget cardFor(CatalogSection sec) {
                    final int count = sec.itemCount > 0
                        ? sec.itemCount
                        : sec.items.length;
                    return MediaCard(
                      title: sec.displayTitle,
                      subtitle: sec.subtitle ??
                          (sec.sourceType == 'artist'
                              ? 'Artist'
                              : '$count songs'),
                      imageUrl: sec.effectiveArtworkUrl ??
                          (sec.items.isNotEmpty
                              ? sec.items.first.artworkUrl
                              : null),
                      fallbackIcon: sec.sourceType == 'artist'
                          ? Icons.person_rounded
                          : (sec.sourceType == 'album'
                              ? Icons.album_rounded
                              : Icons.queue_music_rounded),
                      circle: sec.sourceType == 'artist',
                      badgeText: sec.isBanner
                          ? 'SPECIAL'
                          : (sec.sourceType == 'artist'
                              ? 'ARTIST'
                              : (sec.sourceType == 'album'
                                  ? 'ALBUM'
                                  : 'PLAYLIST')),
                      badgeColor: sec.isBanner
                          ? AppColors.primaryLight
                          : AppColors.secondary,
                      width: cardWidth,
                      onTap: () => openSection(sec),
                      onPlay: sec.items.isNotEmpty
                          ? () => TrackActions.play(
                              context,
                              sec.items.first,
                              queue: sec.items,
                            )
                          : null,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SectionHeader(
                        title: groupTitle,
                        topPadding: AppSpacing.sm,
                        actionLabel: groupSections.length > 1
                            ? 'See all'
                            : null,
                      ),
                      // Artists stay single-row horizontal; other shelves use 2 rows
                      if (isArtistGroup)
                        SizedBox(
                          height: shelfHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            itemCount: groupSections.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.md),
                            itemBuilder: (BuildContext cardCtx, int i) =>
                                cardFor(groupSections[i]),
                          ),
                        )
                      else
                        _buildDoubleRowShelf(
                          context: context,
                          itemCount: groupSections.length,
                          rowHeight: shelfHeight,
                          itemWidth: cardWidth,
                          itemBuilder: (BuildContext cardCtx, int i) =>
                              cardFor(groupSections[i]),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  /// Two-row horizontal shelf: short screens 5/row, large 10/row (max 2 rows).
  Widget _buildDoubleRowShelf({
    required BuildContext context,
    required int itemCount,
    required double rowHeight,
    required double itemWidth,
    required NullableIndexedWidgetBuilder itemBuilder,
  }) {
    final double width = MediaQuery.sizeOf(context).width;
    final int perRow = width >= 700 ? 10 : 5;
    final int visible = math.min(itemCount, perRow * 2);
    final int row1Count = math.min(perRow, visible);
    final int row2Count = math.max(0, visible - row1Count);

    Widget row(int start, int count) {
      return SizedBox(
        height: rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (BuildContext ctx, int i) =>
              itemBuilder(ctx, start + i) ?? const SizedBox.shrink(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        row(0, row1Count),
        if (row2Count > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          row(row1Count, row2Count),
        ],
      ],
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

  Widget _buildFollowedArtistsBar(
    BuildContext context,
    LibraryController library,
    MusicRepository repo,
  ) {
    final List<Artist> artists = library.followedArtists;
    if (artists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Artists You Follow',
          subtitle: 'Auto-suggestions and top picks from your favorites',
          trailing: TextButton(
            onPressed: () => AppShell.selectTab(context, 2),
            child: const Text(
              'View All',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) {
              final Artist artist = artists[index];
              return InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistScreen(artist: artist),
                    ),
                  );
                },
                child: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.heroGradient,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child:
                            artist.imageUrl != null &&
                                artist.imageUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  artist.imageUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      artist.name.isNotEmpty
                                          ? artist.name[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  artist.name.isNotEmpty
                                      ? artist.name[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildBottomTrendingBlast(BuildContext context, PlaybackController playback) {
    final bool isDark = context.isDarkMode;
    final List<Track> tracks = _infiniteTracks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
            title: 'Trending & Fresh Releases',
            subtitle: 'Auto-suggested mixture of viral hits, top charts & fresh drops',
            topPadding: AppSpacing.sm,
            actionLabel: tracks.isNotEmpty ? 'Play All (${tracks.length})' : null,
            onAction: tracks.isNotEmpty
                ? () => TrackActions.play(context, tracks.first, queue: tracks)
                : null,
          ),
          const SizedBox(height: 6),

          if (_isLoadingInitial && tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: TextButton.icon(
                  onPressed: _loadInitialTracks,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Load songs'),
                ),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < tracks.length; i++) ...<Widget>[
                  TrackTile(
                    index: i,
                    track: tracks[i],
                    dense: false,
                    isPlaying: playback.currentTrack?.id == tracks[i].id && playback.isPlaying,
                    onTap: () => TrackActions.play(context, tracks[i], queue: tracks),
                    onMenu: () => showTrackActionsSheet(context, tracks[i]),
                  ),
                  if (i < tracks.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  )
                else if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: const Text('Load more songs'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Simple Made for you logo pulse — no shelf skeletons.
class _MadeForYouSkeleton extends StatefulWidget {
  const _MadeForYouSkeleton();

  @override
  State<_MadeForYouSkeleton> createState() => _MadeForYouSkeletonState();
}

class _MadeForYouSkeletonState extends State<_MadeForYouSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          const SectionHeader(
            title: 'Made for you',
            subtitle: 'Loading your music…',
            topPadding: 0,
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulse,
            builder: (BuildContext context, Widget? child) {
              final double t = _pulse.value;
              return Opacity(
                opacity: 0.75 + t * 0.25,
                child: Transform.scale(
                  scale: 0.94 + t * 0.06,
                  child: child,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
