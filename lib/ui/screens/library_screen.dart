import 'package:flutter/material.dart' hide SearchController;
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
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
import 'category_detail_screen.dart';
import 'list_screen.dart';
import 'onboarding_auth_screen.dart';

/// Unified Library & Search Discovery Screen.
/// Combines live JioSaavn-style search, genre cards, filter tabs,
/// quick access cards (Liked Songs, Downloads, Device Audio), and user playlists.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  static _LibraryScreenState? _activeState;

  static void resetToDefault(BuildContext context) {
    _activeState?._resetToDefault();
    context.read<SearchController>().clear();
  }

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'All';
  String _currentSort = 'Recently Added';
  bool _isGridView = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _dynamicCategories = <Map<String, dynamic>>[];
  bool _loadingCategories = false;

  void _resetToDefault() {
    setState(() {
      _selectedFilter = 'All';
      _searchController.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

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

  static const List<Map<String, dynamic>> _defaultIndianCategories = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'cat_bollywood',
      'title': 'Bollywood Hits',
      'subtitle': 'Top Hindi Cinema Chartbusters',
      'query': 'Bollywood Hits',
      'gradient_start': '#E11D48',
      'gradient_end': '#B45309',
      'artwork_url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      'emoji': '🎬',
    },
    <String, dynamic>{
      'id': 'cat_bhakti',
      'title': 'Bhakti & Aarti',
      'subtitle': 'Devotional Bhajans & Aartis',
      'query': 'Bhakti Songs',
      'gradient_start': '#EA580C',
      'gradient_end': '#EAB308',
      'artwork_url': 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
      'emoji': '🕉️',
    },
    <String, dynamic>{
      'id': 'cat_punjabi',
      'title': 'Punjabi Beats',
      'subtitle': 'High Energy Bhangra & Punjabi Pop',
      'query': 'Punjabi Party Songs',
      'gradient_start': '#D97706',
      'gradient_end': '#F59E0B',
      'artwork_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      'emoji': '🥁',
    },
    <String, dynamic>{
      'id': 'cat_romantic',
      'title': 'Romantic & Love',
      'subtitle': 'Heartfelt Hindi Melodies',
      'query': 'Romantic Hindi Hits',
      'gradient_start': '#BE185D',
      'gradient_end': '#F43F5E',
      'artwork_url': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      'emoji': '💖',
    },
    <String, dynamic>{
      'id': 'cat_retro',
      'title': 'Golden Retro 80s 90s',
      'subtitle': 'Kishore, Lata, Rafi Classics',
      'query': 'Lata Mangeshkar Hits',
      'gradient_start': '#7C2D12',
      'gradient_end': '#EA580C',
      'artwork_url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      'emoji': '📻',
    },
    <String, dynamic>{
      'id': 'cat_marathi',
      'title': 'Marathi Sangeet',
      'subtitle': 'Natya Sangeet, Bhavgeet & Lavani',
      'query': 'Marathi Hits',
      'gradient_start': '#059669',
      'gradient_end': '#10B981',
      'artwork_url': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
      'emoji': '🪕',
    },
    <String, dynamic>{
      'id': 'cat_garba',
      'title': 'Gujarati & Garba',
      'subtitle': 'Dandiya Beats & Gujarati Folk',
      'query': 'Garba Hits',
      'gradient_start': '#DC2626',
      'gradient_end': '#F97316',
      'artwork_url': 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=500&q=80',
      'emoji': '💃',
    },
    <String, dynamic>{
      'id': 'cat_south',
      'title': 'South Cinema',
      'subtitle': 'Tamil, Telugu, Malayalam Chartbusters',
      'query': 'South Indian Hits',
      'gradient_start': '#4338CA',
      'gradient_end': '#6366F1',
      'artwork_url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
      'emoji': '🌟',
    },
    <String, dynamic>{
      'id': 'cat_lofi',
      'title': 'Lo-Fi & Chill',
      'subtitle': 'Relaxing Indian Lo-Fi Beats',
      'query': 'Hindi Lo-Fi Hits',
      'gradient_start': '#0369A1',
      'gradient_end': '#0D9488',
      'artwork_url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      'emoji': '☕',
    },
    <String, dynamic>{
      'id': 'cat_sufi',
      'title': 'Sufi & Ghazals',
      'subtitle': 'Soulful Qawwalis & Poetry',
      'query': 'Sufi Hits',
      'gradient_start': '#312E81',
      'gradient_end': '#4C1D95',
      'artwork_url': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      'emoji': '🌙',
    },
    <String, dynamic>{
      'id': 'cat_workout',
      'title': 'Workout & Gym',
      'subtitle': 'High BPM Indian Workout Beats',
      'query': 'Workout Hindi Songs',
      'gradient_start': '#991B1B',
      'gradient_end': '#DC2626',
      'artwork_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&q=80',
      'emoji': '🔥',
    },
    <String, dynamic>{
      'id': 'cat_indie',
      'title': 'Indian Indie & Pop',
      'subtitle': 'Independent Artists & Modern Waves',
      'query': 'Indian Indie Songs',
      'gradient_start': '#0F766E',
      'gradient_end': '#14B8A6',
      'artwork_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      'emoji': '🎸',
    },
  ];

  static final List<Artist> _curatedIndianArtists = <Artist>[
    const Artist(
      id: 'artist:arijit_singh',
      providerId: 'custom_api',
      providerArtistId: 'arijit_singh',
      name: 'Arijit Singh',
      imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg',
      popularity: 98,
    ),
    const Artist(
      id: 'artist:shreya_ghoshal',
      providerId: 'custom_api',
      providerArtistId: 'shreya_ghoshal',
      name: 'Shreya Ghoshal',
      imageUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20230324072210_500x500.jpg',
      popularity: 95,
    ),
    const Artist(
      id: 'artist:ar_rahman',
      providerId: 'custom_api',
      providerArtistId: 'ar_rahman',
      name: 'A.R. Rahman',
      imageUrl: 'https://c.saavncdn.com/artists/A_R_Rahman_002_20210319080544_500x500.jpg',
      popularity: 97,
    ),
    const Artist(
      id: 'artist:sidhu_moose_wala',
      providerId: 'custom_api',
      providerArtistId: 'sidhu_moose_wala',
      name: 'Sidhu Moose Wala',
      imageUrl: 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_004_20230609101211_500x500.jpg',
      popularity: 94,
    ),
    const Artist(
      id: 'artist:neha_kakkar',
      providerId: 'custom_api',
      providerArtistId: 'neha_kakkar',
      name: 'Neha Kakkar',
      imageUrl: 'https://c.saavncdn.com/artists/Neha_Kakkar_006_20201111110751_500x500.jpg',
      popularity: 92,
    ),
    const Artist(
      id: 'artist:badshah',
      providerId: 'custom_api',
      providerArtistId: 'badshah',
      name: 'Badshah',
      imageUrl: 'https://c.saavncdn.com/artists/Badshah_005_20230614080352_500x500.jpg',
      popularity: 91,
    ),
    const Artist(
      id: 'artist:diljit_dosanjh',
      providerId: 'custom_api',
      providerArtistId: 'diljit_dosanjh',
      name: 'Diljit Dosanjh',
      imageUrl: 'https://c.saavncdn.com/artists/Diljit_Dosanjh_004_20221006184545_500x500.jpg',
      popularity: 93,
    ),
    const Artist(
      id: 'artist:lata_mangeshkar',
      providerId: 'custom_api',
      providerArtistId: 'lata_mangeshkar',
      name: 'Lata Mangeshkar',
      imageUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_500x500.jpg',
      popularity: 96,
    ),
    const Artist(
      id: 'artist:kishore_kumar',
      providerId: 'custom_api',
      providerArtistId: 'kishore_kumar',
      name: 'Kishore Kumar',
      imageUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
      popularity: 96,
    ),
  ];

  static final List<Album> _curatedIndianAlbums = <Album>[
    const Album(
      id: 'album:animal',
      providerId: 'custom_api',
      providerAlbumId: 'animal',
      title: 'Animal',
      artists: <Artist>[Artist(id: 'a1', providerId: 'custom_api', providerArtistId: 'a1', name: 'Manan Bhardwaj, Vishal Mishra')],
      artworkUrl: 'https://c.saavncdn.com/092/Animal-Hindi-2023-20231124191036-500x500.jpg',
      year: 2023,
      trackCount: 8,
    ),
    const Album(
      id: 'album:jawan',
      providerId: 'custom_api',
      providerAlbumId: 'jawan',
      title: 'Jawan',
      artists: <Artist>[Artist(id: 'a2', providerId: 'custom_api', providerArtistId: 'a2', name: 'Anirudh Ravichander')],
      artworkUrl: 'https://c.saavncdn.com/026/Jawan-Hindi-2023-20230905141019-500x500.jpg',
      year: 2023,
      trackCount: 7,
    ),
    const Album(
      id: 'album:kabir_singh',
      providerId: 'custom_api',
      providerAlbumId: 'kabir_singh',
      title: 'Kabir Singh',
      artists: <Artist>[Artist(id: 'a3', providerId: 'custom_api', providerArtistId: 'a3', name: 'Sachet-Parampara, Mithoon')],
      artworkUrl: 'https://c.saavncdn.com/408/Kabir-Singh-Hindi-2019-20240409140417-500x500.jpg',
      year: 2019,
      trackCount: 9,
    ),
    const Album(
      id: 'album:aashiqui2',
      providerId: 'custom_api',
      providerAlbumId: 'aashiqui2',
      title: 'Aashiqui 2',
      artists: <Artist>[Artist(id: 'a4', providerId: 'custom_api', providerArtistId: 'a4', name: 'Mithoon, Ankit Tiwari')],
      artworkUrl: 'https://c.saavncdn.com/452/Aashiqui-2-Hindi-2013-500x500.jpg',
      year: 2013,
      trackCount: 11,
    ),
    const Album(
      id: 'album:brahmastra',
      providerId: 'custom_api',
      providerAlbumId: 'brahmastra',
      title: 'Brahmāstra',
      artists: <Artist>[Artist(id: 'a5', providerId: 'custom_api', providerArtistId: 'a5', name: 'Pritam')],
      artworkUrl: 'https://c.saavncdn.com/514/Brahmastra-Original-Motion-Picture-Soundtrack-Hindi-2022-20221006155913-500x500.jpg',
      year: 2022,
      trackCount: 10,
    ),
    const Album(
      id: 'album:rockstar',
      providerId: 'custom_api',
      providerAlbumId: 'rockstar',
      title: 'Rockstar',
      artists: <Artist>[Artist(id: 'a6', providerId: 'custom_api', providerArtistId: 'a6', name: 'A.R. Rahman')],
      artworkUrl: 'https://c.saavncdn.com/391/Rockstar-Hindi-2011-20221212033008-500x500.jpg',
      year: 2011,
      trackCount: 14,
    ),
  ];

  static final List<Map<String, dynamic>> _curatedIndianPlaylists = <Map<String, dynamic>>[
    <String, dynamic>{
      'title': 'Bollywood Top 50',
      'query': 'Bollywood Top Hits',
      'subtitle': 'Most popular Hindi chartbusters',
      'artwork_url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      'track_count': '50',
    },
    <String, dynamic>{
      'title': 'Bhakti Sagar & Aarti',
      'query': 'Bhakti Songs',
      'subtitle': 'Divine bhajans, morning aartis & chants',
      'artwork_url': 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
      'track_count': '40',
    },
    <String, dynamic>{
      'title': 'Punjabi Party Hits',
      'query': 'Punjabi Party Songs',
      'subtitle': 'High voltage Bhangra & Punjabi pop',
      'artwork_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      'track_count': '35',
    },
    <String, dynamic>{
      'title': 'Golden 90s Classics',
      'query': 'Lata Mangeshkar Hits',
      'subtitle': 'Timeless nostalgic melodies',
      'artwork_url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      'track_count': '45',
    },
    <String, dynamic>{
      'title': 'Late Night Lo-Fi',
      'query': 'Hindi Lo-Fi Hits',
      'subtitle': 'Chill relaxing Hindi lo-fi beats',
      'artwork_url': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      'track_count': '30',
    },
    <String, dynamic>{
      'title': 'Marathi Gaani & Lavani',
      'query': 'Marathi Hits',
      'subtitle': 'Top Marathi songs and folk melodies',
      'artwork_url': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
      'track_count': '32',
    },
  ];

  static Color _parseHexColor(dynamic hex, Color fallback) {
    if (hex == null || hex is! String || hex.isEmpty) return fallback;
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  void initState() {
    super.initState();
    LibraryScreen._activeState = this;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDynamicCategories());
  }

  Future<void> _loadDynamicCategories() async {
    if (_loadingCategories) return;
    _loadingCategories = true;
    try {
      final List<Map<String, dynamic>> cats =
          await context.read<MusicRepository>().fetchLibraryCategories();
      if (mounted && cats.isNotEmpty) {
        setState(() {
          _dynamicCategories = cats.where((c) => c['is_active'] != false).toList();
        });
      }
    } catch (_) {
      // Fallback is handled automatically
    } finally {
      _loadingCategories = false;
    }
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
      final List<Map<String, dynamic>> categoriesToDisplay =
          _dynamicCategories.isNotEmpty ? _dynamicCategories : _defaultIndianCategories;

      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                SizedBox(width: 6),
                Text(
                  'Explore Indian Genres & Moods',
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
                childAspectRatio: 1.7,
              ),
              itemCount: categoriesToDisplay.length,
              itemBuilder: (BuildContext ctx, int i) {
                final Map<String, dynamic> cat = categoriesToDisplay[i];
                final String title = (cat['title'] as String?) ?? (cat['name'] as String?) ?? 'Music';
                final String subtitle = (cat['subtitle'] as String?) ?? '';
                final String query = (cat['query'] as String?) ?? title;
                final String artworkUrl = (cat['artwork_url'] as String?) ?? '';
                final String emoji = (cat['emoji'] as String?) ?? '🎵';
                final Color color1 = _parseHexColor(cat['gradient_start'], const Color(0xFF6366F1));
                final Color color2 = _parseHexColor(cat['gradient_end'], const Color(0xFF8B5CF6));

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => CategoryDetailScreen(
                        title: title,
                        query: query,
                        subtitle: subtitle,
                        artworkUrl: artworkUrl,
                        gradientColors: <Color>[color1, color2],
                        emoji: emoji,
                      ),
                    ));
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (artworkUrl.isNotEmpty)
                          Artwork(
                            url: artworkUrl,
                            size: 200,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.music_note_rounded,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[color1, color2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                color1.withValues(alpha: 0.75),
                                color2.withValues(alpha: 0.90),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Play →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
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
      if (library.localTracks.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 32),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android_rounded, size: 30, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Device Music Storage',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Play MP3, AAC, FLAC files directly from your phone storage. 100% private, files stay on your device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        final provider = context.read<LocalMusicProvider>();
                        library.scanLocal(provider, force: true);
                      },
                      icon: Icon(library.localScanning ? Icons.sync_rounded : Icons.refresh_rounded),
                      label: Text(library.localScanning ? 'Scanning Device...' : 'Scan Device Audio'),
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
      }
      return slivers;
    }

    // Specific filter handling: Artists
    if (_selectedFilter == 'Artists') {
      final List<Artist> artists = library.followedArtists;
      if (artists.isNotEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Followed Artists'),
          ),
        );
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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

      // Always show Top Indian Artists
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Top Indian Artists'),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final Artist a = _curatedIndianArtists[i];
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
                    'Popular Indian Artist',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  ),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => TrackActions.openArtist(context, a),
                    child: const Text('Explore'),
                  ),
                  onTap: () => TrackActions.openArtist(context, a),
                );
              },
              childCount: _curatedIndianArtists.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Specific filter handling: Albums
    if (_selectedFilter == 'Albums') {
      final List<Album> savedAlbums = library.savedAlbums;
      if (savedAlbums.isNotEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Saved Albums'),
          ),
        );
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
                  album: savedAlbums[i],
                  onTap: () => TrackActions.openAlbum(context, savedAlbums[i]),
                ),
                childCount: savedAlbums.length,
              ),
            ),
          ),
        );
      }

      // Always show Trending Indian Albums
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Trending Indian Albums'),
        ),
      );
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
                album: _curatedIndianAlbums[i],
                onTap: () => TrackActions.openAlbum(context, _curatedIndianAlbums[i]),
              ),
              childCount: _curatedIndianAlbums.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Specific filter handling: Playlists
    if (_selectedFilter == 'Playlists') {
      final List<Playlist> userPlaylists = library.playlists;
      if (userPlaylists.isNotEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Your Playlists'),
          ),
        );
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: _buildCollectionsList(library),
          ),
        );
      }

      // Always show Curated Indian Playlists
      slivers.add(
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Curated Indian Playlists'),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext c, int i) {
                final Map<String, dynamic> p = _curatedIndianPlaylists[i];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => CategoryDetailScreen(
                        title: p['title'] as String,
                        query: p['query'] as String,
                        subtitle: p['subtitle'] as String?,
                        artworkUrl: p['artwork_url'] as String?,
                      ),
                    ));
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Artwork(
                              url: p['artwork_url'] as String?,
                              size: 160,
                              fit: BoxFit.cover,
                              fallbackIcon: Icons.queue_music_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p['subtitle'] as String? ?? 'Playlist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _curatedIndianPlaylists.length,
            ),
          ),
        ),
      );

      // Add New Playlist Button
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 16),
            child: OutlinedButton.icon(
              onPressed: () => _promptCreatePlaylist(context, library),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Playlist'),
            ),
          ),
        ),
      );
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
