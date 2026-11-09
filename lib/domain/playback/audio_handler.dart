import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';


import '../../core/utils/logger.dart';
import '../models/stream_source.dart';
import '../models/track.dart';
import 'playback_queue.dart';

/// Resolves a playable source for a track (delegates to the repository, which
/// routes to the owning provider). Kept as a function type so the handler has
/// no compile-time dependency on data-layer classes.
typedef StreamResolver = Future<StreamSource> Function(Track track);

/// The single source of truth for playback.
///
/// Runs in the app's isolate (audio_service 0.18) and owns a [just_audio]
/// player. It drives the media notification, lock-screen and headset controls
/// via [BaseAudioHandler], and manages the queue by feeding one resolved stream
/// at a time — the most reliable pattern for a provider-backed catalogue.
///
/// Audio focus, call interruptions and "becoming noisy" (headphone unplug /
/// Bluetooth disconnect) are handled through [AudioSession] + just_audio's
/// built-in interruption handling (spec §36).
class EchoAudioHandler extends BaseAudioHandler with SeekHandler {
  EchoAudioHandler({required StreamResolver resolver}) : _resolver = resolver {
    _player = AudioPlayer();
    _init();
  }

  final StreamResolver _resolver;

  late final AudioPlayer _player;
  final PlaybackQueue queueModel = PlaybackQueue();

  final StreamController<void> _queueChanges = StreamController<void>.broadcast();

  /// Emits whenever the queue contents/order change (for the queue sheet).
  Stream<void> get queueChanges => _queueChanges.stream;

  /// Emits whenever the current track or its playback state changes.
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast();
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;
  Timer? _persistDebounce;
  AudioSession? _session;
  bool _advancing = false;
  int _loadGeneration = 0;
  Track? _activeTrack;
  /// True while resolving/loading the intended queue track (before just_audio
  /// reports loading/buffering). Keeps cover/title + spinner in sync with skips.
  bool _loadInFlight = false;

  /// The track currently loaded and playing in the audio player.
  Track? get activeTrack => _activeTrack;

  /// Optional hook so the app can record history when a track starts.
  void Function(Track track)? onTrackStarted;

  /// Optional hook when a track ends or is interrupted. Awaited before the
  /// handler advances, so it can extend the queue (e.g. autoplay radio).
  Future<void> Function(Track track, bool completed)? onTrackEnded;

  PlaybackSnapshot get snapshot {
    // Prefer the intended queue track so cover/title never lag behind audio skips.
    final Track? active = queueModel.current ?? _activeTrack;
    final Duration d = (_player.duration != null && _player.duration! > Duration.zero)
        ? _player.duration!
        : (active?.duration ?? Duration.zero);
    // Only force "loading" while resolving URL — once just_audio has a source,
    // trust the player (otherwise web play() can hang and freeze spinner + 0:00).
    final ProcessingState uiState = (_loadInFlight &&
            (_player.audioSource == null ||
                _player.processingState == ProcessingState.idle))
        ? ProcessingState.loading
        : _player.processingState;
    return PlaybackSnapshot(
      track: active,
      queueIndex: queueModel.currentIndex,
      playing: _player.playing,
      processingState: uiState,
      position: _player.position,
      duration: d,
      buffered: _player.bufferedPosition,
      repeatMode: queueModel.repeat,
      shuffleMode: queueModel.shuffle,
      hasNext: queueModel.hasNext,
      hasPrevious: queueModel.hasPrevious,
      volume: _player.volume,
    );
  }

  Future<void> _init() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());
      // Auto-pause on interruptions (calls, other apps) and on noisy routes
      // (headphone unplug / Bluetooth disconnect).
      _noisySub = _session!.becomingNoisyEventStream.listen((_) {
        pause();
      });
      _interruptionSub = _session!.interruptionEventStream.listen((AudioInterruptionEvent e) {
        if (e.begin) {
          pause();
        } else if (e.type == AudioInterruptionType.pause ||
            e.type == AudioInterruptionType.duck) {
          // Resume only for transient interruptions; ducking already handled.
          if (e.type == AudioInterruptionType.duck) return;
          play();
        }
      });
    } catch (e) {
      Logger.warn('AudioSession setup failed', error: e);
    }

    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    _positionSub = _player.positionStream.listen((_) => _emitSnapshot());
    _durationSub = _player.durationStream.listen((Duration? d) {
      _emitSnapshot();
      if (d != null) _pushQueueToService();
    });
    _bufferedSub = _player.bufferedPositionStream.listen((_) => _emitSnapshot());

    _broadcastState();
  }

  // ---------------------------------------------------------------------------
  // Public API (used by PlaybackController)
  // ---------------------------------------------------------------------------

  /// Replace the queue and start playing at [startIndex].
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0, Duration? position}) async {
    queueModel.setQueue(tracks, startIndex: startIndex);
    await _pushQueueToService();
    await _loadCurrent(position: position, autoplay: true);
  }

  Future<void> playTracksNow(List<Track> tracks, int index) =>
      setQueue(tracks, startIndex: index);

  /// Restore a persisted queue and position without autoplaying, so returning
  /// to the app doesn't surprise the user with sudden audio (spec §37).
  Future<void> setQueueRestored(List<Track> tracks, int index, Duration position) async {
    queueModel.setQueue(tracks, startIndex: index);
    await _pushQueueToService();
    await _loadCurrent(position: position, autoplay: false);
    _notifyQueueChanged();
  }

  Future<void> playNext(Track track) async {
    queueModel.playNext(track);
    await _pushQueueToService();
    _notifyQueueChanged();
    _schedulePersist();
  }

  Future<void> appendToQueue(List<Track> tracks) async {
    queueModel.appendAll(tracks);
    await _pushQueueToService();
    _notifyQueueChanged();
    _schedulePersist();
  }

  Future<void> jumpTo(int index) async {
    final Track? t = queueModel.jumpTo(index);
    if (t == null) return;
    await _loadCurrent(autoplay: true);
    _notifyQueueChanged();
    _schedulePersist();
  }

  Future<void> removeFromQueue(int index) async {
    final bool removingCurrent = queueModel.removeAt(index);
    await _pushQueueToService();
    _notifyQueueChanged();
    if (removingCurrent) {
      if (queueModel.isEmpty) {
        await _player.stop();
      } else {
        await _loadCurrent(autoplay: _player.playing);
      }
    }
    _schedulePersist();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    queueModel.reorder(oldIndex, newIndex);
    await _pushQueueToService();
    _notifyQueueChanged();
    _schedulePersist();
  }

  void setShuffle(bool value) {
    queueModel.setShuffle(value);
    _broadcastState();
    _notifyQueueChanged();
    _schedulePersist();
  }

  RepeatMode cycleRepeat() {
    final RepeatMode mode = queueModel.cycleRepeat();
    _broadcastState();
    _schedulePersist();
    return mode;
  }

  void setRepeatModeCompat(RepeatMode mode) {
    queueModel.repeat = mode;
    _broadcastState();
    _schedulePersist();
  }

  /// Preload/refresh the current stream (e.g. after a quality change).
  Future<void> reloadCurrent({bool autoplay = true}) =>
      _loadCurrent(autoplay: autoplay);

  // ---------------------------------------------------------------------------
  // Queue <-> MediaItem
  // ---------------------------------------------------------------------------
  Future<void> _pushQueueToService() async {
    final List<MediaItem> items = queueModel.tracks.map((Track t) {
      final Duration d = t.duration;
      return MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artistNames,
        album: t.album?.title ?? '',
        duration: d == Duration.zero ? null : d,
        artUri: _artUri(t.artworkUrl),
        extras: <String, dynamic>{'providerId': t.providerId},
      );
    }).toList();
    queue.add(items);
    final Track? current = queueModel.current;
    mediaItem.add(current == null ? null : _mediaItemFor(current));
  }

  Uri? _artUri(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return Uri.parse(url);
    // Local content:// art still renders in the notification.
    if (url.startsWith('content://') || url.startsWith('file://')) return Uri.parse(url);
    return null;
  }

  MediaItem _mediaItemFor(Track t) => MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artistNames,
        album: t.album?.title ?? '',
        duration: t.duration == Duration.zero ? null : t.duration,
        artUri: _artUri(t.artworkUrl),
        extras: <String, dynamic>{'providerId': t.providerId},
      );

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------
  Future<void> _loadCurrent({Duration? position, bool autoplay = true}) async {
    final int generation = ++_loadGeneration;
    final Track? track = queueModel.current;
    if (track == null) {
      _activeTrack = null;
      _loadInFlight = false;
      await _player.stop();
      mediaItem.add(null);
      _broadcastState();
      return;
    }
    try {
      // 1. Stop prior audio, then publish the NEW track immediately so cover/title
      //    match the queue (JioSaavn-style: UI updates first, then waits to play).
      await _player.stop();
      _activeTrack = track;
      _loadInFlight = true;
      mediaItem.add(_mediaItemFor(track));
      _broadcastState(processingState: AudioProcessingState.loading);

      // 2. Resolve stream URL (UI stays on loading spinner for this track)
      final StreamSource source = await _resolver(track);
      if (generation != _loadGeneration) {
        // A newer track was requested while resolving this one — cancel stale load.
        return;
      }
      final String rawUrl = source.url;
      if (rawUrl.isEmpty) {
        throw Exception('No playable stream URL for "${track.title}"');
      }
      final Uri uri;
      if (rawUrl.startsWith('file://')) {
        uri = Uri.parse(rawUrl);
      } else if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        uri = Uri.parse(rawUrl);
      } else if (!kIsWeb && File(rawUrl).existsSync()) {
        uri = Uri.file(rawUrl);
      } else {
        uri = Uri.parse(rawUrl);
      }

      // 3. Activate audio session for mobile foreground playback & audio focus
      try {
        if (_session != null) {
          await _session!.setActive(true);
        }
      } catch (_) {}

      // 4. Load the new AudioSource into just_audio
      final Duration startAt = position ?? Duration.zero;
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          headers: source.headers.isEmpty ? null : source.headers,
          tag: _mediaItemFor(track),
        ),
        initialPosition: startAt,
        preload: true,
      );
      if (generation != _loadGeneration) return;

      // Clear loading BEFORE play — on web await play() may never complete while
      // audio is already audible (spinner + timer stuck at 0:00).
      _loadInFlight = false;
      _activeTrack = track;
      _broadcastState();

      // 5. Natural play after source is ready
      if (autoplay) {
        unawaited(_player.play().then((_) {
          if (generation != _loadGeneration) return;
          if (!_player.playing) {
            unawaited(_player.play());
          }
        }));
      }

      onTrackStarted?.call(track);
      await _pushQueueToService();
      _broadcastState();
      _schedulePersist();
    } catch (e) {
      if (generation != _loadGeneration) return;
      Logger.warn('Playback load failed for track ${track.id}', error: e);
      _loadInFlight = false;
      _activeTrack = null;
      _broadcastState(
        processingState: AudioProcessingState.error,
        errorMessage: 'Playback error: Unable to stream "${track.title}". Please retry or check network.',
      );
    }
  }

  void _onPlayerState(PlayerState state) {
    // Safety net: if audio is actually moving, never leave UI stuck on loading.
    if (_loadInFlight &&
        (state.playing ||
            state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.completed)) {
      _loadInFlight = false;
    }
    if (state.processingState == ProcessingState.completed) {
      _handleCompletion();
    }
    _broadcastState();
  }

  Future<void> _handleCompletion() async {
    if (_advancing) return;
    _advancing = true;
    final Track? finished = _activeTrack ?? queueModel.current;
    try {
      if (queueModel.repeat == RepeatMode.one) {
        // Repeat single track: seek to 0 and replay
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      Track? next = queueModel.next();
      if (next == null && onTrackEnded != null) {
        // Queue reached the end: await radio autoplay to extend queue if enabled
        await onTrackEnded!(finished ?? _empty, true);
        next = queueModel.next();
      } else if (onTrackEnded != null) {
        // Asynchronously update history without interrupting background playback
        unawaited(onTrackEnded!(finished ?? _empty, true));
      }

      if (next == null) {
        _activeTrack = null;
        await _player.stop();
        _broadcastState(processingState: AudioProcessingState.completed);
      } else {
        await _loadCurrent(position: Duration.zero, autoplay: true);
      }
    } finally {
      _advancing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // audio_service overrides
  // ---------------------------------------------------------------------------
  @override
  Future<void> play() async {
    final Track? t = queueModel.current;
    if (t == null) return;
    final bool needsLoad = _player.audioSource == null ||
        _player.processingState == ProcessingState.idle ||
        _player.processingState == ProcessingState.completed ||
        _activeTrack == null ||
        _activeTrack?.id != t.id;
    if (needsLoad) {
      await _loadCurrent(autoplay: true);
    } else {
      await _player.play();
    }
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
    await onTrackEnded?.call(_activeTrack ?? queueModel.current ?? _empty, false);
    _schedulePersist();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    final Track? next = queueModel.next();
    if (next == null) {
      await _player.pause();
      return;
    }
    await _loadCurrent(position: Duration.zero, autoplay: true);
    _notifyQueueChanged();
  }

  @override
  Future<void> skipToPrevious() async {
    // Standard behaviour: restart if we're partway through the current track.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final Track? prev = queueModel.previous();
    if (prev == null) return;
    await _loadCurrent(position: Duration.zero, autoplay: true);
    _notifyQueueChanged();
  }

  @override
  Future<void> skipToQueueItem(int index) => jumpTo(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        queueModel.repeat = RepeatMode.off;
        break;
      case AudioServiceRepeatMode.all:
        queueModel.repeat = RepeatMode.all;
        break;
      case AudioServiceRepeatMode.one:
        queueModel.repeat = RepeatMode.one;
        break;
      case AudioServiceRepeatMode.group:
        queueModel.repeat = RepeatMode.all;
        break;
    }
    _broadcastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    queueModel.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    _loadGeneration++;
    _activeTrack = null;
    _loadInFlight = false;
    await _player.stop();
    queueModel.clear();
    mediaItem.add(null);
    queue.add(const <MediaItem>[]);
    playbackState.add(
      PlaybackState(
        controls: const <MediaControl>[],
        systemActions: const <MediaAction>{},
        androidCompactActionIndices: const <int>[],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
    await super.stop();
    _notifyQueueChanged();
    _emitSnapshot();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  @override
  Future<void> onTaskRemoved() async {
    await _persistNow();
    await stop();
  }

  // ---------------------------------------------------------------------------
  // State broadcasting
  // ---------------------------------------------------------------------------
  void _broadcastState({
    AudioProcessingState? processingState,
    String? errorMessage,
  }) {
    final AudioProcessingState stateForService =
        processingState ?? _mapProcessingState(_player.processingState);
    final bool playing = _player.playing;

    final List<MediaControl> controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: stateForService,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueModel.currentIndex >= 0 ? queueModel.currentIndex : null,
        errorMessage: errorMessage,
        repeatMode: _mapRepeatForService(),
        shuffleMode: queueModel.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
    _emitSnapshot();
  }

  AudioProcessingState _mapProcessingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _mapRepeatForService() {
    switch (queueModel.repeat) {
      case RepeatMode.off:
        return AudioServiceRepeatMode.none;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  void _emitSnapshot() {
    if (_snapshots.isClosed) return;
    _snapshots.add(snapshot);
  }

  void _notifyQueueChanged() {
    if (!_queueChanges.isClosed) _queueChanges.add(null);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 3), _persistNow);
  }

  /// Persist callback set by the controller (avoids a queue-store dependency).
  Future<void> Function(List<Track> queue, int index, Duration position)? persist;

  Future<void> _persistNow() async {
    final Future<void> Function(List<Track>, int, Duration)? p = persist;
    if (p == null) return;
    try {
      await p(queueModel.tracks, queueModel.currentIndex, _player.position);
    } catch (_) {}
  }

  static final Track _empty = Track(
    id: 'empty',
    providerId: 'none',
    providerTrackId: 'none',
    title: '',
  );

  /// Tears down players, subscriptions and streams. Called by the app scope.
  Future<void> disposeHandler() async {
    await _persistNow();
    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferedSub?.cancel();
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await _player.dispose();
    await _queueChanges.close();
    await _snapshots.close();
  }
}

/// Immutable snapshot of playback, pushed to the UI.
class PlaybackSnapshot {
  final Track? track;
  final int queueIndex;
  final bool playing;
  final ProcessingState processingState;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final RepeatMode repeatMode;
  final bool shuffleMode;
  final bool hasNext;
  final bool hasPrevious;
  final double volume;

  const PlaybackSnapshot({
    required this.track,
    required this.queueIndex,
    required this.playing,
    required this.processingState,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.repeatMode,
    required this.shuffleMode,
    required this.hasNext,
    required this.hasPrevious,
    required this.volume,
  });

  bool get isBuffering => processingState == ProcessingState.buffering ||
      processingState == ProcessingState.loading;

  bool get isPlaying => playing;
}
