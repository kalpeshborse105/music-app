import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/music_repository.dart';
import '../../data/services/supabase_service.dart';
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
import '../widgets/inline_ad_slot.dart';
import '../widgets/admob_banner_card.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';
import '../../domain/models/advertisement.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import 'album_screen.dart';
import 'app_shell.dart';
import 'artist_screen.dart';
import 'list_screen.dart';

/// Home: greeting, trending, and admin-managed catalogue shelves (no mood/language filters).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static _HomeScreenState? _activeState;

  static void scrollToTopAndRefresh() {
    _activeState?._onScrollToTop();
  }

  static void resetToDefaultAndRefresh() {
    _activeState?._resetToDefault();
  }

  /// Silent background refresh (no pull UI) — used after warm-up / login.
  static void silentRefreshLatest() {
    _activeState?._silentBackgroundRefresh();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Home tab re-tap: scroll to top (no mood/language filters).
  void _resetToDefault() {
    _onScrollToTop();
  }

  late Future<List<CatalogSection>> _catalogSectionsFuture;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  final List<Track> _infiniteTracks = <Track>[];
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

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
    setState(() {
      _catalogSectionsFuture = repo.getCatalogSections(forceRefresh: true);
    });
    await Future.wait(<Future<dynamic>>[
      _loadInitialTracks(),
      library.syncWithSupabase(),
    ]);
  }

  /// Fetch latest catalogue without blocking or flashing the UI.
  Future<void> _silentBackgroundRefresh() async {
    if (!mounted) return;
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final LibraryController library = context.read<LibraryController>();
      final List<Object> results = await Future.wait(<Future<Object>>[
        repo.getCatalogSections(forceRefresh: true),
        library.syncWithSupabase().then((_) => true),
      ]);
      if (!mounted) return;
      setState(() {
        _catalogSectionsFuture = Future<List<CatalogSection>>.value(
          results[0] as List<CatalogSection>,
        );
      });
      await _loadInitialTracks();
    } catch (e) {
      debugPrint('[HomeScreen] silent refresh skipped: $e');
    }
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
      _currentOffset = 0;
      _hasMore = true;
    });
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final PagedResult<Track> paged = await repo.trendingPaged(
        limit: 20,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _currentOffset = paged.items.length;
          _infiniteTracks.clear();
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
      final PagedResult<Track> paged = await repo.trendingPaged(
        limit: 20,
        offset: _currentOffset,
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
      // Always fetch network catalogue first so admin edits show without a long stale flash.
      _catalogSectionsFuture = repo.getCatalogSections(forceRefresh: true);
      _loadInitialTracks();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _silentBackgroundRefresh();
      });
    }
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

                  // Admin ad: after header, before radio (only if active)
                  const SliverToBoxAdapter(
                    child: InlineAdSlot(
                      placement: Advertisement.placementHomePreRadio,
                    ),
                  ),

                  // Beats Radio Live Banner
                  SliverToBoxAdapter(child: _buildLiveRadioBanner(context)),

                  // Top Festival / Special Hero Banner (if active)
                  SliverToBoxAdapter(
                    child: _buildTopFestivalPosterHero(context),
                  ),

                  // Greeting (no mood / language chips — admin shelves drive Home)
                  SliverToBoxAdapter(
                    child: _buildGreeting(context),
                  ),

                  const SliverToBoxAdapter(
                    child: InlineAdSlot(
                      placement: Advertisement.placementHomePostRecent,
                    ),
                  ),

                  // Admin catalogue shelves
                  SliverToBoxAdapter(
                    child: _buildAdminCatalogSections(context, repo),
                  ),

                  // Followed Artists Quick Shelf
                  if (library.followedArtists.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildFollowedArtistsBar(context, library, repo),
                    ),

                  const SliverToBoxAdapter(
                    child: AdMobBannerCard(),
                  ),

                  // Infinite scroll songs after catalogue (auto-loads on scroll)
                  SliverToBoxAdapter(
                    child: _buildBottomTrendingBlast(context, playback),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
                  Text(
                    'Kalpkrut Beats',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.4,
                      color: context.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.secondary
                            : AppColors.lightSecondaryAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MUSIC | MOOD | ENJOY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
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
      notes = await repo.fetchNotifications(
        limit: 40,
        userId: SupabaseService().currentUserId,
      );
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
                        final String when = ts > 0 ? _formatNotifTime(ts) : '';
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
                            imageUrl: '${n['image_url'] ?? ''}',
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
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      unix * 1000,
    ).toLocal();
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openNotificationTarget(BuildContext context, Map<String, dynamic> n) {
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
    String imageUrl = '',
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
          if (imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl.trim(),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ),
            )
          else
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

  Widget _buildGreeting(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
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
                          child: Icon(
                            Icons.celebration_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimaryAccent,
                            size: 36,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.celebration_rounded,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.lightPrimaryAccent,
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary
                                    : AppColors.lightPrimaryAccent,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.lightPrimaryAccent,
                              ),
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

        // Regular non-banner sections — sort by admin position first
        final List<CatalogSection> regularSections = sections
            .where(
              (CatalogSection s) =>
                  (!s.isBanner || !s.isCampaignActive) && s.isEnabled,
            )
            .toList()
          ..sort(
            (CatalogSection a, CatalogSection b) =>
                a.position.compareTo(b.position),
          );

        // Group by displayGroup; Home order = admin ↑↓ via min(position) per group
        final Map<String, List<CatalogSection>> grouped =
            <String, List<CatalogSection>>{};
        for (final CatalogSection sec in regularSections) {
          final String g = sec.displayGroup.trim().isEmpty
              ? 'More'
              : sec.displayGroup.trim();
          grouped.putIfAbsent(g, () => <CatalogSection>[]).add(sec);
        }
        int minPos(List<CatalogSection> list) {
          var m = 1 << 30;
          for (final CatalogSection s in list) {
            if (s.position < m) m = s.position;
          }
          return m;
        }

        void openSection(CatalogSection section) {
          final int count = section.itemCount > 0
              ? section.itemCount
              : section.items.length;
          final bool isSingleTrack = section.sourceType == 'song' ||
              section.sourceType == 'track' ||
              (count == 1 &&
                  section.sourceType != 'album' &&
                  section.sourceType != 'artist');
          if (isSingleTrack && section.items.isNotEmpty) {
            TrackActions.play(context, section.items.first, queue: section.items);
            return;
          }
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

        // Sort groups by lowest shelf position (admin group ↑↓ writes these ranks).
        final List<MapEntry<String, List<CatalogSection>>> groupEntries =
            grouped.entries.toList()
              ..sort(
                (MapEntry<String, List<CatalogSection>> a,
                        MapEntry<String, List<CatalogSection>> b) =>
                    minPos(a.value).compareTo(minPos(b.value)),
              );
        final int midGroup = groupEntries.isEmpty
            ? 0
            : (groupEntries.length / 2).floor().clamp(0, groupEntries.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Dynamic Sections grouped by category (Phase 4)
            for (int gi = 0; gi < groupEntries.length; gi++) ...<Widget>[
              if (gi == midGroup && groupEntries.length > 1)
                const InlineAdSlot(
                  placement: Advertisement.placementCatalogMid,
                ),
              Builder(
                builder: (BuildContext ctx) {
                  final MapEntry<String, List<CatalogSection>> entry =
                      groupEntries[gi];
                  final String groupTitle = entry.key;
                  final List<CatalogSection> groupSections = entry.value;

                  // Split TRACK shelves from entity cards inside the same group.
                  // Before: track shelf only if group had exactly 1 section — so
                  // "New Releases (Hindi)" TRACK sat as one card next to playlists.
                  final List<CatalogSection> shelfSections = groupSections;
                  if (shelfSections.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  bool wantsTrackShelf(CatalogSection s) {
                    final String mode = s.displayMode.toLowerCase();
                    return mode == 'tracks' ||
                        mode == 'songs' ||
                        mode == 'song' ||
                        s.sourceType == 'song' ||
                        s.sourceType == 'track';
                  }

                  bool hasPlayableTracks(CatalogSection s) {
                    final int n =
                        s.items.length > s.itemCount ? s.items.length : s.itemCount;
                    return s.items.length > 1 || n > 1;
                  }

                  final List<CatalogSection> trackShelves = shelfSections
                      .where(
                        (CatalogSection s) =>
                            wantsTrackShelf(s) && hasPlayableTracks(s),
                      )
                      .toList();
                  final List<CatalogSection> entitySections = shelfSections
                      .where(
                        (CatalogSection s) =>
                            !(wantsTrackShelf(s) && hasPlayableTracks(s)),
                      )
                      .toList();

                  final bool isArtistGroup = entitySections.isNotEmpty &&
                      entitySections.every(
                        (CatalogSection s) => s.sourceType == 'artist',
                      );
                  final double shelfHeight = isArtistGroup ? 185 : 215;
                  final double cardWidth = isArtistGroup ? 130 : 148;

                  Widget cardForTrack(Track track, List<Track> queue) {
                    return MediaCard(
                      title: track.title,
                      subtitle: track.artistNames,
                      imageUrl: track.artworkUrl,
                      fallbackIcon: Icons.music_note_rounded,
                      badgeText: 'TRACK',
                      badgeColor: AppColors.tertiary,
                      width: cardWidth,
                      onTap: () => TrackActions.play(context, track, queue: queue),
                      onPlay: () => TrackActions.play(context, track, queue: queue),
                    );
                  }

                  Widget cardFor(CatalogSection sec) {
                    final int count = sec.itemCount > 0
                        ? sec.itemCount
                        : sec.items.length;
                    // Skip empty featured albums/playlists (0 songs looks broken).
                    if (sec.sourceType != 'artist' &&
                        count <= 0 &&
                        sec.items.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    // Never badge a multi-song TRACK shelf as a single TRACK card —
                    // those render above via cardForTrack. Lone 1-song shelves only.
                    final bool isSingleTrack = (sec.sourceType == 'song' ||
                            sec.sourceType == 'track') &&
                        count <= 1;
                    final bool shelfDark = context.isDarkMode;
                    String badge;
                    if (sec.isBanner) {
                      badge = 'SPECIAL';
                    } else if (isSingleTrack) {
                      badge = 'TRACK';
                    } else if (sec.sourceType == 'artist') {
                      badge = 'ARTIST';
                    } else if (sec.sourceType == 'album') {
                      badge = 'ALBUM';
                    } else if (sec.sourceType == 'new_releases') {
                      badge = 'NEW';
                    } else {
                      badge = 'PLAYLIST';
                    }
                    return MediaCard(
                      title: sec.displayTitle,
                      subtitle: sec.subtitle ??
                          (isSingleTrack
                              ? (sec.items.isNotEmpty
                                  ? sec.items.first.artistNames
                                  : 'Single Track')
                              : (sec.sourceType == 'artist'
                                  ? 'Artist'
                                  : '$count songs')),
                      imageUrl: sec.effectiveArtworkUrl ??
                          (sec.items.isNotEmpty
                              ? sec.items.first.artworkUrl
                              : null),
                      fallbackIcon: isSingleTrack
                          ? Icons.music_note_rounded
                          : (sec.sourceType == 'artist'
                              ? Icons.person_rounded
                              : (sec.sourceType == 'album'
                                  ? Icons.album_rounded
                                  : Icons.queue_music_rounded)),
                      circle: sec.sourceType == 'artist',
                      badgeText: badge,
                      badgeColor: sec.isBanner
                          ? (shelfDark
                              ? AppColors.primaryLight
                              : AppColors.lightPrimaryAccent)
                          : (isSingleTrack ? AppColors.tertiary : AppColors.secondary),
                      width: cardWidth,
                      onTap: () {
                        if (isSingleTrack && sec.items.isNotEmpty) {
                          TrackActions.play(
                            context,
                            sec.items.first,
                            queue: sec.items,
                          );
                        } else {
                          openSection(sec);
                        }
                      },
                      onPlay: sec.items.isNotEmpty
                          ? () => TrackActions.play(
                              context,
                              sec.items.first,
                              queue: sec.items,
                            )
                          : null,
                    );
                  }

                  Widget buildTrackShelf(CatalogSection trackSection) {
                    final List<Track> tracks = trackSection.items;
                    final String title = trackSection.displayTitle.isNotEmpty
                        ? trackSection.displayTitle
                        : groupTitle;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeader(
                          title: title,
                          topPadding: AppSpacing.sm,
                          actionLabel: tracks.length > 1 ? 'See all' : null,
                          onAction: tracks.isNotEmpty
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => TrackListScreen(
                                        title: title,
                                        tracks: tracks,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                        _buildDoubleRowShelf(
                          context: context,
                          itemCount: tracks.length,
                          rowHeight: shelfHeight,
                          itemWidth: cardWidth,
                          itemBuilder: (BuildContext cardCtx, int i) =>
                              cardForTrack(tracks[i], tracks),
                        ),
                      ],
                    );
                  }

                  Widget buildEntityShelf(List<CatalogSection> sections) {
                    if (sections.isEmpty) return const SizedBox.shrink();
                    final bool artistsOnly = sections.every(
                      (CatalogSection s) => s.sourceType == 'artist',
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeader(
                          title: groupTitle,
                          topPadding: AppSpacing.sm,
                          actionLabel: sections.length > 1 ? 'See all' : null,
                        ),
                        if (artistsOnly)
                          SizedBox(
                            height: shelfHeight,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              itemCount: sections.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (BuildContext cardCtx, int i) =>
                                  cardFor(sections[i]),
                            ),
                          )
                        else
                          _buildDoubleRowShelf(
                            context: context,
                            itemCount: sections.length,
                            rowHeight: shelfHeight,
                            itemWidth: cardWidth,
                            itemBuilder: (BuildContext cardCtx, int i) =>
                                cardFor(sections[i]),
                          ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final CatalogSection ts in trackShelves)
                        buildTrackShelf(ts),
                      if (entitySections.isNotEmpty)
                        buildEntityShelf(entitySections),
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

  /// Infinite song list after admin catalogue — loads more on scroll.
  Widget _buildBottomTrendingBlast(
    BuildContext context,
    PlaybackController playback,
  ) {
    final List<Track> tracks = _infiniteTracks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
            title: 'Trending & Fresh Releases',
            subtitle:
                'Auto-suggested mixture of viral hits, top charts & fresh drops',
            topPadding: AppSpacing.sm,
            actionLabel: tracks.isNotEmpty
                ? 'Play All (${tracks.length})'
                : null,
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
                    isPlaying: playback.currentTrack?.id == tracks[i].id &&
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
                child: Transform.scale(scale: 0.94 + t * 0.06, child: child),
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
