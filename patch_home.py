import re

def main():
    file_path = r'd:\music-app\lib\ui\screens\home_screen.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update State Variables
    content = content.replace(
        '''  late Future<List<Track>> _trendingFuture;
  late Future<List<Track>> _newReleasesFuture;
  late Future<List<Track>> _spotlightFuture;
  Future<List<Track>>? _categoryTracksFuture;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  final List<Track> _infiniteTracks = <Track>[];
  bool _isLoadingMore = false;''',
        '''  late Future<List<Track>> _newReleasesFuture;
  late Future<List<Track>> _spotlightFuture;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  final List<Track> _infiniteTracks = <Track>[];
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;'''
    )

    # 2. Update _onScrollToTop
    content = content.replace(
        '''  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    final MusicRepository repo = context.read<MusicRepository>();
    setState(() {
      _infiniteTracks.clear();
      final String? lang = _selectedMood == 'All' ? null : _selectedMood.toLowerCase();
      _trendingFuture = repo.trending(limit: 20, language: lang);
      _newReleasesFuture = repo.newReleases(limit: 10);
    });
  }''',
        '''  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    final MusicRepository repo = context.read<MusicRepository>();
    setState(() {
      _newReleasesFuture = repo.newReleases(limit: 10);
    });
    _loadInitialTracks();
  }'''
    )

    # 3. Add _loadInitialTracks and update _loadMore
    content = content.replace(
        '''  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final String? lang = _selectedMood == 'All' ? null : _selectedMood.toLowerCase();
      final List<Track> more = await repo.trending(
        limit: 20,
        offset: _infiniteTracks.length,
        language: lang,
      );
      if (more.isNotEmpty && mounted) {
        setState(() {
          final Set<String> existingIds = _infiniteTracks.map((Track t) => t.id).toSet();
          for (final Track t in more) {
            final String normKey = '${t.title.toLowerCase().trim()}|${t.artistNames.toLowerCase().trim()}';
            final bool duplicate = _infiniteTracks.any((Track existing) =>
                existing.id == t.id ||
                '${existing.title.toLowerCase().trim()}|${existing.artistNames.toLowerCase().trim()}' == normKey);
            if (!duplicate && existingIds.add(t.id)) {
              _infiniteTracks.add(t);
            }
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }''',
        '''  Future<void> _loadInitialTracks() async {
    if (_isLoadingInitial) return;
    setState(() {
      _isLoadingInitial = true;
      _infiniteTracks.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final String? lang = _selectedMood == 'All' ? null : _selectedMood.toLowerCase();
      final List<Track> initial = await repo.trending(
        limit: 20,
        offset: _currentOffset,
        language: lang,
      );
      if (mounted) {
        setState(() {
          _currentOffset += 20;
          _infiniteTracks.addAll(initial);
          if (initial.isEmpty) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final String? lang = _selectedMood == 'All' ? null : _selectedMood.toLowerCase();
      final List<Track> more = await repo.trending(
        limit: 20,
        offset: _currentOffset,
        language: lang,
      );
      if (mounted) {
        setState(() {
          if (more.isEmpty) {
            _hasMore = false;
          } else {
            _currentOffset += 20;
            final Set<String> existingIds = _infiniteTracks.map((Track t) => t.id).toSet();
            for (final Track t in more) {
              final String normKey = '${t.title.toLowerCase().trim()}|${t.artistNames.toLowerCase().trim()}';
              final bool duplicate = _infiniteTracks.any((Track existing) =>
                  existing.id == t.id ||
                  '${existing.title.toLowerCase().trim()}|${existing.artistNames.toLowerCase().trim()}' == normKey);
              if (!duplicate && existingIds.add(t.id)) {
                _infiniteTracks.add(t);
              }
            }
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }'''
    )

    # 4. Update didChangeDependencies
    content = content.replace(
        '''  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final MusicRepository repo = context.read<MusicRepository>();
      _trendingFuture = repo.trending(limit: 20);
      _newReleasesFuture = repo.newReleases(limit: 8);
      _spotlightFuture = repo.trending(limit: 1);
    }
  }''',
        '''  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final MusicRepository repo = context.read<MusicRepository>();
      _newReleasesFuture = repo.newReleases(limit: 8);
      _spotlightFuture = repo.trending(limit: 1);
      _loadInitialTracks();
    }
  }'''
    )

    # 5. Update _onMoodSelected
    content = content.replace(
        '''  void _onMoodSelected(String mood, MusicRepository repo) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
      _infiniteTracks.clear();
      final String? lang = mood == 'All' ? null : mood.toLowerCase();
      _trendingFuture = repo.trending(limit: 20, offset: 0, language: lang);
      if (mood != 'All') {
        _categoryTracksFuture = _fetchCategoryTracks(mood, repo);
      } else {
        _categoryTracksFuture = null;
      }
    });
  }

  Future<List<Track>> _fetchCategoryTracks(String category, MusicRepository repo) async {
    try {
      final List<Track> tracks = await repo.trending(
        limit: 20,
        offset: 0,
        language: category.toLowerCase(),
      );
      if (tracks.isNotEmpty) {
        return tracks;
      }
    } catch (_) {}
    return repo.trending(limit: 20);
  }''',
        '''  void _onMoodSelected(String mood, MusicRepository repo) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
    });
    _loadInitialTracks();
  }'''
    )

    # 6. Update _buildCategoryView to remove FutureBuilder
    content = re.sub(
        r'  Widget _buildCategoryView\(\n.*?}\n\n  Widget _buildJumpBackInSection',
        '''  Widget _buildCategoryView(
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
                else if (!_hasMore && tracks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('You\\'ve reached the end', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildJumpBackInSection''',
        content,
        flags=re.DOTALL
    )

    # 7. Update _buildTrendingRankedSection
    content = re.sub(
        r'  Widget _buildTrendingRankedSection\(\n.*?}\n\n  /// Builds',
        '''  Widget _buildTrendingRankedSection(BuildContext context, PlaybackController pc) {
    final bool isLoading = _isLoadingInitial && _infiniteTracks.isEmpty;
    final List<Track> tracks = _infiniteTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Trending Right Now',
          subtitle: 'Global top streams updated live',
          topPadding: AppSpacing.sm,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (context.isDarkMode ? AppColors.secondary : AppColors.lightSecondaryAccent)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (context.isDarkMode ? AppColors.secondary : AppColors.lightSecondaryAccent)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.auto_graph_rounded,
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
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          )
        else if (tracks.isEmpty)
          const SizedBox.shrink()
        else
          Padding(
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
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (!_hasMore && tracks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('You\\'ve reached the end', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds''',
        content,
        flags=re.DOTALL
    )

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched home_screen.dart!")

if __name__ == '__main__':
    main()
