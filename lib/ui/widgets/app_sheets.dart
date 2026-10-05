import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_messenger.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../screens/lyrics_screen.dart';
import '../services/track_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'artwork.dart';
import 'sheet_scaffolds.dart';

/// Bottom sheet with every per-track action (spec §22).
Future<void> showTrackActionsSheet(BuildContext context, Track track) async {
  final LibraryController library = context.read<LibraryController>();
  final DownloadsController downloads = context.read<DownloadsController>();
  final bool liked = library.isLiked(track.id);
  final bool downloaded = downloads.isDownloaded(track.id);
  final bool canDownload = downloads.canDownload(track);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Artwork(url: track.artworkUrl, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        Text(
                          track.artistNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        if (track.album != null &&
                            track.album!.title.isNotEmpty &&
                            track.album!.title != 'Single') ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            track.album!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _SheetAction(
              icon: Icons.play_arrow_rounded,
              label: 'Play now',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.play(context, track);
              },
            ),
            _SheetAction(
              icon: Icons.playlist_play_rounded,
              label: 'Play next',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.playNext(context, track);
              },
            ),
            _SheetAction(
              icon: Icons.queue_music_rounded,
              label: 'Add to queue',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.addToQueue(context, track);
              },
            ),
            _SheetAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.toggleFavorite(context, track);
              },
            ),
            _SheetAction(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.addToPlaylist(context, track);
              },
            ),
            _SheetAction(
              icon: Icons.lyrics_rounded,
              label: 'Lyrics',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LyricsScreen(track: track),
                  ),
                );
              },
            ),
            if (canDownload)
              _SheetAction(
                icon: downloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                label: downloaded ? 'Remove download' : 'Download',
                onTap: () async {
                  Navigator.pop(ctx);
                  if (downloaded) {
                    await downloads.remove(track.id);
                    AppMessenger.show('Removed download');
                  } else {
                    try {
                      await downloads.download(track);
                      AppMessenger.show('Downloaded');
                    } catch (e) {
                      AppMessenger.showError(e);
                    }
                  }
                },
              ),
            _SheetAction(
              icon: Icons.bedtime_rounded,
              label: 'Sleep timer',
              onTap: () {
                Navigator.pop(ctx);
                showSleepTimerSheet(context);
              },
            ),
            _SheetAction(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(ctx);
                TrackActions.share(context, track);
              },
            ),
            if (track.album != null)
              _SheetAction(
                icon: Icons.album_rounded,
                label: 'Go to album',
                onTap: () {
                  Navigator.pop(ctx);
                  TrackActions.openAlbum(context, track.album!);
                },
              ),
            if (track.artists.isNotEmpty)
              _SheetAction(
                icon: Icons.person_rounded,
                label: 'Go to artist',
                onTap: () {
                  Navigator.pop(ctx);
                  TrackActions.openArtist(context, track.primaryArtist);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      minVerticalPadding: AppSpacing.md,
    );
  }
}

/// Sheet to add a track to one of the user's playlists, or create a new one.
/// Returns the playlist title on success, otherwise null.
Future<String?> showAddToPlaylistSheet(BuildContext context, Track track) async {
  final LibraryController library = context.read<LibraryController>();
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Add to playlist',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: () async {
                final String? name = await promptForText(
                  ctx,
                  title: 'New playlist',
                  hint: 'Playlist name',
                );
                if (name == null || name.trim().isEmpty) return;
                final playlist = await library.createPlaylist(name.trim());
                await library.addTrackToPlaylist(playlist.id, track);
                if (ctx.mounted) Navigator.pop(ctx, playlist.title);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: Builder(
                builder: (BuildContext inner) {
                  final playlists = library.playlists;
                  if (playlists.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'You have no playlists yet.',
                        style: Theme.of(inner).textTheme.bodySmall,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (BuildContext c, int i) {
                      final p = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music_rounded),
                        title: Text(p.title),
                        subtitle: Text('${p.trackCount} songs'),
                        onTap: () async {
                          await library.addTrackToPlaylist(p.id, track);
                          if (ctx.mounted) Navigator.pop(ctx, p.title);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

/// The playback queue, with reorder / remove / jump (spec §8).
Future<void> showQueueSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return Consumer<PlaybackController>(
        builder: (BuildContext c, PlaybackController pb, Widget? _) {
          final List<Track> queue = pb.queue.tracks;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (BuildContext c2, ScrollController controller) {
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Playing queue',
                            style: Theme.of(c).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${queue.length} tracks',
                          style: Theme.of(c).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: queue.isEmpty
                        ? Center(
                            child: Text(
                              'The queue is empty.',
                              style: Theme.of(c).textTheme.bodySmall,
                            ),
                          )
                        : ReorderableListView.builder(
                            scrollController: controller,
                            itemCount: queue.length,
                            onReorderItem: (int oldIndex, int newIndex) =>
                                pb.reorderQueue(oldIndex, newIndex),
                            itemBuilder: (BuildContext c3, int i) {
                              final Track t = queue[i];
                              final bool current = i == pb.queue.currentIndex;
                              return ListTile(
                                key: ValueKey<String>('${t.id}-$i'),
                                leading: current
                                    ? Icon(Icons.graphic_eq_rounded,
                                        color: Theme.of(c3).colorScheme.primary)
                                    : Artwork(url: t.artworkUrl, size: 44),
                                title: Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: current
                                        ? Theme.of(c3).colorScheme.primary
                                        : null,
                                    fontWeight:
                                        current ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  t.artistNames,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () => pb.removeFromQueue(i),
                                ),
                                onTap: () => pb.jumpTo(i),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

/// Spotify/JioSaavn-style Sleep Timer modal sheet.
Future<void> showSleepTimerSheet(BuildContext context) async {
  final PlaybackController pc = context.read<PlaybackController>();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      final bool hasTimer = pc.hasActiveSleepTimer;
      final Duration? remaining = pc.sleepTimerRemaining;

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.bedtime_rounded, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Sleep timer',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (hasTimer)
                    Text(
                      pc.stopAtTrackEnd
                          ? 'Ends with track'
                          : (remaining != null ? '${remaining.inMinutes}m left' : 'Active'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('15 minutes'),
              trailing: !pc.stopAtTrackEnd && remaining != null && remaining.inMinutes <= 15 && remaining.inMinutes > 5
                  ? const Icon(Icons.check_rounded, color: AppColors.secondary)
                  : null,
              onTap: () {
                pc.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(ctx);
                AppMessenger.show('Sleep timer set for 15 minutes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('30 minutes'),
              onTap: () {
                pc.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(ctx);
                AppMessenger.show('Sleep timer set for 30 minutes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('45 minutes'),
              onTap: () {
                pc.setSleepTimer(const Duration(minutes: 45));
                Navigator.pop(ctx);
                AppMessenger.show('Sleep timer set for 45 minutes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('1 hour'),
              onTap: () {
                pc.setSleepTimer(const Duration(hours: 1));
                Navigator.pop(ctx);
                AppMessenger.show('Sleep timer set for 1 hour');
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_rounded),
              title: const Text('End of track'),
              trailing: pc.stopAtTrackEnd ? const Icon(Icons.check_rounded, color: AppColors.secondary) : null,
              onTap: () {
                pc.setSleepTimer(null, endOfTrack: true);
                Navigator.pop(ctx);
                AppMessenger.show('Sleep timer set to end of track');
              },
            ),
            if (hasTimer)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined, color: AppColors.error),
                title: const Text(
                  'Turn off timer',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  pc.cancelSleepTimer();
                  Navigator.pop(ctx);
                  AppMessenger.show('Sleep timer turned off');
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
