import pytest
import json
from server import app, parse_catalog_url, get_mock_catalog_items, load_catalog_sections

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

class TestCatalogUrlParsing:
    def test_artist_url(self):
        url = "https://www.jiosaavn.com/artist/salman-khan-songs/uuAKJcbNOKg_"
        parsed, err = parse_catalog_url(url)
        assert err is None
        assert parsed["source_type"] == "artist"
        assert parsed["source_id"] == "uuAKJcbNOKg_"
        assert parsed["slug"] == "salman-khan-songs"
        assert parsed["default_title"] == "Salman Khan"

    def test_featured_playlist_url(self):
        url = "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__"
        parsed, err = parse_catalog_url(url)
        assert err is None
        assert parsed["source_type"] == "playlist"
        assert parsed["source_id"] == "zlJfJYVuyjpxWb5,FqsjKg__"
        assert parsed["slug"] == "hindi-india-superhits-top-50"
        assert parsed["default_title"] == "Hindi India Superhits Top 50"

    def test_collection_pages(self):
        # new-releases
        p1, e1 = parse_catalog_url("https://www.jiosaavn.com/new-releases")
        assert e1 is None
        assert p1["source_type"] == "new_releases"
        assert p1["source_id"] == "new-releases"

        # charts
        p2, e2 = parse_catalog_url("https://www.jiosaavn.com/charts")
        assert e2 is None
        assert p2["source_type"] == "charts"
        assert p2["source_id"] == "charts"

        # top-artists
        p3, e3 = parse_catalog_url("https://www.jiosaavn.com/top-artists")
        assert e3 is None
        assert p3["source_type"] == "top_artists"
        assert p3["source_id"] == "top-artists"

    def test_song_url(self):
        url = "https://www.jiosaavn.com/song/bhakti-geet/BxwzaSVoA3I"
        parsed, err = parse_catalog_url(url)
        assert err is None
        assert parsed["source_type"] == "song"
        assert parsed["source_id"] == "BxwzaSVoA3I"
        assert parsed["slug"] == "bhakti-geet"
        assert "Bhakti Geet" in parsed["default_title"]

    def test_invalid_hostname(self):
        parsed, err = parse_catalog_url("https://spotify.com/playlist/123")
        assert parsed is None
        assert "Invalid hostname" in err

    def test_unsupported_path(self):
        parsed, err = parse_catalog_url("https://www.jiosaavn.com/unsupported/random")
        assert parsed is None
        assert "Unsupported path" in err

class TestCatalogMockProvider:
    def test_mock_items_are_tagged(self):
        items = get_mock_catalog_items("playlist", "test_id", "hindi-india-superhits-top-50")
        assert len(items) > 0
        for item in items:
            assert item["is_mock"] is True
            assert "[MOCK]" in item["title"]

    def test_mock_artist_items(self):
        items = get_mock_catalog_items("artist", "uuAKJcbNOKg_", "salman-khan-songs")
        assert len(items) > 0
        titles = [i["title"] for i in items]
        assert any("O O Jane Jaana" in t for t in titles)
        for item in items:
            assert item["is_mock"] is True

class TestCatalogEndpoints:
    def test_get_sections(self, client):
        resp = client.get("/api/catalog/sections")
        assert resp.status_code == 200
        data = resp.get_json()
        assert "sections" in data
        assert len(data["sections"]) >= 5

    def test_preview_endpoint(self, client):
        resp = client.post("/api/catalog/preview", json={
            "url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__"
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["valid"] is True
        assert data["source_type"] == "playlist"
        assert isinstance(data["is_mock"], bool)
        assert len(data["preview_items"]) > 0

    def test_source_type_independent_of_display_group(self, client):
        # A playlist can appear under Top Charts without being misclassified as a chart
        resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
            "display_title": "Hindi Superhits in Charts",
            "display_group": "Top Charts",
            "position": 99,
            "is_enabled": True
        })
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["source_type"] == "playlist"
        assert data["display_group"] == "Top Charts"
        key = data["key"]

        # Clean up
        client.delete(f"/api/catalog/sections/{key}")

    def test_section_key_tolerance(self, client):
        # Even with hyphen vs underscore or sec_ prefix, section should be found
        resp = client.get("/api/catalog/sections")
        sections = resp.get_json()["sections"]
        assert len(sections) > 0
        first_sec = sections[0]
        k = first_sec["key"]
        hyphen_k = k.replace("_", "-")

        # Test lookup with hyphen version
        resp_h = client.get(f"/api/catalog/sections/{hyphen_k}")
        assert resp_h.status_code == 200, f"Expected 200 for {hyphen_k}, got {resp_h.status_code}"

    def test_resolve_track_endpoint(self, client):
        resp = client.post("/api/catalog/resolve_track", json={
            "url": "https://www.jiosaavn.com/song/bhakti-geet/BxwzaSVoA3I"
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["valid"] is True
        assert "track" in data
        assert "title" in data["track"]

    def test_daily_mix_url_parsing(self):
        url = "https://www.jiosaavn.com/s/mix/daily_mix_2/gqr026sjjg5EycPt65hWSv9qnJHMxyN4MeBKaZmPvCCAFfS7n,cswwZHpEuo2hRsPnpS-,sujNQ4ntm,PDU0YLdZVNQiypBe"
        parsed, err = parse_catalog_url(url)
        assert err is None
        assert parsed["source_type"] == "mix"
        assert parsed["source_id"] == "gqr026sjjg5EycPt65hWSv9qnJHMxyN4MeBKaZmPvCCAFfS7n,cswwZHpEuo2hRsPnpS-,sujNQ4ntm,PDU0YLdZVNQiypBe"
        assert parsed["slug"] == "daily_mix_2"
        assert parsed["default_title"] == "Daily Mix 2"
        assert parsed["default_group"] == "Daily Mixes & Radio"

    def test_comma_token_preservation(self):
        url = "https://www.jiosaavn.com/mix/punjabi_mix_1/token1,token2,token3"
        parsed, err = parse_catalog_url(url)
        assert err is None
        assert parsed["source_type"] == "mix"
        assert parsed["source_id"] == "token1,token2,token3"
        assert "," in parsed["source_id"]

    def test_mix_mock_provider(self):
        items = get_mock_catalog_items("mix", "sample_token", "daily_mix_2")
        assert len(items) > 0
        for item in items:
            assert item["is_mock"] is True
            assert "[MOCK]" in item["title"]

    def test_daily_mix_preview(self, client):
        url = "https://www.jiosaavn.com/s/mix/daily_mix_2/gqr026sjjg5EycPt65hWSv9qnJHMxyN4MeBKaZmPvCCAFfS7n,cswwZHpEuo2hRsPnpS-,sujNQ4ntm,PDU0YLdZVNQiypBe"
        resp = client.post("/api/catalog/preview", json={"url": url})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["valid"] is True
        assert data["source_type"] == "mix"
        assert data["source_id"] == "gqr026sjjg5EycPt65hWSv9qnJHMxyN4MeBKaZmPvCCAFfS7n,cswwZHpEuo2hRsPnpS-,sujNQ4ntm,PDU0YLdZVNQiypBe"
        assert "preview_items" in data
        assert isinstance(data["preview_items"], list)
        assert data["detected_title"] == "Daily Mix 2"

    def test_single_section_refresh_endpoint(self, client):
        resp = client.get("/api/catalog/sections")
        sections = resp.get_json()["sections"]
        assert len(sections) > 0
        first_key = sections[0]["key"]

        resp_ref = client.post(f"/api/catalog/sections/{first_key}/refresh")
        assert resp_ref.status_code == 200
        ref_data = resp_ref.get_json()
        assert ref_data["key"] == first_key
        assert "items" in ref_data
        assert ref_data["last_refresh"] > 0

