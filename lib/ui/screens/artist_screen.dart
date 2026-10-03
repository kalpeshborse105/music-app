import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/track.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/artwork.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';

/// Stitch Artist Screen: artwork hero, verified checkmark, albums carousel,
/// and popular tracks list.
class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late final Future<List<Track>> _topTracks =
      context.read<MusicRepository>().artistTopTracks(widget.artist);
  late final Future<List<Album>> _albums =
      context.read<MusicRepository>().artistAlbums(widget.artist);

  @override
  Widget build(BuildContext context) {
    final bool following =
        context.watch<LibraryController>().isFollowingArtist(widget.artist.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist.name),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: <Widget>[
          Padding(
            padding: AppSpacing.screen,
            child: Column(
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Container(
                      width: 148,
                      height: 148,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.heroGradient,
                      ),
                      child: Center(
                        child: ClipOval(
                          child: Artwork(
                            url: widget.artist.imageUrl,
                            size: 140,
                            radius: 70,
                            fallbackIcon: Icons.person_rounded,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 16, color: AppColors.onSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.artist.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Verified Artist • Flow Catalog',
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: following ? AppColors.surfaceContainerHigh : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context
                      .read<LibraryController>()
                      .toggleFollowArtist(widget.artist),
                  icon: Icon(following
                      ? Icons.check_rounded
                      : Icons.person_add_alt_1_rounded),
                  label: Text(following ? 'Following' : 'Follow'),
                ),
              ],
            ),
          ),
          FutureBuilder<List<Album>>(
            future: _albums,
            builder: (BuildContext context, AsyncSnapshot<List<Album>> snap) {
              final albums = snap.data ?? <Album>[];
              if (albums.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader(title: 'Discography & Albums'),
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: AppSpacing.screen,
                      itemCount: albums.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (BuildContext c, int i) => MediaCard.forAlbum(
                        album: albums[i],
                        onTap: () => TrackActions.openAlbum(context, albums[i]),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SectionHeader(title: 'Popular Tracks'),
          FutureBuilder<List<Track>>(
            future: _topTracks,
            builder: (BuildContext context, AsyncSnapshot<List<Track>> snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: LoadingView(),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: MessageView.fromError(snap.error!),
                );
              }
              final tracks = snap.data ?? <Track>[];
              if (tracks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: MessageView(
                    icon: Icons.music_off_rounded,
                    title: 'No tracks available',
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (int i = 0; i < tracks.length; i++)
                    TrackTile(
                      track: tracks[i],
                      index: i,
                      onTap: () =>
                          TrackActions.playAll(context, tracks, startIndex: i),
                      onMenu: () => showTrackActionsSheet(context, tracks[i]),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
