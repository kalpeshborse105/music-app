import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/track.dart';
import '../../ui/screens/album_screen.dart';
import '../../ui/screens/artist_screen.dart';
import '../../ui/screens/list_screen.dart';
import '../../ui/services/track_actions.dart';
import '../music_repository.dart';
import 'fcm_service.dart';
import '../../core/utils/logger.dart';

/// Handles https://beats.kalpkrutinfotech.com/song|album|artist|playlist/... opens
/// and FCM notification taps with target_type / target_id.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  StreamSubscription<Uri>? _sub;
  MusicRepository? _repo;
  bool _booted = false;

  Future<void> start(MusicRepository repo) async {
    _repo = repo;
    if (_booted) return;
    _booted = true;

    FcmService.instance.onNotificationOpen = (Map<String, dynamic> data) {
      openFromPayload(data);
    };

    try {
      final AppLinks links = AppLinks();
      final Uri? initial = await links.getInitialLink();
      if (initial != null) {
        // Delay until navigator is ready.
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          openUri(initial);
        });
      }
      _sub = links.uriLinkStream.listen(openUri, onError: (Object e) {
        Logger.warn('deep link stream error', error: e);
      });
    } catch (e) {
      Logger.warn('deep link init failed', error: e);
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void openFromPayload(Map<String, dynamic> data) {
    final String type = '${data['target_type'] ?? data['type'] ?? ''}'.toLowerCase();
    final String id = '${data['target_id'] ?? data['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    openTyped(type, id, title: '${data['preview_title'] ?? data['title'] ?? ''}');
  }

  void openUri(Uri uri) {
    if (uri.host.isNotEmpty &&
        uri.host != 'beats.kalpkrutinfotech.com' &&
        uri.scheme != 'com.kalpkrut.beats') {
      return;
    }
    // OAuth callback — AuthGate / Supabase handle this.
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      return;
    }
    final List<String> parts = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return;

    // Support both /song/ID and legacy /track/custom_api/ID
    String type = parts.first.toLowerCase();
    String id = '';
    if (type == 'track' && parts.length >= 2) {
      type = 'song';
      id = parts.length >= 3 ? parts.sublist(2).join('/') : parts[1];
      if (id == 'custom_api' && parts.length >= 3) {
        id = parts.sublist(2).join('/');
      }
    } else if (parts.length >= 2) {
      id = Uri.decodeComponent(parts.sublist(1).join('/'));
    }
    if (id.isEmpty) return;
    if (id == 'custom_api' && parts.length >= 3) {
      id = Uri.decodeComponent(parts.sublist(2).join('/'));
    }
    openTyped(type, id);
  }

  Future<void> openTyped(String type, String id, {String title = ''}) async {
    final NavigatorState? nav = KalpkrutBeatsApp.navigatorKey.currentState;
    if (nav == null) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        openTyped(type, id, title: title);
      });
      return;
    }
    final BuildContext? ctx = nav.context;
    if (ctx == null || !ctx.mounted) return;

    final String clean = id.contains(':') ? id.split(':').last : id;
    final String kind = type.toLowerCase();

    try {
      if (kind == 'song' || kind == 'track') {
        await _openSong(ctx, clean, title: title);
        return;
      }
      if (kind == 'album') {
        nav.push(MaterialPageRoute<void>(
          builder: (_) => AlbumScreen(
            album: Album(
              id: 'custom_api:album:$clean',
              providerId: 'custom_api',
              providerAlbumId: clean,
              title: title.isNotEmpty ? title : 'Album',
            ),
          ),
        ));
        return;
      }
      if (kind == 'artist') {
        nav.push(MaterialPageRoute<void>(
          builder: (_) => ArtistScreen(
            artist: Artist(
              id: 'custom_api:artist:$clean',
              providerId: 'custom_api',
              providerArtistId: clean,
              name: title.isNotEmpty ? title : 'Artist',
            ),
          ),
        ));
        return;
      }
      if (kind == 'playlist' || kind == 'catalog') {
        final MusicRepository? repo = _repo;
        if (repo != null) {
          try {
            final Track? seed = await repo.resolveTrack(clean);
            if (seed != null && ctx.mounted) {
              await TrackActions.play(ctx, seed);
              return;
            }
          } catch (_) {}
        }
        nav.push(MaterialPageRoute<void>(
          builder: (_) => TrackListScreen(
            title: title.isNotEmpty ? title : 'Playlist',
            tracks: const <Track>[],
          ),
        ));
      }
    } catch (e) {
      Logger.warn('deep link open failed', error: e);
    }
  }

  Future<void> _openSong(BuildContext context, String id, {String title = ''}) async {
    final MusicRepository? repo = _repo;
    Track? track;
    if (repo != null) {
      try {
        track = await repo.resolveTrack(id);
      } catch (_) {}
      if (track == null) {
        try {
          track = await repo.getTrackByProviderId(id);
        } catch (_) {}
      }
    }
    if (!context.mounted) return;
    if (track != null) {
      await TrackActions.play(context, track);
      return;
    }
    // Fallback: open empty list with title so user lands in-app.
    KalpkrutBeatsApp.navigatorKey.currentState?.push(MaterialPageRoute<void>(
      builder: (_) => TrackListScreen(
        title: title.isNotEmpty ? title : 'Song',
        tracks: const <Track>[],
      ),
    ));
  }
}
