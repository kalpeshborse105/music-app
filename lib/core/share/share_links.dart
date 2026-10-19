import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/track.dart';
import '../constants/app_constants.dart';

/// Official public share URLs for Kalpkrut Beats (no provider noise in path).
class ShareLinks {
  ShareLinks._();

  static const String host = 'beats.kalpkrutinfotech.com';
  static String get base => AppConstants.officialWebUrl.replaceAll(RegExp(r'/+$'), '');

  static String _cleanId(String raw) {
    String id = raw.trim();
    if (id.contains(':')) {
      id = id.split(':').last;
    }
    return Uri.encodeComponent(id);
  }

  static String song(Track track) {
    final String id = track.providerTrackId.isNotEmpty
        ? track.providerTrackId
        : track.id;
    return '$base/song/${_cleanId(id)}';
  }

  static String album(Album album) {
    final String id = album.providerAlbumId.isNotEmpty
        ? album.providerAlbumId
        : album.id;
    return '$base/album/${_cleanId(id)}';
  }

  static String artist(Artist artist) {
    final String id = artist.providerArtistId.isNotEmpty
        ? artist.providerArtistId
        : artist.id;
    return '$base/artist/${_cleanId(id)}';
  }

  static String playlist(String playlistId) {
    return '$base/playlist/${_cleanId(playlistId)}';
  }

  /// Intent URL used by web share pages to open the installed Android app.
  static String androidIntent(String httpsUrl) {
    final Uri u = Uri.parse(httpsUrl);
    return 'intent://${u.host}${u.path}'
        '#Intent;scheme=https;package=com.kalpkrut.beats;end';
  }
}
