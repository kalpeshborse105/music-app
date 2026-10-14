import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
import '../../domain/models/album.dart';
import '../../domain/models/track.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/artwork.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';

/// Album detail: cover, metadata, track list, play/shuffle/favorite (spec §21).
class AlbumScreen extends StatefulWidget {
  final Album album;
  final List<Track>? initialTracks;

  const AlbumScreen({
    super.key,
    required this.album,
    this.initialTracks,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late Future<List<Track>> _future = (widget.initialTracks != null && widget.initialTracks!.isNotEmpty)
      ? Future<List<Track>>.value(widget.initialTracks)
      : _load();

  Future<List<Track>> _load() =>
      context.read<MusicRepository>().albumTrackList(widget.album);

  @override
  Widget build(BuildContext context) {
    final bool saved = context.watch<LibraryController>().isAlbumSaved(widget.album.id);
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<Track>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<Track>> snap) {
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen,
                  child: Column(
                    children: <Widget>[
                      Artwork(
                        url: widget.album.artworkUrl,
                        size: 180,
                        radius: AppSpacing.radiusLg,
                        fallbackIcon: Icons.album_rounded,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        widget.album.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(widget.album.artistNames,
                          style: Theme.of(context).textTheme.bodySmall),
                      if (widget.album.year != null)
                        Text('${widget.album.year}',
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: (snap.data?.isEmpty ?? true)
                                ? null
                                : () => TrackActions.playAll(context, snap.data!),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            tooltip: saved ? 'Remove from library' : 'Save album',
                            onPressed: () => context
                                .read<LibraryController>()
                                .toggleSaveAlbum(widget.album),
                            icon: Icon(saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingView(),
                )
              else if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView.fromError(snap.error!,
                      onRetry: () => setState(() => _future = _load())),
                )
              else if ((snap.data ?? <Track>[]).isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView(
                    icon: Icons.music_off_rounded,
                    title: 'No tracks available',
                  ),
                )
              else
                SliverList.builder(
                  itemCount: snap.data!.length,
                  itemBuilder: (BuildContext c, int i) {
                    final Track t = snap.data![i];
                    return TrackTile(
                      track: t,
                      index: i,
                      onTap: () =>
                          TrackActions.playAll(context, snap.data!, startIndex: i),
                      onMenu: () => showTrackActionsSheet(context, t),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }
}
