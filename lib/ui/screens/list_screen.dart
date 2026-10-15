import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/track.dart';
import '../../domain/providers/local_provider.dart';
import '../../state/library_controller.dart';
import '../services/track_actions.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheets.dart';
import '../widgets/mini_player.dart';
import '../widgets/sheet_scaffolds.dart';
import '../widgets/state_views.dart';
import '../widgets/track_tile.dart';

/// Generic scrollable list of tracks with a "play all" / "shuffle" header.
class TrackListScreen extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  final String? subtitle;

  const TrackListScreen({
    super.key,
    required this.title,
    required this.tracks,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: MiniPlayer(),
      ),
      body: tracks.isEmpty
          ? const MessageView(
              icon: Icons.music_off_rounded,
              title: 'No tracks yet',
              subtitle: 'Tracks you add will appear here.',
            )
          : Column(
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
                      FilledButton.icon(
                        onPressed: () => TrackActions.playAll(context, tracks),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => TrackActions.shufflePlay(context, tracks),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: AppSpacing.screen,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: tracks.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Track t = tracks[i];
                      return TrackTile(
                        track: t,
                        index: i,
                        onTap: () => TrackActions.playAll(context, tracks, startIndex: i),
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

/// The user's playlists: create, open, rename, delete.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryController library = context.watch<LibraryController>();
    final playlists = library.playlists;

    return Scaffold(
      appBar: AppBar(title: const Text('My playlists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await promptForText(context,
              title: 'New playlist', hint: 'Playlist name');
          if (name != null && name.trim().isNotEmpty) {
            await library.createPlaylist(name.trim());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: playlists.isEmpty
          ? const MessageView(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              subtitle: 'Create a playlist to organise your music.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext c, int i) {
                final p = playlists[i];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6C4DF6), Color(0xFF19C3A4)],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: Colors.white),
                  ),
                  title: Text(p.title),
                  subtitle: Text('${p.trackCount} songs'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                  )),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String v) async {
                      if (v == 'rename') {
                        final name = await promptForText(context,
                            title: 'Rename playlist', initialValue: p.title);
                        if (name != null && name.trim().isNotEmpty) {
                          await library.renamePlaylist(p.id, name.trim());
                        }
                      } else if (v == 'delete') {
                        final ok = await confirmDialog(context,
                            title: 'Delete playlist?',
                            message: 'This cannot be undone.',
                            confirmLabel: 'Delete',
                            destructive: true);
                        if (ok) await library.deletePlaylist(p.id);
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                      PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Detail view for a user playlist.
class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final playlist = library.playlist(playlistId);
    if (playlist == null) {
      return const Scaffold(
        body: MessageView(icon: Icons.error_outline, title: 'Playlist not found'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(playlist.title)),
      body: playlist.tracks.isEmpty
          ? const MessageView(
              icon: Icons.library_add_outlined,
              title: 'This playlist is empty',
              subtitle: 'Add songs from any track menu.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: playlist.tracks.length,
              itemBuilder: (BuildContext c, int i) {
                final Track t = playlist.tracks[i];
                return TrackTile(
                  track: t,
                  index: i,
                  onTap: () => TrackActions.playAll(
                      context, playlist.tracks, startIndex: i),
                  onMenu: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (BuildContext ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(Icons.play_arrow_rounded),
                            title: const Text('Play'),
                            onTap: () {
                              Navigator.pop(ctx);
                              TrackActions.playAll(context, playlist.tracks,
                                  startIndex: i);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete_outline_rounded),
                            title: const Text('Remove from playlist'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await library.removeTrackFromPlaylist(
                                  playlist.id, t.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Device (local) music.
class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({super.key});

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LocalMusicProvider>();
      context.read<LibraryController>().scanLocal(provider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('On this device'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final provider = context.read<LocalMusicProvider>();
              library.scanLocal(provider, force: true);
            },
          ),
        ],
      ),
      body: library.localScanning
          ? const LoadingView(message: 'Scanning your device…')
          : library.localTracks.isEmpty
              ? const MessageView(
                  icon: Icons.smartphone_rounded,
                  title: 'No local music found',
                  subtitle:
                      'Grant music permission, or add audio files to your device. '
                      'Your files never leave this device.',
                )
              : ListView.builder(
                  itemCount: library.localTracks.length,
                  itemBuilder: (BuildContext c, int i) {
                    final Track t = library.localTracks[i];
                    return TrackTile(
                      track: t,
                      onTap: () => TrackActions.playAll(
                          context, library.localTracks, startIndex: i),
                      onMenu: () => showTrackActionsSheet(context, t),
                    );
                  },
                ),
    );
  }
}
