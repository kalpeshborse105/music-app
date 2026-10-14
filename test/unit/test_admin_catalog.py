import copy

import pytest
import server


@pytest.fixture
def catalog_test_env(monkeypatch):
    """In-memory catalogue storage: tests must never touch the connected Supabase project."""
    rows = []
    monkeypatch.setattr(server, "is_admin_request", lambda _request: True)
    monkeypatch.setattr(server, "load_catalog_sections", lambda: sorted(
        copy.deepcopy(rows), key=lambda section: section.get("position", 999)
    ))

    def save_sections(sections):
        rows[:] = copy.deepcopy(sections)
        return True

    monkeypatch.setattr(server, "save_catalog_sections", save_sections)
    monkeypatch.setattr(server, "delete_catalog_section_from_supabase", lambda *_args: True)
    monkeypatch.setattr(
        server,
        "resolve_catalog_items",
        lambda source_type, source_id, slug, language="all": (
            [{
                "id": str(source_id or "fixture-track"),
                "title": str(slug or "Fixture track").replace("-", " ").title(),
                "artist": "Fixture Artist",
                "language": language if language != "all" else "hindi",
                "is_mock": False,
            }],
            False,
            "fixture",
            str(slug or "Fixture title"),
            None,
        ),
    )
    monkeypatch.setattr(server, "get_section_items", lambda section, force_refresh=False, language=None: [
        {
            "id": str(section.get("source_id") or "track-1"),
            "title": str(section.get("display_title") or "Test track"),
            "artist": "Fixture Artist",
            "language": language or section.get("language") or "hindi",
            "is_mock": False,
        }
    ])
    server._CATALOG_ITEMS_CACHE.clear()
    server.app.config["TESTING"] = True
    yield rows
    server._CATALOG_ITEMS_CACHE.clear()


@pytest.fixture
def client():
    server.app.config["TESTING"] = True
    with server.app.test_client() as test_client:
        yield test_client


class TestCatalogUrlParsing:
    def test_artist_url(self):
        parsed, error = server.parse_catalog_url(
            "https://www.jiosaavn.com/artist/salman-khan-songs/uuAKJcbNOKg_"
        )
        assert error is None
        assert parsed["source_type"] == "artist"
        assert parsed["source_id"] == "uuAKJcbNOKg_"
        assert parsed["slug"] == "salman-khan-songs"
        assert parsed["default_title"] == "Salman Khan"

    def test_featured_playlist_url(self):
        parsed, error = server.parse_catalog_url(
            "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__"
        )
        assert error is None
        assert parsed["source_type"] == "playlist"
        assert parsed["source_id"] == "zlJfJYVuyjpxWb5,FqsjKg__"
        assert parsed["slug"] == "hindi-india-superhits-top-50"
        assert parsed["default_title"] == "Hindi India Superhits Top 50"

    def test_collection_pages(self):
        releases, releases_error = server.parse_catalog_url("https://www.jiosaavn.com/new-releases")
        charts, charts_error = server.parse_catalog_url("https://www.jiosaavn.com/charts")
        assert releases_error is None and releases["source_type"] == "new_releases"
        assert charts_error is None and charts["source_type"] == "charts"

    def test_top_artists_is_not_a_fake_special_endpoint(self):
        parsed, error = server.parse_catalog_url("https://www.jiosaavn.com/top-artists")
        assert parsed is None
        assert "Unsupported path" in error

    def test_invalid_hostname(self):
        parsed, error = server.parse_catalog_url("https://spotify.com/playlist/123")
        assert parsed is None
        assert "Invalid hostname" in error

    def test_unsupported_path(self):
        parsed, error = server.parse_catalog_url("https://www.jiosaavn.com/unsupported/random")
        assert parsed is None
        assert "Unsupported path" in error


class TestNoStaticCatalogFallback:
    def test_mock_catalog_is_always_empty(self):
        assert server.get_mock_catalog_items("playlist", "test_id", "sample") == []
        assert server.get_mock_catalog_items("artist", "test_id", "sample") == []

    def test_get_sections_does_not_seed_static_content(self, client, catalog_test_env):
        response = client.get("/api/catalog/sections")
        assert response.status_code == 200
        payload = response.get_json()
        assert payload["sections"] == []
        assert payload["source"] == "admin_catalog"

    def test_home_is_empty_when_admin_has_published_nothing(self, client, catalog_test_env):
        response = client.get("/api/home?lang=hindi")
        assert response.status_code == 200
        payload = response.get_json()
        assert payload["sections"] == []
        assert payload["source"] == "supabase_catalog"


class TestCatalogAdminMutations:
    def test_preview_uses_real_resolver_contract_without_network(self, client, monkeypatch):
        monkeypatch.setattr(
            server,
            "resolve_catalog_items",
            lambda *_args, **_kwargs: (
                [{"id": "fixture-playlist", "title": "Real fixture item", "language": "hindi", "is_mock": False}],
                False,
                "fixture",
                "Hindi Fixture Playlist",
                None,
            ),
        )
        response = client.post("/api/catalog/preview", json={
            "url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__"
        })
        assert response.status_code == 200
        payload = response.get_json()
        assert payload["valid"] is True
        assert payload["source_type"] == "playlist"
        assert payload["is_mock"] is False
        assert payload["preview_items"][0]["id"] == "fixture-playlist"

    def test_create_and_read_back_admin_section(self, client, catalog_test_env):
        response = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
            "display_title": "Hindi Superhits",
            "display_group": "Top Charts",
            "subtitle": "Admin-written subtitle",
            "language": "hindi",
            "position": 8,
            "is_enabled": True,
        })
        assert response.status_code == 201
        saved = response.get_json()
        assert saved["display_title"] == "Hindi Superhits"
        assert saved["display_group"] == "Top Charts"
        assert saved["language"] == "hindi"
        assert len(catalog_test_env) == 1

        read_back = client.get("/api/catalog/sections?lang=hindi").get_json()["sections"]
        assert len(read_back) == 1
        assert read_back[0]["key"] == saved["key"]
        assert read_back[0]["subtitle"] == "Admin-written subtitle"

    def test_failed_supabase_write_returns_service_unavailable(self, client, monkeypatch, catalog_test_env):
        monkeypatch.setattr(server, "save_catalog_sections", lambda _sections: False)
        response = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
            "display_title": "Must Not Pretend Saved",
            "display_group": "Test",
        })
        assert response.status_code == 503
        assert "not saved to Supabase" in response.get_json()["error"]

    def test_admin_gate_blocks_write(self, client, monkeypatch):
        monkeypatch.setattr(server, "is_admin_request", lambda _request: False)
        response = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/new-releases",
        })
        assert response.status_code == 403


def test_selected_language_filters_mixed_provider_items(monkeypatch):
    server._CATALOG_ITEMS_CACHE.clear()
    monkeypatch.setattr(
        server,
        "resolve_catalog_items",
        lambda *_args, **_kwargs: (
            [
                {"id": "h-1", "title": "Hindi track", "language": "hindi"},
                {"id": "te-1", "title": "Telugu track", "language": "telugu"},
                {"id": "unknown-1", "title": "Unclassified track"},
            ],
            False,
            "fixture",
            "Test",
            None,
        ),
    )
    section = {
        "key": "language-filter-test",
        "source_type": "playlist",
        "source_id": "fixture",
        "slug": "fixture",
        "language": "all",
        "custom_tracks": [],
        "excluded_track_ids": [],
    }
    items = server.get_section_items(section, force_refresh=True, language="hindi")
    assert [item["id"] for item in items] == ["h-1"]
    server._CATALOG_ITEMS_CACHE.clear()
