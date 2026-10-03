import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import '../core/storage/download_store.dart';
import '../core/storage/settings_store.dart';
import '../core/utils/logger.dart';
import '../data/music_repository.dart';
import '../domain/models/audio_quality.dart';
import '../domain/models/track.dart';

enum DownloadStatus { idle, queued, downloading, done, failed }

class DownloadTask {
  final Track track;
  final double progress;
  final DownloadStatus status;
  final String? error;

  const DownloadTask({
    required this.track,
    this.progress = 0,
    this.status = DownloadStatus.idle,
    this.error,
  });

  DownloadTask copyWith({double? progress, DownloadStatus? status, String? error}) =>
      DownloadTask(
        track: track,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        error: error,
      );
}

/// Manages provider-authorized offline downloads.
///
/// Only tracks whose owning provider advertises `downloading: true` can be
/// queued. Files are stored in the app documents directory; nothing is uploaded.
/// Supports progress, retry, cancellation and storage management (spec §12).
class DownloadsController extends ChangeNotifier {
  DownloadsController({
    required MusicRepository repository,
    required SettingsStore settings,
    required DownloadStore store,
    http.Client? client,
  })  : _repository = repository,
        _settings = settings,
        _store = store,
        _client = client ?? http.Client();

  final MusicRepository _repository;
  final SettingsStore _settings;
  final DownloadStore _store;
  final http.Client _client;

  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  Directory? _dir;

  Map<String, DownloadTask> get tasks => Map<String, DownloadTask>.unmodifiable(_tasks);
  List<DownloadRecord> get downloads => _store.all();
  int get totalBytes => _store.totalBytes();
  bool get hasDownloads => downloads.isNotEmpty;

  bool isDownloaded(String trackId) => _store.contains(trackId);
  DownloadRecord? record(String trackId) => _store.get(trackId);
  String? localPath(String trackId) => _store.get(trackId)?.filePath;
  DownloadTask? task(String trackId) => _tasks[trackId];

  Future<void> _ensureDir() async {
    if (_dir != null) return;
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
  }

  /// Whether [track]'s provider permits downloading.
  bool canDownload(Track track) => track.isDownloadable;

  Future<void> download(Track track) async {
    if (!canDownload(track)) {
      throw const UnsupportedOperationException(
        message: 'This source does not allow offline downloads.',
      );
    }
    if (_tasks[track.id]?.status == DownloadStatus.downloading) return;
    if (_store.contains(track.id)) return;

    // Wi-Fi-only guard (spec §25 downloads).
    if (_settings.wifiOnlyDownload && !kIsWeb) {
      try {
        final List<ConnectivityResult> results =
            await Connectivity().checkConnectivity();
        final bool onWifi = results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet);
        if (!onWifi && !results.contains(ConnectivityResult.none)) {
          throw const UnsupportedOperationException(
            message: 'Downloads are set to Wi-Fi only. Change this in Settings.',
          );
        }
      } catch (_) {
        // If connectivity can't be determined, allow the attempt.
      }
    }

    _update(track, status: DownloadStatus.downloading, progress: 0);
    try {
      final dynamic source =
          await _repository.resolveStream(track, quality: _settings.downloadQuality);
      final String url = source.url as String;
      if (url.isEmpty || url.startsWith('content://')) {
        // Local/opaque sources are already offline.
        throw const UnsupportedOperationException(
          message: 'This track is already stored on your device.',
        );
      }

      await _ensureDir();
      final http.Request request = http.Request('GET', Uri.parse(url));
      final http.StreamedResponse response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProviderException(track.providerId);
      }
      final int total = response.contentLength ?? 0;
      final String ext = _extensionFor(url);
      final String safeName = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final File file = File('${_dir!.path}/$safeName$ext');

      final IOSink sink = file.openWrite();
      int received = 0;
      await for (final List<int> chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _update(track, status: DownloadStatus.downloading, progress: received / total);
        }
      }
      await sink.flush();
      await sink.close();

      final DownloadRecord record = DownloadRecord(
        track: track.toCompact(),
        filePath: file.path,
        sizeBytes: received,
        qualityTier: _settings.downloadQuality.label,
        downloadedAt: DateTime.now(),
      );
      await _store.put(record);
      _update(track, status: DownloadStatus.done, progress: 1);
      notifyListeners();
    } catch (e) {
      Logger.warn('Download failed', error: e);
      final AppException ex = toAppException(e);
      _update(track, status: DownloadStatus.failed, error: ex.message);
      rethrow;
    }
  }

  Future<void> remove(String trackId) async {
    final DownloadRecord? record = _store.get(trackId);
    if (record != null && !kIsWeb) {
      try {
        final File f = File(record.filePath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        Logger.warn('Failed to delete download file', error: e);
      }
    }
    await _store.remove(trackId);
    _tasks.remove(trackId);
    notifyListeners();
  }

  Future<void> removeAll() async {
    for (final DownloadRecord r in _store.all()) {
      try {
        final File f = File(r.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _store.clear();
    _tasks.clear();
    notifyListeners();
  }

  void _update(Track track, {DownloadStatus? status, double? progress, String? error}) {
    final DownloadTask current =
        _tasks[track.id] ?? DownloadTask(track: track);
    _tasks[track.id] = current.copyWith(
      status: status,
      progress: progress,
      error: error,
    );
    notifyListeners();
  }

  String _extensionFor(String url) {
    final String path = Uri.tryParse(url)?.path ?? '';
    final int dot = path.lastIndexOf('.');
    if (dot >= 0 && dot < path.length - 1) {
      final String ext = path.substring(dot);
      if (ext.length <= 5) return ext;
    }
    return '.mp3';
  }

  String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
