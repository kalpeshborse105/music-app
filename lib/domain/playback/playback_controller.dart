import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../core/storage/library_store.dart';
import '../../core/storage/queue_store.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/logger.dart';
import '../../data/music_repository.dart';
import '../models/track.dart';
import 'audio_handler.dart';
import 'playback_queue.dart';

/// The UI-facing playback facade.
///
/// Wraps [EchoAudioHandler], resolves streams through [MusicRepository],
/// records privacy-first listening history, autoplays radio when a queue
/// finishes, and persists the queue for restore-on-launch. Exposes a
/// [ChangeNotifier] surface so widgets can rebuild without touching the handler.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required EchoAudioHandler handler,
    required MusicRepository repository,
    required LibraryStore library,
    required QueueStore queueStore,
    required SettingsStore settings,
  })  : _handler = handler,
        _repository = repository,
        _library = library,
        _queueStore = queueStore,
        _settings = settings {
    _init();
  }

  final EchoAudioHandler _handler;
  final MusicRepository _repository;
  final LibraryStore _library;
  final QueueStore _queueStore;
  final SettingsStore _settings;

  StreamSubscription<PlaybackSnapshot>? _snapSub;
  StreamSubscription<void>? _queueSub;
  PlaybackSnapshot _snapshot = const PlaybackSnapshot(
    track: null,
    queueIndex: -1,
    playing: false,
    processingState: ja.ProcessingState.idle,
    position: Duration.zero,
    duration: Duration.zero,
    buffered: Duration.zero,
    repeatMode: RepeatMode.off,
    shuffleMode: false,
    hasNext: false,
    hasPrevious: false,
    volume: 1,
  );

  PlaybackSnapshot get snapshot => _snapshot;
  Track? get currentTrack => _snapshot.track;
  bool get isPlaying => _snapshot.playing;
  bool get hasTrack => _snapshot.track != null;
  PlaybackQueue get queue => _handler.queueModel;
  Stream<void> get queueChanges => _handler.queueChanges;
  String? lastErrorMessage;

  bool _isMiniPlayerDismissed = false;
  bool get isMiniPlayerDismissed => _isMiniPlayerDismissed;

  Future<void> dismissMiniPlayer() async {
    _isMiniPlayerDismissed = true;
    await stop();
    notifyListeners();
  }

  /// Fresh app launch: clear bottom player + persisted queue.
  Future<void> resetForFreshLaunch() async {
    _isMiniPlayerDismissed = true;
    try {
      await stop();
    } catch (_) {}
    try {
      await _queueStore.clear();
    } catch (_) {}
    notifyListeners();
  }

  void showMiniPlayer() {
    _isMiniPlayerDismissed = false;
    notifyListeners();
  }

  void _init() {
    _snapSub = _handler.snapshots.listen((PlaybackSnapshot s) {
      if (s.track?.id != _snapshot.track?.id && s.track != null) {
        _isMiniPlayerDismissed = false;
      }
      _snapshot = s;
      notifyListeners();
    });
    _queueSub = _handler.queueChanges.listen((_) => notifyListeners());

    // Wire handler callbacks.
    _handler.persist = (List<Track> tracks, int index, Duration position) async {
      await _queueStore.save(queue: tracks, index: index, position: position);
    };
    _handler.onTrackStarted = _recordStart;
    _handler.onTrackEnded = _handleEnded;
  }

  void _recordStart(Track track) {
    if (track.id == 'empty') return;
    if (_settings.saveHistory) {
      _library.recordPlay(track).catchError((Object e) {
        Logger.warn('history write failed', error: e);
      });
    }
  }

  bool _isExtendingRadio = false;

  Future<void> _handleEnded(Track track, bool completed) async {
    if (track.id == 'empty' || track.providerId == 'radio') return;
    if (_stopAtTrackEnd && completed) {
      await pause();
      cancelSleepTimer();
      return;
    }
    if (completed) {
      final double completion = _completionRatio();
      if (_settings.saveHistory) {
        await _library.updateCompletion(track.id, completion).catchError((Object e) {
          Logger.warn('history completion write failed', error: e);
        });
      }
      // Autoplay radio when the queue is exhausted.
      if (_settings.autoplayRadio &&
          !_handler.queueModel.hasNext &&
          !_handler.queueModel.isEmpty &&
          !_isExtendingRadio) {
        await _maybeExtendWithRadio(track);
      }
    }
  }

  double _completionRatio() {
    final Duration total = _snapshot.duration;
    if (total.inMilliseconds <= 0) return 0;
    return (_snapshot.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> _maybeExtendWithRadio(Track seed) async {
    if (_isExtendingRadio) return;
    _isExtendingRadio = true;
    try {
      final List<Track> related = await _repository.radio(seed, limit: 15);
      if (related.isEmpty) return;
      final Set<String> existingIds = _handler.queueModel.tracks.map((Track t) => t.id).toSet();
      existingIds.add(seed.id);
      final List<Track> fresh = related.where((Track t) => !existingIds.contains(t.id)).toList();
      if (fresh.isNotEmpty) {
        await _handler.appendToQueue(fresh);
      }
    } catch (e) {
      Logger.warn('autoplay radio failed', error: e);
    } finally {
      _isExtendingRadio = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback intents
  // ---------------------------------------------------------------------------
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _isMiniPlayerDismissed = false;
    final List<Track> list = queue ?? <Track>[track];
    int index = list.indexWhere((Track t) => t.id == track.id);
    if (index < 0) {
      list.insert(0, track);
      index = 0;
    }
    await _handler.setQueue(list, startIndex: index);
  }

  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) async {
    _isMiniPlayerDismissed = false;
    if (tracks.isEmpty) return;
    await _handler.setQueue(tracks, startIndex: startIndex);
  }

  Future<void> playNext(Track track) {
    _isMiniPlayerDismissed = false;
    return _handler.playNext(track);
  }

  Future<void> addToQueue(Track track) => _handler.appendToQueue(<Track>[track]);

  Future<void> addAllToQueue(List<Track> tracks) => _handler.appendToQueue(tracks);

  Future<void> play() {
    _isMiniPlayerDismissed = false;
    return _handler.play();
  }
  Future<void> pause() => _handler.pause();

  Future<void> togglePlayPause() async {
    if (_snapshot.track == null) return;
    if (_snapshot.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  // ---------------------------------------------------------------------------
  // Sleep Timer (Spotify & JioSaavn Standard Feature)
  // ---------------------------------------------------------------------------
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _stopAtTrackEnd = false;

  bool get hasActiveSleepTimer => _sleepTimer != null || _stopAtTrackEnd;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;
  bool get stopAtTrackEnd => _stopAtTrackEnd;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final Duration diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void setSleepTimer(Duration? duration, {bool endOfTrack = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _stopAtTrackEnd = endOfTrack;

    if (endOfTrack) {
      notifyListeners();
      return;
    }

    if (duration != null && duration > Duration.zero) {
      _sleepTimerEndTime = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        pause();
        cancelSleepTimer();
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _stopAtTrackEnd = false;
    notifyListeners();
  }

  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> jumpTo(int index) => _handler.jumpTo(index);
  Future<void> removeFromQueue(int index) => _handler.removeFromQueue(index);
  Future<void> reorderQueue(int oldIndex, int newIndex) =>
      _handler.reorderQueue(oldIndex, newIndex);

  void toggleShuffle() => _handler.setShuffle(!_handler.queueModel.shuffle);
  RepeatMode cycleRepeat() => _handler.cycleRepeat();

  Future<void> stop() => _handler.stop();

  /// Re-resolve the current stream (used after a quality change).
  Future<void> reloadForQuality() => _handler.reloadCurrent(autoplay: _snapshot.playing);

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------
  /// Restore the last queue + position without autoplaying (spec §37).
  Future<bool> restore() async {
    final ({List<Track> queue, int index, Duration position})? saved =
        _queueStore.restore();
    if (saved == null || saved.queue.isEmpty) return false;
    try {
      await _handler.setQueueRestored(saved.queue, saved.index, saved.position);
      return true;
    } catch (e) {
      Logger.warn('restore failed', error: e);
      return false;
    }
  }

  @override
  void dispose() {
    _snapSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }
}
