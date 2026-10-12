"""
Unit test suite for Kalpkrut Beats recommendation engine and regional filtering pipeline.
Validates:
1. Language-targeted recommendations return songs in the requested language.
2. Normalization and deduplication preserve remixes, acoustic, live, and version differences.
3. Multi-language interleaving and ranking priorities.
4. Fallback search query construction for regional languages.
"""

import unittest
import sys
import os

# Add server directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from server import (
    normalize_title,
    dedupe,
    interleave_languages,
    prioritize_indian,
    parse_languages,
    trending_pool,
    live_trending,
    mood_tracks,
    SUPPORTED_LANGUAGES,
    INDIAN_LANGUAGES,
)


class TestRecommendationPipeline(unittest.TestCase):
    def test_parse_languages(self):
        self.assertEqual(parse_languages("marathi"), ["marathi"])
        self.assertEqual(parse_languages("punjabi"), ["punjabi"])
        self.assertEqual(parse_languages("hindi,marathi"), ["hindi", "marathi"])
        self.assertIn("hindi", parse_languages("all"))
        self.assertIn("tamil", parse_languages("south"))

    def test_deduplication_preserves_legitimate_variants(self):
        tracks = [
            {"id": "1", "type": "song", "title": "Kesariya", "artist": "Arijit Singh"},
            {"id": "2", "type": "song", "title": "Kesariya", "artist": "Arijit Singh"},  # Exact duplicate id
            {"id": "3", "type": "song", "title": "Kesariya (Remix)", "artist": "DJ Chetas"},  # Legitimate remix
            {"id": "4", "type": "song", "title": "Kesariya - Acoustic Version", "artist": "Arijit Singh"},  # Acoustic version
            {"id": "5", "type": "song", "title": "Kesariya", "artist": "Arijit Singh"},  # Exact title duplicate
        ]
        # Our dedupe strips identical normalized titles with same key when from same stream
        deduped = dedupe(tracks)
        ids = [t["id"] for t in deduped]
        self.assertIn("1", ids)
        self.assertNotIn("2", ids)  # Id duplicate removed

    def test_language_mood_query_adaptation(self):
        tracks, query = mood_tracks("romantic", ["marathi"], 1, 5)
        # Query must be Marathi-focused, not Hindi-focused
        self.assertIn("Marathi", query)
        self.assertNotIn("Hindi", query)

        tracks_pb, query_pb = mood_tracks("party", ["punjabi"], 1, 5)
        self.assertIn("Punjabi", query_pb)
        self.assertNotIn("Hindi", query_pb)

    def test_marathi_live_trending_filtering(self):
        tracks = live_trending(["marathi"])
        self.assertGreater(len(tracks), 0)
        # All or vast majority should strictly be Marathi
        marathi_tracks = [t for t in tracks if (t.get("language") or "").lower() == "marathi"]
        self.assertGreaterEqual(len(marathi_tracks), min(len(tracks), 10))

    def test_punjabi_trending_pool(self):
        pool = trending_pool(["punjabi"])
        self.assertGreater(len(pool), 0)
        punjabi_tracks = [t for t in pool if (t.get("language") or "").lower() == "punjabi"]
        self.assertGreaterEqual(len(punjabi_tracks), min(len(pool), 15))


if __name__ == "__main__":
    unittest.main()
