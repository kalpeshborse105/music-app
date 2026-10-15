import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/track.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';

/// Full-featured Playlist / Category discovery screen for Indian music categories.
class CategoryDetailScreen extends StatefulWidget {
  final String title;
  final String query;
  final String? subtitle;
  final String? artworkUrl;
  final List<Color>? gradientColors;
  final String? emoji;

  const CategoryDetailScreen({
    super.key,
    required this.title,
    required this.query,
    this.subtitle,
    this.artworkUrl,
    this.gradientColors,
    this.emoji,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() {
    final MusicRepository repo = context.read<MusicRepository>();
    _tracksFuture = repo.search(widget.query, limit: 30).then((SearchResult r) {
      if (r.tracks.isNotEmpty) {
        return r.tracks;
      }
      // Fallback search with generic query if specific query yielded 0
      return repo.search('${widget.title} songs', limit: 25).then((SearchResult r2) => r2.tracks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = widget.gradientColors ??
        const <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)];

    return Scaffold(
      bottomNavigationBar: const SafeArea(
        top: false,
        child: MiniPlayer(),
      ),
      body: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (BuildContext ctx, AsyncSnapshot<List<Track>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: const LoadingView(message: 'Loading songs...'),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: MessageView(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load songs',
                subtitle: 'Check your connection or try again.',
                actionLabel: 'Retry',
                onAction: () => setState(_loadTracks),
              ),
            );
          }

          final List<Track> tracks = snapshot.data ?? <Track>[];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              // Hero App Bar with Artwork and Gradient
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? AppColors.darkBg : AppColors.lightElevatedSurface,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  title: Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (widget.artworkUrl != null && widget.artworkUrl!.isNotEmpty)
                        Artwork(
                          url: widget.artworkUrl,
                          size: 360,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.music_note_rounded,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: widget.emoji != null && widget.emoji!.isNotEmpty
                                ? Text(widget.emoji!, style: const TextStyle(fontSize: 72))
                                : const Icon(Icons.music_note_rounded, size: 72, color: Colors.white54),
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.lg,
                        bottom: 60,
                        right: AppSpacing.lg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...<Widget>[
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              '${tracks.length} tracks • Curated Playlist',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons Row: Play All & Shuffle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: tracks.isEmpty
                                ? null
                                : () => TrackActions.playAll(context, tracks),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            label: const Text(
                              'Play All',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                          ),
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onPressed: tracks.isEmpty
                              ? null
                              : () => TrackActions.shufflePlay(context, tracks),
                          icon: const Icon(Icons.shuffle_rounded, size: 22, color: AppColors.secondary),
                          tooltip: 'Shuffle Play',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Song List
              if (tracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView(
                    icon: Icons.music_off_rounded,
                    title: 'No songs found',
                    subtitle: 'Unable to find songs for this category right now.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext c, int i) {
                        final Track t = tracks[i];
                        return TrackTile(
                          track: t,
                          index: i,
                          onTap: () => TrackActions.playAll(context, tracks, startIndex: i),
                          onMenu: () => showTrackActionsSheet(context, t),
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
