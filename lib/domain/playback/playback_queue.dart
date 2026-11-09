import 'dart:math';

import '../models/track.dart';

/// Repeat behaviour for the queue.
enum RepeatMode { off, all, one }

/// Pure-Dart playback queue. Contains no platform dependencies so it is fully
/// unit-testable (spec §8/§40).
///
/// Holds the tracks, the current index, shuffle order and repeat mode, and
/// computes `next`/`previous` according to those. Shuffle is implemented via a
/// permutation so "previous" stays consistent and un-shuffling restores the
/// original order.
class PlaybackQueue {
  final List<Track> _tracks = <Track>[];
  List<int> _shuffleOrder = <int>[];
  int _shufflePos = 0;
  int _currentIndex = -1;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;
  final Random _random;

  PlaybackQueue({Random? random}) : _random = random ?? Random();

  List<Track> get tracks => List<Track>.unmodifiable(_tracks);
  int get length => _tracks.length;
  bool get isEmpty => _tracks.isEmpty;
  int get currentIndex => _currentIndex;

  Track? get current =>
      (_currentIndex >= 0 && _currentIndex < _tracks.length) ? _tracks[_currentIndex] : null;

  bool get hasNext {
    if (_tracks.isEmpty) return false;
    if (repeat == RepeatMode.all) return true;
    if (shuffle) return _shufflePos < _shuffleOrder.length - 1;
    return _currentIndex < _tracks.length - 1;
  }

  bool get hasPrevious {
    if (_tracks.isEmpty) return false;
    if (shuffle) return _shufflePos > 0 || repeat == RepeatMode.all;
    return _currentIndex > 0 || repeat == RepeatMode.all;
  }

  Track? peekNext() {
    if (_tracks.isEmpty) return null;
    if (shuffle) {
      if (_shufflePos < _shuffleOrder.length - 1) {
        return _tracks[_shuffleOrder[_shufflePos + 1]];
      }
      return repeat == RepeatMode.all ? _tracks[_shuffleOrder.first] : null;
    }
    if (_currentIndex < _tracks.length - 1) return _tracks[_currentIndex + 1];
    return repeat == RepeatMode.all ? _tracks.first : null;
  }

  static final RegExp _variantRegex = RegExp(
    r'\b(remix|acoustic|live|lofi|lo-fi|version|unplugged|reprise|instrumental|cover|mix|edit|extended|deluxe|slowed|reverb|mashup)\b',
    caseSensitive: false,
  );

  static String _normalizeTitle(String s) {
    if (s.isEmpty) return '';
    String t = s.toLowerCase();
    t = t.replaceAllMapped(RegExp(r'[\(\[][^\)\]]*[\)\]]'), (Match m) {
      final String match = m.group(0) ?? '';
      return _variantRegex.hasMatch(match) ? match : '';
    });
    t = t.replaceAll(
      RegExp(r'\b(feat|ft|official|audio|video|soundtrack|hd|4k|lyrics|from the movie)\b', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp(r'[^\w\s]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isNotEmpty ? t : s.toLowerCase().trim();
  }

  static List<Track> _dedupe(List<Track> tracks) {
    final Set<String> seenIds = <String>{};
    final List<Track> out = <Track>[];
    for (final Track t in tracks) {
      final String cleanId = t.providerTrackId.isNotEmpty
          ? t.providerTrackId.toLowerCase().trim()
          : (t.id.contains(':') ? t.id.split(':').last : t.id).toLowerCase().trim();
      if (cleanId.isNotEmpty && !seenIds.add(cleanId)) continue;
      out.add(t);
    }
    return out.isNotEmpty ? out : tracks;
  }

  /// Replace the queue and start at [startIndex].
  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    final Track? selected = (startIndex >= 0 && startIndex < tracks.length)
        ? tracks[startIndex]
        : (tracks.isNotEmpty ? tracks.first : null);

    final List<Track> deduped = _dedupe(tracks);
    _tracks
      ..clear()
      ..addAll(deduped);

    if (selected != null) {
      final String selClean = selected.providerTrackId.isNotEmpty
          ? selected.providerTrackId.toLowerCase().trim()
          : (selected.id.contains(':') ? selected.id.split(':').last : selected.id).toLowerCase().trim();
      int found = _tracks.indexWhere((Track t) => t.id == selected.id);
      if (found < 0) {
        found = _tracks.indexWhere((Track t) {
          final String tClean = t.providerTrackId.isNotEmpty
              ? t.providerTrackId.toLowerCase().trim()
              : (t.id.contains(':') ? t.id.split(':').last : t.id).toLowerCase().trim();
          return tClean.isNotEmpty && tClean == selClean;
        });
      }
      _currentIndex = found >= 0 ? found : (startIndex < _tracks.length ? startIndex : 0);
    } else {
      _currentIndex = _tracks.isEmpty ? -1 : 0;
    }
    _rebuildShuffleOrder(keepCurrent: true);
  }

  /// Move to the next track. Returns the new current track, or null if the
  /// queue finished (repeat off at the end).
  Track? next() {
    if (_tracks.isEmpty) return null;
    if (repeat == RepeatMode.one && _currentIndex >= 0) {
      return _tracks[_currentIndex];
    }
    if (shuffle) {
      if (_shufflePos < _shuffleOrder.length - 1) {
        _shufflePos++;
        _currentIndex = _shuffleOrder[_shufflePos];
        return _tracks[_currentIndex];
      }
      if (repeat == RepeatMode.all) {
        _rebuildShuffleOrder(keepCurrent: false);
        _shufflePos = 0;
        _currentIndex = _shuffleOrder.first;
        return _tracks[_currentIndex];
      }
      return null;
    }
    if (_currentIndex < _tracks.length - 1) {
      _currentIndex++;
      return _tracks[_currentIndex];
    }
    if (repeat == RepeatMode.all) {
      _currentIndex = 0;
      return _tracks[_currentIndex];
    }
    return null;
  }

  Track? previous() {
    if (_tracks.isEmpty) return null;
    if (shuffle) {
      if (_shufflePos > 0) {
        _shufflePos--;
        _currentIndex = _shuffleOrder[_shufflePos];
        return _tracks[_currentIndex];
      }
      if (repeat == RepeatMode.all) {
        _shufflePos = _shuffleOrder.length - 1;
        _currentIndex = _shuffleOrder[_shufflePos];
        return _tracks[_currentIndex];
      }
      return _tracks[_currentIndex];
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      return _tracks[_currentIndex];
    }
    if (repeat == RepeatMode.all) {
      _currentIndex = _tracks.length - 1;
      return _tracks[currentIndex];
    }
    return _tracks[_currentIndex];
  }

  /// Jump to an explicit queue index.
  Track? jumpTo(int index) {
    if (index < 0 || index >= _tracks.length) return null;
    _currentIndex = index;
    final int pos = _shuffleOrder.indexOf(index);
    if (pos >= 0) _shufflePos = pos;
    return _tracks[index];
  }

  void append(Track track) {
    final String norm = _normalizeTitle(track.title);
    final bool duplicate = _tracks.any((Track e) =>
        e.id == track.id ||
        (norm.isNotEmpty && _normalizeTitle(e.title) == norm));
    if (!duplicate) {
      _tracks.add(track);
      _rebuildShuffleOrder(keepCurrent: true);
    }
  }

  void appendAll(List<Track> tracks) {
    final Set<String> seenIds = _tracks.map((Track t) => t.id.toLowerCase().trim()).toSet();
    final Set<String> seenTitles = _tracks.map((Track t) => _normalizeTitle(t.title)).where((String s) => s.isNotEmpty).toSet();

    for (final Track t in tracks) {
      final String cleanId = t.id.toLowerCase().trim();
      final String normTitle = _normalizeTitle(t.title);
      if (seenIds.add(cleanId) && (normTitle.isEmpty || seenTitles.add(normTitle))) {
        _tracks.add(t);
      }
    }
    _rebuildShuffleOrder(keepCurrent: true);
  }

  /// Insert right after the current track ("play next").
  void playNext(Track track) {
    final String norm = _normalizeTitle(track.title);
    if (_currentIndex >= 0 && _currentIndex < _tracks.length) {
      if (_tracks[_currentIndex].id == track.id ||
          (norm.isNotEmpty && _normalizeTitle(_tracks[_currentIndex].title) == norm)) {
        return;
      }
    }

    final int existingIdx = _tracks.indexWhere((Track t) =>
        t.id == track.id ||
        (norm.isNotEmpty && _normalizeTitle(t.title) == norm));
    if (existingIdx > _currentIndex) {
      _tracks.removeAt(existingIdx);
    }

    if (_tracks.isEmpty) {
      _tracks.add(track);
      _currentIndex = 0;
    } else {
      _tracks.insert(_currentIndex + 1, track);
    }
    _rebuildShuffleOrder(keepCurrent: true);
  }

  bool removeAt(int index) {
    if (index < 0 || index >= _tracks.length) return false;
    final bool removingCurrent = index == _currentIndex;
    _tracks.removeAt(index);
    if (_tracks.isEmpty) {
      _currentIndex = -1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (removingCurrent) {
      _currentIndex = _currentIndex.clamp(0, _tracks.length - 1);
    }
    _rebuildShuffleOrder(keepCurrent: true);
    return removingCurrent;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tracks.length) return;
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final Track currentTrack = current ?? _tracks.first;
    final Track moved = _tracks.removeAt(oldIndex);
    _tracks.insert(target.clamp(0, _tracks.length), moved);
    _currentIndex = _tracks.indexWhere((Track t) => t.id == currentTrack.id);
    _rebuildShuffleOrder(keepCurrent: true);
  }

  void clear() {
    _tracks.clear();
    _shuffleOrder = <int>[];
    _shufflePos = 0;
    _currentIndex = -1;
  }

  void setShuffle(bool value) {
    if (shuffle == value) return;
    shuffle = value;
    _rebuildShuffleOrder(keepCurrent: true);
  }

  RepeatMode cycleRepeat() {
    switch (repeat) {
      case RepeatMode.off:
        repeat = RepeatMode.all;
        break;
      case RepeatMode.all:
        repeat = RepeatMode.one;
        break;
      case RepeatMode.one:
        repeat = RepeatMode.off;
        break;
    }
    return repeat;
  }

  void _rebuildShuffleOrder({required bool keepCurrent}) {
    final int? currentTrackIndex =
        (_currentIndex >= 0 && _currentIndex < _tracks.length) ? _currentIndex : null;
    final List<int> order = List<int>.generate(_tracks.length, (int i) => i);
    order.shuffle(_random);
    if (keepCurrent && currentTrackIndex != null) {
      // Ensure the current track sits at the start of the shuffled run.
      order.remove(currentTrackIndex);
      order.insert(0, currentTrackIndex);
    }
    _shuffleOrder = order;
    _shufflePos = 0;
  }
}
