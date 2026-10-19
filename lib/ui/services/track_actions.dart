import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/app_messenger.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../../state/downloads_controller.dart';
import '../../state/library_controller.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/onboarding_auth_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/app_sheets.dart';

/// Cross-cutting track interactions (play, queue, favorite, playlist, share,
/// navigation, download). Centralised so behaviour is identical everywhere
/// (spec §46 — no duplicated logic).
class TrackActions {
  TrackActions._();

  // ---- Playback ----
  static Future<void> play(BuildContext context, Track track, {List<Track>? queue}) =>
      context.read<PlaybackController>().playTrack(track, queue: queue);

  static Future<void> playAll(BuildContext context, List<Track> tracks,
          {int startIndex = 0}) =>
      context.read<PlaybackController>().playAll(tracks, startIndex: startIndex);

  static Future<void> playNext(BuildContext context, Track track) async {
    await context.read<PlaybackController>().playNext(track);
    AppMessenger.show('Playing next');
  }

  static Future<void> addToQueue(BuildContext context, Track track) async {
    await context.read<PlaybackController>().addToQueue(track);
    AppMessenger.show('Added to queue');
  }

  static Future<void> shufflePlay(BuildContext context, List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final List<Track> copy = <Track>[...tracks]..shuffle();
    final PlaybackController pc = context.read<PlaybackController>();
    if (!pc.queue.shuffle) pc.toggleShuffle();
    await pc.playAll(copy);
  }

  // ---- Favorites ----
  static Future<void> toggleFavorite(BuildContext context, Track track) async {
    final LibraryController library = context.read<LibraryController>();
    if (!library.isAuthenticated) {
      _showSignInPrompt(context, 'Sign in to save favorites to your cloud library');
      return;
    }
    final bool wasLiked = library.isLiked(track.id);
    await library.toggleLike(track);
    AppMessenger.show(wasLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs');
  }

  static Future<void> addToPlaylist(BuildContext context, Track track) async {
    final LibraryController library = context.read<LibraryController>();
    if (!library.isAuthenticated) {
      _showSignInPrompt(context, 'Sign in to create and manage custom playlists');
      return;
    }
    final result = await showAddToPlaylistSheet(context, track);
    if (result != null && context.mounted) {
      AppMessenger.show('Added to “$result”');
    }
  }

  static void _showSignInPrompt(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
  }

  // ---- Share (no technical stream URLs exposed — spec §22) ----
  static Future<void> share(BuildContext context, Track track) async {
    try {
      final String provider = (track.providerId ?? 'custom_api').toString();
      final String pid = (track.providerTrackId ?? track.id).toString();
      final String url = 'https://beats.kalpkrutinfotech.com/track/${provider.replaceAll(':', '-')}/${Uri.encodeComponent(pid)}';
      final String text = 'Listening to “${track.title}” by ${track.artistNames}'
          '${track.album != null ? ' — ${track.album!.title}' : ''} on Kalpkrut Beats\n\nListen: $url';
      await Share.share(text, subject: track.title);
    } catch (_) {
      AppMessenger.show('Sharing is not available here');
    }
  }

  // ---- Navigation ----
  static Future<void> openArtist(BuildContext context, Artist artist) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArtistScreen(artist: artist)),
    );
  }

  static Future<void> openAlbum(BuildContext context, Album album) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlbumScreen(album: album)),
    );
  }

  // ---- Download eligibility ----
  static bool canDownload(BuildContext context, Track track) {
    return context.read<DownloadsController>().canDownload(track);
  }
}
