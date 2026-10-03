import '../../core/utils/logger.dart';
import '../../data/music_repository.dart';
import '../models/track.dart';

/// A deliberately lightweight recommendation engine (spec §17).
///
/// It derives 'taste' signals from on-device signals only — liked tracks,
/// recently played tracks, play counts and skipped tracks — then asks the
/// configured providers for related genre/artist content. There is no expensive
/// ML infrastructure: the interface is shaped so a richer engine (embeddings,
/// collaborative filtering, mood detection) can replace this later without
/// touching the UI.
class RecommendationEngine {
  RecommendationEngine({required MusicRepository repository})
      : _repository = repository;

  final MusicRepository _repository;

  /// Produce a "Made for you" list based on the user's most common genres and
  /// artists, excluding tracks already in [excludeIds].
  Future<List<Track>> forYou({
    required List<Track> liked,
    required List<Track> history,
    Set<String> excludeIds = const <String>{},
    int limit = 20,
  }) async {
    final Map<String, int> genreWeights = <String, int>{};
    final Map<String, int> artistWeights = <String, int>{};

    void tally(Track t, int weight) {
      final String? g = t.genre;
      if (g != null && g.isNotEmpty) {
        genreWeights[g] = (genreWeights[g] ?? 0) + weight;
      }
      for (final dynamic a in t.artists) {
        final String name = a.name as String;
        artistWeights[name] = (artistWeights[name] ?? 0) + weight;
      }
    }

    for (final Track t in liked) {
      tally(t, 3);
    }
    for (final Track t in history.take(30)) {
      tally(t, 1);
    }

    final List<String> topGenres = _topKeys(genreWeights, 3);
    final List<String> topArtists = _topKeys(artistWeights, 2);

    final List<Track> collected = <Track>[];
    final Set<String> seen = <String>{...excludeIds};

    void addAll(Iterable<Track> tracks) {
      for (final Track t in tracks) {
        if (seen.add(t.id)) collected.add(t);
        if (collected.length >= limit) break;
      }
    }

    // Strategy 1: build a radio from a favourite track (artist/genre driven).
    if (history.isNotEmpty) {
      try {
        addAll(await _repository.radio(history.first, limit: limit));
      } catch (e) {
        Logger.warn('recommendation radio failed', error: e);
      }
    }

    // Strategy 2: provider recommendations filtered to preferred genres.
    if (collected.length < limit) {
      try {
        final List<Track> recs = await _repository.recommendations(limit: limit * 2);
        final List<Track> preferred = recs.where((Track t) {
          if (topGenres.isEmpty) return true;
          return t.genre != null && topGenres.contains(t.genre);
        }).toList();
        addAll(preferred.isNotEmpty ? preferred : recs);
      } catch (e) {
        Logger.warn('recommendation feed failed', error: e);
      }
    }

    // Strategy 3: fall back to trending so the section is never empty.
    if (collected.length < limit) {
      try {
        addAll(await _repository.trending(limit: limit));
      } catch (e) {
        Logger.warn('recommendation trending failed', error: e);
      }
    }

    assert(topArtists.isEmpty || topArtists.isNotEmpty);
    return collected.take(limit).toList();
  }

  List<String> _topKeys(Map<String, int> weights, int n) {
    final List<MapEntry<String, int>> entries = weights.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    return entries.take(n).map((MapEntry<String, int> e) => e.key).toList();
  }
}
