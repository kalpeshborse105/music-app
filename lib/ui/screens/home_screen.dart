import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/music_repository.dart';
import '../../domain/models/catalog_section.dart';
import '../../domain/models/track.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';
import '../widgets/cards.dart';
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
  String _selectedMood = 'Hindi';

  void _resetToDefault() {
    if (_selectedMood != 'Hindi') {
      setState(() {
        _selectedMood = 'Hindi';
      });
      _refreshData();
    }
    _onScrollToTop();
  }

  /// Language preference chips — these map to the `lang=` backend parameter.
  /// Hindi is the primary default, followed by All and regional languages.
  static const List<String> _languages = <String>[
    'Hindi',
    'All',
    'Marathi',
    'Punjabi',
    'Bhojpuri',
    'Haryanvi',
    'Gujarati',
    'Tamil',
    'Telugu',
    'Bengali',
  ];

  /// These chips change the catalogue language filter, not a mood search query.
  static List<String> get _moods => _languages;

  late Future<List<CatalogSection>> _catalogSectionsFuture;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  /// Returns the lang= parameter value for the currently selected chip.
  /// Language chips (Hindi, Telugu, etc.) map to their lowercase name.
  String? get _activeLang {
    if (_selectedMood == 'All') return 'all';
    return _selectedMood.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    HomeScreen._activeState = this;
    final String? userLang = context.read<LibraryController>().preferredLanguage;
    if (userLang != null && userLang.trim().isNotEmpty) {
      final String trimmed = userLang.trim();
      final String formatted = trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
      if (_moods.contains(formatted)) {
        _selectedMood = formatted;
      }
    }
  }

  Future<void> _refreshData() async {
    final MusicRepository repo = context.read<MusicRepository>();
    final LibraryController library = context.read<LibraryController>();
    setState(() {
      _catalogSectionsFuture = repo.getCatalogSections(lang: _activeLang);
    });
    await library.syncWithSupabase();
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

  @override
  void dispose() {
    if (HomeScreen._activeState == this) {
      HomeScreen._activeState = null;
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final MusicRepository repo = context.read<MusicRepository>();
      // Preserve the explicit profile preference; the first-run default is Hindi.
      _catalogSectionsFuture = repo.getCatalogSections(lang: _activeLang);
    }
  }

  void _onMoodSelected(String mood, MusicRepository repo) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
      _catalogSectionsFuture = repo.getCatalogSections(lang: _activeLang);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MusicRepository repo = context.read<MusicRepository>();
    final LibraryController library = context.watch<LibraryController>();
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
              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
              backgroundColor: isDark ? AppColors.surfaceContainerHigh : Colors.white,
              onRefresh: _refreshData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: <Widget>[
                // 1. Header with Brand Mark and Actions
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // Global Search Redirect Bar
                SliverToBoxAdapter(
                  child: _buildSearchBar(context),
                ),

                // Language selection applies to the admin-published catalogue.
                SliverToBoxAdapter(
                  child: _buildGreetingAndMoods(context, repo),
                ),

                // User-specific history is separate from editorial catalogue content.
                SliverToBoxAdapter(
                  child: _buildRecentlyPlayed(context, library),
                ),

                // All public editorial sections are rendered from Supabase in admin order.
                SliverToBoxAdapter(
                  child: _buildAdminCatalogSections(context, repo),
                ),

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
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
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
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 10),
              Text(
                'Search songs, artists, albums...',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationCenter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.isDarkMode ? AppColors.surfaceContainerHigh : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.notifications_none_rounded, size: 32),
              const SizedBox(height: 12),
              Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: ctx.textPrimary)),
              const SizedBox(height: 8),
              Text('No new notifications. Real announcements will appear here when available.',
                  textAlign: TextAlign.center, style: TextStyle(color: ctx.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
          // Language filter pills
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

  Widget _buildRecentlyPlayed(BuildContext context, LibraryController library) {
    if (library.history.isEmpty) return const SizedBox.shrink();
    final List<Track> historyTracks = library.history.map((h) => h.track).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Recently Played',
          subtitle: 'Continue your listening',
          topPadding: AppSpacing.sm,
          actionLabel: 'See all',
          onAction: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TrackListScreen(title: 'Recently Played', tracks: historyTracks),
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

  Widget _buildAdminCatalogSections(BuildContext context, MusicRepository repo) {
    return FutureBuilder<List<CatalogSection>>(
      future: _catalogSectionsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<CatalogSection>> snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              children: <Widget>[
                const Icon(Icons.cloud_off_rounded, size: 30, color: AppColors.outline),
                const SizedBox(height: 8),
                Text('Catalogue could not be loaded', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Check your connection and try again. Demo music is not shown.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _refreshData, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final List<CatalogSection> sections = snapshot.data ?? <CatalogSection>[];
        if (sections.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              children: <Widget>[
                const Icon(Icons.library_music_outlined, size: 32, color: AppColors.outline),
                const SizedBox(height: 8),
                Text('No catalogue sections published', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Published music sections will appear here when configured by the administrator.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 12)),
              ],
            ),
          );
        }

        // Honour publication status, campaign windows and admin-saved order.
        final List<CatalogSection> regularSections = sections
            .where((CatalogSection s) => s.isEnabled && s.isCampaignActive)
            .toList()
          ..sort((CatalogSection a, CatalogSection b) => a.position.compareTo(b.position));

        // Group only adjacent rows with the same group; never reorder editorial items.
        final List<List<CatalogSection>> grouped = <List<CatalogSection>>[];
        for (final CatalogSection section in regularSections) {
          final bool isTrackFeed = section.sourceType == 'new_releases' || section.sourceType == 'tracks';
          final bool previousIsTrackFeed = grouped.isNotEmpty &&
              (grouped.last.first.sourceType == 'new_releases' || grouped.last.first.sourceType == 'tracks');
          if (section.isBanner || isTrackFeed || grouped.isEmpty ||
              grouped.last.first.isBanner || previousIsTrackFeed ||
              grouped.last.first.displayGroup != section.displayGroup) {
            grouped.add(<CatalogSection>[section]);
          } else {
            grouped.last.add(section);
          }
        }

        void openSection(CatalogSection section) {
          if (section.sourceType == 'artist') {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ArtistScreen(
                artist: Artist(
                  id: 'custom_api:artist:${section.sourceId.isNotEmpty ? section.sourceId : section.key}',
                  providerId: 'custom_api',
                  providerArtistId: section.sourceId.isNotEmpty ? section.sourceId : section.key,
                  name: section.displayTitle,
                  imageUrl: section.effectiveArtworkUrl ??
                      (section.items.isNotEmpty ? section.items.first.artworkUrl : null),
                ),
              ),
            ));
          } else if (section.sourceType == 'album') {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AlbumScreen(
                album: Album(
                  id: 'custom_api:album:${section.sourceId.isNotEmpty ? section.sourceId : section.key}',
                  providerId: 'custom_api',
                  providerAlbumId: section.sourceId.isNotEmpty ? section.sourceId : section.key,
                  title: section.displayTitle,
                  artists: section.items.isNotEmpty ? section.items.first.artists : const <Artist>[],
                  artworkUrl: section.effectiveArtworkUrl ??
                      (section.items.isNotEmpty ? section.items.first.artworkUrl : null),
                  year: section.items.isNotEmpty
                      ? int.tryParse(section.items.first.extra['year']?.toString() ?? '')
                      : null,
                ),
                initialTracks: section.items,
              ),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TrackListScreen(
                title: section.displayTitle,
                tracks: section.items,
              ),
            ));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Dynamic Sections grouped by category (Phase 4)
            for (final List<CatalogSection> groupSections in grouped) ...<Widget>[
              Builder(
                builder: (BuildContext ctx) {
                  final String groupTitle = groupSections.first.displayGroup;
                  if (groupSections.length == 1 && groupSections.first.isBanner) {
                    return _buildFestivalHeroBanner(ctx, groupSections.first);
                  }

                  // Check if this is a genuine track-only shelf (e.g. New Releases)
                  final bool isTrackFeed = groupSections.length == 1 &&
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
                          subtitle: sec.subtitle ?? '${sec.displayGroup} • ${sec.language.toUpperCase()}',
                          topPadding: AppSpacing.sm,
                          actionLabel: 'See all (${sec.items.length})',
                          onAction: () => openSection(sec),
                        ),
                        SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            itemCount: sec.items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                            itemBuilder: (BuildContext cardCtx, int i) {
                              final Track track = sec.items[i];
                              return MediaCard.forTrack(
                                track: track,
                                onTap: () => TrackActions.play(context, track, queue: sec.items),
                                onPlay: () => TrackActions.play(context, track, queue: sec.items),
                                width: 136,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  // Entity Shelves (Playlists, Albums, Artists, Charts):
                  // Renders genuine entity cards without appending tracks into the shelf.
                  final bool isArtistGroup =
                      groupSections.every((CatalogSection s) => s.sourceType == 'artist');
                  final double shelfHeight = isArtistGroup ? 185 : 215;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SectionHeader(
                        title: groupTitle,
                        subtitle: groupSections.first.subtitle ??
                            (groupSections.first.displayGroup.isNotEmpty
                                ? groupSections.first.displayGroup
                                : '${groupSections.first.sourceType.toUpperCase()} • ${groupSections.first.language.toUpperCase()}'),
                        topPadding: AppSpacing.sm,
                        actionLabel: groupSections.length > 2 ? 'See all' : null,
                      ),
                      SizedBox(
                        height: shelfHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: groupSections.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                          itemBuilder: (BuildContext cardCtx, int i) {
                            final CatalogSection sec = groupSections[i];
                            final int count = sec.itemCount > 0 ? sec.itemCount : sec.items.length;
                            return MediaCard(
                              title: sec.displayTitle,
                              subtitle: sec.subtitle ??
                                  (sec.sourceType == 'artist' ? 'Artist' : '$count songs'),
                              imageUrl: sec.effectiveArtworkUrl ??
                                  (sec.items.isNotEmpty ? sec.items.first.artworkUrl : null),
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
                                      : (sec.sourceType == 'album' ? 'ALBUM' : 'PLAYLIST')),
                              badgeColor:
                                  sec.isBanner ? AppColors.primaryLight : AppColors.secondary,
                              width: sec.sourceType == 'artist' ? 130 : 148,
                              onTap: () => openSection(sec),
                              onPlay: sec.items.isNotEmpty
                                  ? () => TrackActions.play(context, sec.items.first,
                                      queue: sec.items)
                                  : null,
                            );
                          },
                        ),
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


}
