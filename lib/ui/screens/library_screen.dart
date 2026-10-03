import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/history_entry.dart';
import '../../domain/models/playlist.dart';
import '../../domain/providers/local_provider.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';
import 'list_screen.dart';

/// Stitch Library Screen with segmented filter chips, pinned bento cards
/// (Liked Songs, Downloads, Device Audio), and dynamic collections.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'All';
  String _currentSort = 'Recently Added';
  bool _isGridView = false;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filters = <String>[
    'All',
    'Playlists',
    'Liked Songs',
    'Albums',
    'Artists',
    'Downloaded',
    'Local Files',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryController library = context.watch<LibraryController>();
    final DownloadsController downloads = context.watch<DownloadsController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int totalCount = library.likedTracks.length +
        library.playlists.length +
        downloads.downloads.length +
        library.localTracks.length;

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
            child: CustomScrollView(
              slivers: <Widget>[
                // Header Bar with Total Items & Action Buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text(
                                  'Your Library',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 24,
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                IconButton(
                                  icon: Icon(
                                    _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchOpen = !_isSearchOpen;
                                      if (!_isSearchOpen) _searchController.clear();
                                    });
                                  },
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
                          ],
                        ),

                        // Togglable Inline Search Bar
                        if (_isSearchOpen) ...<Widget>[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Filter your library...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.secondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => setState(() => _searchController.clear()),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Horizontal Segmented Filter Chips
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
                          return InkWell(
                            onTap: () => setState(() => _selectedFilter = f),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: active ? AppColors.brandGradient : null,
                                color: active ? null : AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: active ? Colors.transparent : AppColors.borderSubtle,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  f,
                                  style: TextStyle(
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
                  ),
                ),

                // Sorting & View Mode Switcher
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        InkWell(
                          onTap: () => _pickSortOption(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  _currentSort,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondaryDark),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              icon: Icon(
                                Icons.format_list_bulleted_rounded,
                                color: !_isGridView ? AppColors.primaryLight : AppColors.outline,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isGridView = false),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.grid_view_rounded,
                                color: _isGridView ? AppColors.primaryLight : AppColors.outline,
                                size: 20,
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

                // Pinned Quick Access Bento Grid
                if (_selectedFilter == 'All')
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
                              // Downloads Card
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

                              // Local Device Audio Card
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

                // Collections Section Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                    child: Text(
                      'COLLECTIONS & PLAYLISTS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),

                // Playlists & Saved Collections List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  sliver: _buildCollectionsList(library),
                ),

                // Recently Played Tracks Section
                if (library.history.isNotEmpty && _selectedFilter == 'All') ...<Widget>[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Recently Played',
                      subtitle: 'Ordered by most recent playback',
                      actionLabel: 'Clear',
                      onAction: library.clearHistory,
                    ),
                  ),
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
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
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
                    onPressed: () {},
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
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                library.createPlaylist(nameCtrl.text.trim());
              }
              Navigator.pop(ctx);
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
