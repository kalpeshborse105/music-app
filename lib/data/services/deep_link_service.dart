import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/track.dart';
import '../../ui/screens/album_screen.dart';
import '../../ui/screens/artist_screen.dart';
import '../../ui/screens/list_screen.dart';
import '../../ui/services/track_actions.dart';
import '../music_repository.dart';
import 'fcm_service.dart';

/// Handles https://beats…/song|album|artist|playlist and
/// com.kalpkrut.beats://song/… plus FCM notification taps.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  StreamSubscription<Uri>? _sub;
  MusicRepository? _repo;
  bool _booted = false;
  String? _lastHandled;

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
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
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
    final String type =
        '${data['target_type'] ?? data['type'] ?? ''}'.toLowerCase();
    final String id = '${data['target_id'] ?? data['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    openTyped(
      type.isEmpty ? 'song' : type,
      id,
      title: '${data['preview_title'] ?? data['title'] ?? ''}',
    );
  }

  void openUri(Uri uri) {
    // Custom scheme: com.kalpkrut.beats://song/ID
    // HTTPS: https://beats.kalpkrutinfotech.com/song/ID
    final bool isAppScheme = uri.scheme == 'com.kalpkrut.beats';
    final bool isHttpsHost = uri.host == 'beats.kalpkrutinfotech.com';
    if (!isAppScheme && !isHttpsHost && uri.host.isNotEmpty) {
      return;
    }
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      return;
    }

    final List<String> parts =
        uri.pathSegments.where((String s) => s.isNotEmpty).toList();

    String type = '';
    String id = '';

    if (isAppScheme) {
      // host is type (song/album/…), path is id
      type = uri.host.toLowerCase();
      if (parts.isNotEmpty) {
        id = Uri.decodeComponent(parts.join('/'));
      } else if (uri.path.isNotEmpty) {
        id = Uri.decodeComponent(uri.path.replaceFirst('/', ''));
      }
    } else {
      if (parts.isEmpty) return;
      type = parts.first.toLowerCase();
      if (type == 'share' && parts.length >= 3) {
        type = parts[1].toLowerCase();
        id = Uri.decodeComponent(parts.sublist(2).join('/'));
      } else if (type == 'track') {
        type = 'song';
        // /track/custom_api/ID or /track/ID
        if (parts.length >= 3 && parts[1] == 'custom_api') {
          id = Uri.decodeComponent(parts.sublist(2).join('/'));
        } else if (parts.length >= 2) {
          id = Uri.decodeComponent(parts.sublist(1).join('/'));
          if (id == 'custom_api' && parts.length >= 3) {
            id = Uri.decodeComponent(parts.sublist(2).join('/'));
          }
        }
      } else if (parts.length >= 2) {
        id = Uri.decodeComponent(parts.sublist(1).join('/'));
      }
    }

    if (id.isEmpty || type.isEmpty) return;
    if (id == 'custom_api') return;
    openTyped(type, id);
  }

  Future<void> openTyped(String type, String id, {String title = ''}) async {
    final String clean = id.contains(':') ? id.split(':').last : id;
    final String kind = type.toLowerCase();
    final String dedupeKey = '$kind:$clean';
    if (_lastHandled == dedupeKey) return;
    _lastHandled = dedupeKey;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_lastHandled == dedupeKey) _lastHandled = null;
    });

    NavigatorState? nav = KalpkrutBeatsApp.navigatorKey.currentState;
    if (nav == null) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        _lastHandled = null;
        openTyped(type, id, title: title);
      });
      return;
    }
    final BuildContext? ctx = nav.context;
    if (ctx == null || !ctx.mounted) return;

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
        await _openSong(ctx, clean, title: title.isNotEmpty ? title : 'Playlist');
      }
    } catch (e) {
      Logger.warn('deep link open failed', error: e);
    }
  }

  Future<void> _openSong(BuildContext context, String id, {String title = ''}) async {
    final MusicRepository? repo = _repo;
    Track? track;
    if (repo != null) {
      // Prefer direct track API (reliable for share ids).
      try {
        track = await repo.getTrackByProviderId(id);
      } catch (_) {}
      if (track == null) {
        try {
          track = await repo.resolveTrack(id);
        } catch (_) {}
      }
    }
    if (!context.mounted) return;
    if (track != null) {
      await TrackActions.play(context, track);
      return;
    }
    KalpkrutBeatsApp.navigatorKey.currentState?.push(MaterialPageRoute<void>(
      builder: (_) => TrackListScreen(
        title: title.isNotEmpty ? title : 'Song',
        tracks: const <Track>[],
      ),
    ));
  }
}
