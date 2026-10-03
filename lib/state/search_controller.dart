import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/debouncer.dart';
import '../data/music_repository.dart';
import '../domain/models/search_result.dart';

enum SearchStatus { idle, loading, loaded, error }

/// Debounced, paginating, provider-aggregating search (spec §5/§38).
class SearchController extends ChangeNotifier {
  SearchController({required MusicRepository repository})
      : _repository = repository;

  final MusicRepository _repository;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 320));

  SearchStatus status = SearchStatus.idle;
  SearchResult result = SearchResult.empty;
  Object? error;
  String query = '';
  bool loadingMore = false;
  int _offset = 0;
  int _generation = 0;

  bool get hasMore => result.tracks.length >= 18;

  /// Debounced entry point for as-you-type search.
  void onQueryChanged(String value) {
    query = value;
    if (value.trim().isEmpty) {
      status = SearchStatus.idle;
      result = SearchResult.empty;
      notifyListeners();
      _debouncer.cancel();
      return;
    }
    _debouncer.run(() => _run(value.trim(), reset: true));
  }

  Future<void> submit(String value) async {
    query = value;
    _debouncer.cancel();
    await _run(value.trim(), reset: true);
  }

  Future<void> _run(String q, {required bool reset}) async {
    if (q.isEmpty) return;
    final int gen = ++_generation;
    status = SearchStatus.loading;
    error = null;
    if (reset) {
      _offset = 0;
      result = SearchResult.empty;
    }
    notifyListeners();
    try {
      final SearchResult r = await _repository.search(q, offset: 0, limit: 20);
      if (gen != _generation) return; // a newer search superseded this one
      result = r;
      _offset = r.tracks.length;
      status = SearchStatus.loaded;
    } catch (e) {
      if (gen != _generation) return;
      error = e;
      status = SearchStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore || query.trim().isEmpty) return;
    loadingMore = true;
    notifyListeners();
    try {
      final SearchResult more =
          await _repository.search(query.trim(), offset: _offset, limit: 20);
      result = result.merge(more);
      _offset += more.tracks.length;
    } catch (e) {
      error = e;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  String errorMessage() {
    final Object? e = error;
    return e == null ? 'Something went wrong.' : toAppException(e).message;
  }

  void clear() {
    _debouncer.cancel();
    query = '';
    result = SearchResult.empty;
    status = SearchStatus.idle;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
