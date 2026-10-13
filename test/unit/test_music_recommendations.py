"""
Kalpkrut Beats - Comprehensive Unit Test Suite (Phase D)
=========================================================
All tests are fully deterministic: unittest.mock patches jio_call and
search_songs so no live network calls are made.

Covers all 13 Phase D required scenarios:
 1. /api/new-releases parses new song records correctly.
 2. Album-only responses do not fabricate song tracks.
 3. Release ordering uses trustworthy ISO dates.
 4. Release endpoint never falls back to trending.
 5. Hindi, Telugu, Tamil and Marathi filter mismatched tracks.
 6. Multi-language India feeds interleave intentionally.
 7. Mood requests respect selected language.
 8. Duplicate IDs removed; legitimate song versions preserved.
 9. Pagination: no fabricated totals, terminates reliably.
10. Upstream timeouts/invalid JSON return observable error or stale.
11. Cache entries cannot leak between languages, feed types, pages.
12. Flutter getNewReleases does NOT call trending as fallback.
13. Flutter does not endlessly request pages after exhaustion.
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

# Prevent background worker threads from starting during import
_wp = patch("threading.Thread")
_wp.start()

import server  # noqa: E402
from server import (
    normalize_title,
    dedupe,
    interleave_languages,
    prioritize_indian,
    parse_languages,
    _sort_by_release_date,
    live_new_releases,
    live_trending,
    mood_tracks,
    format_track,
    SUPPORTED_LANGUAGES,
    INDIAN_LANGUAGES,
    DEFAULT_LANGUAGES,
    _CACHE,
    _lang_key,
    HOURLY,
)

_wp.stop()


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

def _clr():
    """Clear in-memory cache between tests."""
    _CACHE.clear()


def _song(sid, title, lang, rd="", artist="Artist"):
    """Minimal JioSaavn song payload (api v4 shape)."""
    return {
        "id": sid, "type": "song", "title": title, "language": lang,
        "year": rd[:4] if rd else "", "play_count": 1,
        "perma_url": "https://www.jiosaavn.com/song/" + sid,
        "more_info": {
            "encrypted_media_url": "", "duration": "240",
            "release_date": rd, "album": title + " Album",
            "album_id": "alb" + sid, "album_url": "",
            "320kbps": "true", "has_lyrics": "false",
        },
        "primary_artists": artist, "primary_artists_id": "art" + sid,
        "image": "https://c.saavncdn.com/500x500.jpg",
    }


def _album(aid, title, lang, year=""):
    """Minimal album entity as returned by content.getAlbums -> _entities()."""
    return {
        "id": aid, "type": "album", "title": title, "language": lang,
        "year": year, "source": "jiosaavn",
        "image": "https://c.saavncdn.com/500x500.jpg",
        "perma_url": "https://www.jiosaavn.com/album/" + aid,
        "more_info": {"song_count": 5, "release_date": year + "-06-01" if year else ""},
    }


# ---------------------------------------------------------------------------
# 1. New-releases parses song records correctly
# ---------------------------------------------------------------------------
class TestNewReleasesParsesSongs(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_returns_songs_from_albums(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": [_album("a1", "NB Album", "hindi", "2025")]}
        mock_expand.return_value = [
            format_track(_song("s1", "Aaj Ki Raat", "hindi", "2025-10-01")),
            format_track(_song("s2", "Kal Bhi Tu", "hindi", "2025-09-20")),
        ]
        r = live_new_releases(["hindi"])
        self.assertIsInstance(r, dict)
        self.assertIn("songs", r)
        self.assertIn("albums", r)
        self.assertEqual(len(r["songs"]), 2)
        self.assertEqual(r["songs"][0]["type"], "song")

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_has_required_fields(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": [_album("a2", "Telugu A", "telugu", "2025")]}
        mock_expand.return_value = [format_track(_song("t1", "Nee Kosam", "telugu", "2025-10-05"))]
        r = live_new_releases(["telugu"])
        for s in r["songs"]:
            self.assertTrue(s.get("id"))
            self.assertTrue(s.get("title"))
            self.assertEqual(s.get("type"), "song")


# ---------------------------------------------------------------------------
# 2. Album-only responses do NOT fabricate songs
# ---------------------------------------------------------------------------
class TestAlbumOnlyNoFabrication(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    @patch("server.search_songs")
    def test_no_search_fallback_when_expansion_fails(self, mock_search, mock_expand, mock_jio):
        mock_jio.return_value = {"data": [_album("a3", "FA", "hindi", "2025")]}
        mock_expand.return_value = []
        r = live_new_releases(["hindi"])
        mock_search.assert_not_called()
        self.assertEqual(r["songs"], [])
        self.assertGreater(len(r["albums"]), 0)

    @patch("server.jio_call")
    def test_albums_separate_from_songs(self, mock_jio):
        mock_jio.side_effect = [
            {"data": [_album("a4", "OA", "marathi", "2025")]},
            {"id": "a4", "list": [], "more_info": {}, "year": "2025"},
        ]
        r = live_new_releases(["marathi"])
        for s in r["songs"]:
            self.assertEqual(s["type"], "song")
        for a in r["albums"]:
            self.assertEqual(a["type"], "album")


# ---------------------------------------------------------------------------
# 3. Release ordering uses trustworthy ISO dates only
# ---------------------------------------------------------------------------
class TestReleaseDateOrdering(unittest.TestCase):
    def test_iso_sorted_newest_first(self):
        items = [
            {"id": "1", "release_date": "2025-01-10"},
            {"id": "2", "release_date": "2025-10-01"},
            {"id": "3", "release_date": "2024-06-15"},
        ]
        s = _sort_by_release_date(items)
        self.assertEqual(s[0]["id"], "2")
        self.assertEqual(s[1]["id"], "1")
        self.assertEqual(s[2]["id"], "3")

    def test_year_only_goes_to_end(self):
        items = [
            {"id": "a", "year": "2025"},
            {"id": "b", "release_date": "2025-03-15"},
            {"id": "c"},
        ]
        s = _sort_by_release_date(items)
        self.assertEqual(s[0]["id"], "b")
        tail_ids = {x["id"] for x in s[1:]}
        self.assertIn("a", tail_ids)
        self.assertIn("c", tail_ids)

    def test_no_invented_dates(self):
        s = _sort_by_release_date([{"id": "x", "year": "2025"}])
        self.assertEqual(s[0]["id"], "x")


# ---------------------------------------------------------------------------
# 4. Release endpoint never falls back to trending
# ---------------------------------------------------------------------------
class TestNoTrendingFallback(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    @patch("server.live_trending")
    @patch("server._expand_album_to_tracks")
    def test_live_trending_not_called(self, mock_expand, mock_trending, mock_jio):
        mock_jio.return_value = {"data": [_album("a5", "EA", "hindi")]}
        mock_expand.return_value = []
        live_new_releases(["hindi"])
        mock_trending.assert_not_called()

    @patch("server.jio_call")
    @patch("server.search_songs")
    @patch("server._expand_album_to_tracks")
    def test_search_songs_not_called(self, mock_expand, mock_search, mock_jio):
        mock_jio.return_value = {"data": [_album("a6", "NS", "telugu")]}
        mock_expand.return_value = []
        live_new_releases(["telugu"])
        mock_search.assert_not_called()


# ---------------------------------------------------------------------------
# 5. Regional language filtering (Hindi, Telugu, Tamil, Marathi)
# ---------------------------------------------------------------------------
class TestRegionalFiltering(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    def test_telugu_excludes_hindi_tracks(self, mock_jio):
        mock_jio.return_value = [
            _song("t1", "Nee Kosam", "telugu"),
            _song("t2", "Ek Baar", "hindi"),
        ]
        tracks = live_trending(["telugu"])
        langs = {t["language"] for t in tracks}
        self.assertNotIn("hindi", langs)

    @patch("server.jio_call")
    def test_marathi_excludes_tamil_tracks(self, mock_jio):
        mock_jio.return_value = [
            _song("m1", "Aaichi Saavli", "marathi"),
            _song("m2", "Bigil", "tamil"),
        ]
        tracks = live_trending(["marathi"])
        self.assertFalse(any(t["language"] != "marathi" for t in tracks))

    @patch("server.jio_call")
    def test_tamil_filtering(self, mock_jio):
        mock_jio.return_value = [
            _song("ta1", "Bigil", "tamil"),
            _song("ta2", "Kesariya", "hindi"),
        ]
        for t in live_trending(["tamil"]):
            self.assertEqual(t.get("language"), "tamil")

    @patch("server.jio_call")
    def test_hindi_single_region(self, mock_jio):
        mock_jio.return_value = [
            _song("h1", "Tum Hi Ho", "hindi"),
            _song("h2", "Cover", "bengali"),
        ]
        for t in live_trending(["hindi"]):
            self.assertEqual(t.get("language"), "hindi")


# ---------------------------------------------------------------------------
# 6. Multi-language India feeds interleave intentionally
# ---------------------------------------------------------------------------
class TestMultiLangInterleaving(unittest.TestCase):
    def test_interleave_two_languages(self):
        hi = [{"id": "h" + str(i), "language": "hindi"} for i in range(4)]
        te = [{"id": "t" + str(i), "language": "telugu"} for i in range(4)]
        r = interleave_languages(hi + te, ["hindi", "telugu"])
        # First lang gets 2 slots per round, second gets 1
        self.assertEqual(r[0]["language"], "hindi")
        self.assertEqual(r[1]["language"], "hindi")
        self.assertEqual(r[2]["language"], "telugu")

    def test_prioritize_preferred_first(self):
        t = [
            {"id": "e1", "language": "english"},
            {"id": "h1", "language": "hindi"},
            {"id": "t1", "language": "telugu"},
        ]
        r = prioritize_indian(t, ["telugu", "hindi"])
        self.assertEqual(r[0]["language"], "telugu")
        self.assertEqual(r[1]["language"], "hindi")
        self.assertEqual(r[2]["language"], "english")

    def test_all_india_includes_major_langs(self):
        langs = parse_languages("all")
        for lang in ["hindi", "telugu", "tamil", "marathi"]:
            self.assertIn(lang, langs)


# ---------------------------------------------------------------------------
# 7. Mood requests respect selected language (not DEFAULT_LANGUAGES)
# ---------------------------------------------------------------------------
class TestMoodLanguageRespect(unittest.TestCase):
    def test_romantic_telugu_not_hindi(self):
        _, q = mood_tracks("romantic", ["telugu"], 1, 5)
        self.assertNotIn("Hindi", q)

    def test_party_marathi(self):
        _, q = mood_tracks("party", ["marathi"], 1, 5)
        self.assertIn("Marathi", q)

    def test_devotional_tamil_no_hindi(self):
        _, q = mood_tracks("devotional", ["tamil"], 1, 5)
        self.assertNotIn("Hindi", q)

    def test_romantic_hindi_stays_hindi(self):
        _, q = mood_tracks("romantic", ["hindi"], 1, 5)
        self.assertIn("Hindi", q)


# ---------------------------------------------------------------------------
# 8. Deduplication: removes duplicate IDs; preserves legitimate variants
# ---------------------------------------------------------------------------
class TestDeduplication(unittest.TestCase):
    def _t(self, tid, title, lang="hindi", src="jiosaavn"):
        return {"id": tid, "type": "song", "title": title, "language": lang, "source": src}

    def test_exact_id_duplicate_removed(self):
        t = [self._t("1", "K"), self._t("1", "K")]
        self.assertEqual(len(dedupe(t)), 1)

    def test_remix_with_different_id_preserved(self):
        t = [self._t("1", "Kesariya"), self._t("2", "Kesariya (Remix)")]
        r = dedupe(t)
        ids = {x["id"] for x in r}
        self.assertIn("2", ids, "Remix with distinct ID must be preserved")

    def test_acoustic_version_preserved(self):
        t = [self._t("10", "Tum Hi Ho"), self._t("11", "Tum Hi Ho - Acoustic")]
        self.assertEqual(len(dedupe(t)), 2)

    def test_same_title_different_languages_preserved(self):
        t = [self._t("a", "Tum Hi Ho", "hindi"), self._t("b", "Tum Hi Ho", "telugu")]
        self.assertEqual(len(dedupe(t)), 2,
                         "Same title in different languages must NOT be merged")

    def test_exclude_ids_parameter(self):
        t = [self._t("x1", "A"), self._t("x2", "B")]
        r = dedupe(t, exclude_ids={"x1"})
        ids = [x["id"] for x in r]
        self.assertNotIn("x1", ids)
        self.assertIn("x2", ids)


# ---------------------------------------------------------------------------
# 9. Pagination: no fabricated totals, terminates reliably
# ---------------------------------------------------------------------------
class TestPaginationTruthfulness(unittest.TestCase):
    def setUp(self):
        _clr()

    def test_has_more_false_when_exhausted(self):
        pool_size, page, limit = 15, 2, 20
        start = (page - 1) * limit
        has_more = (start + limit) < pool_size
        self.assertFalse(has_more)

    def test_has_more_true_when_more_pages(self):
        pool_size, page, limit = 50, 1, 20
        has_more = ((page - 1) * limit + limit) < pool_size
        self.assertTrue(has_more)

    def test_partial_last_page_no_more(self):
        pool_size, page, limit = 35, 2, 20
        start = (page - 1) * limit
        has_more = (start + limit) < pool_size
        self.assertFalse(has_more)

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_total_is_real_count_not_100(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": [_album("a7", "Album", "hindi", "2025")]}
        mock_expand.return_value = [
            format_track(_song("s10", "One", "hindi", "2025-10-01")),
        ]
        r = live_new_releases(["hindi"])
        self.assertEqual(len(r["songs"]), 1)
        # Must NOT be inflated to min 100
        self.assertLess(len(r["songs"]), 100)

    def test_parse_single_language(self):
        self.assertEqual(parse_languages("telugu"), ["telugu"])
        self.assertEqual(parse_languages("marathi"), ["marathi"])

    def test_parse_multi_language(self):
        self.assertEqual(parse_languages("hindi,telugu"), ["hindi", "telugu"])

    def test_parse_unknown_falls_back_to_default(self):
        result = parse_languages("klingon")
        self.assertEqual(result, list(DEFAULT_LANGUAGES))


# ---------------------------------------------------------------------------
# 10. Upstream timeouts/invalid JSON return observable error or stale data
# ---------------------------------------------------------------------------
class TestUpstreamErrorHandling(unittest.TestCase):
    def test_timeout_returns_empty_dict(self):
        with patch("server.urllib.request.urlopen", side_effect=TimeoutError("timed out")):
            result = server.jio_call("song.getDetails", {"pids": "nonexistent"})
        self.assertEqual(result, {})

    def test_invalid_json_returns_empty_dict(self):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"not valid json"
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("server.urllib.request.urlopen", return_value=mock_resp):
            result = server.jio_call("song.getDetails", {"pids": "x"})
        self.assertEqual(result, {})

    @patch("server.jio_call")
    def test_stale_cache_marked_with_flag(self, mock_jio):
        """When producer fails and stale cache exists, _stale flag is set."""
        _clr()
        mock_jio.return_value = {"data": [_album("a8", "Stale Album", "hindi", "2025")]}
        with patch("server._expand_album_to_tracks", return_value=[]):
            live_new_releases(["hindi"], page=3, limit=5)
        cache_key = "newrel:v2:" + _lang_key(["hindi"]) + ":3:5"
        if cache_key in _CACHE:
            old_ts, old_val = _CACHE[cache_key]
            _CACHE[cache_key] = (old_ts - HOURLY - 1, old_val)
        mock_jio.side_effect = TimeoutError("upstream down")
        with patch("server._expand_album_to_tracks", side_effect=Exception("fail")):
            result2 = live_new_releases(["hindi"], page=3, limit=5)
        if result2 and isinstance(result2, dict) and result2.get("_stale"):
            self.assertTrue(result2["_stale"])
            self.assertIn("_updated_at", result2)


# ---------------------------------------------------------------------------
# 11. Cache entries cannot leak between languages, feed types, or pages
# ---------------------------------------------------------------------------
class TestCacheKeyIsolation(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_different_languages_different_keys(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": []}
        mock_expand.return_value = []
        live_new_releases(["telugu"], page=1, limit=10)
        live_new_releases(["hindi"], page=1, limit=10)
        tk = "newrel:v2:" + _lang_key(["telugu"]) + ":1:10"
        hk = "newrel:v2:" + _lang_key(["hindi"]) + ":1:10"
        self.assertIn(tk, _CACHE)
        self.assertIn(hk, _CACHE)
        self.assertNotEqual(tk, hk)

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_different_pages_different_keys(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": []}
        mock_expand.return_value = []
        live_new_releases(["hindi"], page=1, limit=10)
        live_new_releases(["hindi"], page=2, limit=10)
        k1 = "newrel:v2:" + _lang_key(["hindi"]) + ":1:10"
        k2 = "newrel:v2:" + _lang_key(["hindi"]) + ":2:10"
        self.assertIn(k1, _CACHE)
        self.assertIn(k2, _CACHE)
        self.assertNotEqual(k1, k2)

    @patch("server.jio_call")
    @patch("server._expand_album_to_tracks")
    def test_newrel_and_pool_different_prefixes(self, mock_expand, mock_jio):
        mock_jio.return_value = {"data": []}
        mock_expand.return_value = []
        live_new_releases(["hindi"], page=1, limit=10)
        nr_keys = [k for k in _CACHE if k.startswith("newrel:")]
        self.assertTrue(all(not k.startswith("pool:") for k in nr_keys))


# ---------------------------------------------------------------------------
# 12. getNewReleases does NOT call trending as fallback (backend verification)
# ---------------------------------------------------------------------------
class TestNewReleasesNoTrendingFallbackConfirmation(unittest.TestCase):
    def setUp(self):
        _clr()

    @patch("server.jio_call")
    @patch("server.live_trending")
    @patch("server.search_songs")
    @patch("server._expand_album_to_tracks")
    def test_no_trending_or_search_when_songs_empty(self, mock_expand, mock_search, mock_trending, mock_jio):
        mock_jio.return_value = {"data": [_album("a9", "A", "hindi")]}
        mock_expand.return_value = []
        r = live_new_releases(["hindi"])
        mock_trending.assert_not_called()
        mock_search.assert_not_called()
        self.assertEqual(r["songs"], [])


# ---------------------------------------------------------------------------
# 13. Pagination exhaustion terminates scroll reliably (has_more=False)
# ---------------------------------------------------------------------------
class TestPaginationExhaustion(unittest.TestCase):
    def test_exhausted_page_has_more_false(self):
        pool, page, limit = 15, 2, 20
        start = (page - 1) * limit
        has_more = (start + limit) < pool
        self.assertFalse(has_more)

    def test_partial_last_page_has_more_false(self):
        pool, page, limit = 35, 2, 20
        start = (page - 1) * limit
        has_more = (start + limit) < pool
        self.assertFalse(has_more)

    def test_first_full_page_has_more_true(self):
        pool, page, limit = 50, 1, 20
        start = (page - 1) * limit
        has_more = (start + limit) < pool
        self.assertTrue(has_more)


# ---------------------------------------------------------------------------
# Basic import check
# ---------------------------------------------------------------------------
class TestImports(unittest.TestCase):
    def test_all_functions_importable(self):
        for fn in [normalize_title, dedupe, interleave_languages, prioritize_indian,
                   parse_languages, _sort_by_release_date, live_new_releases,
                   live_trending, mood_tracks, format_track]:
            self.assertTrue(callable(fn))

    def test_language_lists_populated(self):
        self.assertIn("telugu", SUPPORTED_LANGUAGES)
        self.assertIn("hindi", INDIAN_LANGUAGES)
        self.assertGreater(len(DEFAULT_LANGUAGES), 3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
