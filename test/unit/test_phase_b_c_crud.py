import time
import pytest
from unittest.mock import patch
import server
from server import app, load_catalog_sections, save_catalog_sections

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

class TestPhaseBCrudReliability:

    def test_1_slow_jiosaavn_resolver_does_not_block_save(self, client):
        """Phase B1: Slow JioSaavn resolver must not block Save beyond request budget."""
        # Warm up catalogue memory so cold start network sync doesn't skew timing
        client.get("/api/catalog/sections?lite=1")

        with patch.object(server, "resolve_catalog_items") as mock_resolve:
            def slow_resolve(*args, **kwargs):
                time.sleep(10.0)
                return [], False, "ok", "Slow Title", None
            mock_resolve.side_effect = slow_resolve

            t0 = time.time()
            resp = client.post("/api/catalog/sections", json={
                "source_url": "https://www.jiosaavn.com/featured/slow-test-playlist/abcdef12345__",
                "display_title": "Fast Save Test Shelf",
                "display_group": "Top Charts",
                "is_enabled": True
            })
            duration = time.time() - t0

            assert resp.status_code == 201
            assert duration < 5.0, f"Save took {duration:.2f}s, should be < 5s without waiting for 10s Jio resolve"
            data = resp.get_json()
            assert data["provider_status"] == "pending"
            # Cleanup
            client.delete(f"/api/catalog/sections/{data['key']}")

    def test_2_saved_section_remains_saved_when_resolution_is_pending(self, client):
        """Phase B2: Saved section remains saved and visible in Admin when resolution is pending."""
        resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/pending-shelf-test/xyz9876543__",
            "display_title": "Pending Shelf",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert resp.status_code == 201
        created = resp.get_json()
        key = created["key"]
        try:
            list_resp = client.get("/api/catalog/sections?include_disabled=1")
            assert list_resp.status_code == 200
            sections = list_resp.get_json()["sections"]
            found = next((s for s in sections if s["key"] == key), None)
            assert found is not None
            assert found["display_title"] == "Pending Shelf"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_3_supabase_failure_returns_honest_error(self, client):
        """Phase B2: Supabase failure returns an honest 502 error and rolls back local state."""
        with patch.object(server, "upsert_single_catalog_section_to_supabase", return_value=(False, "Simulated DB Connection Timeout")):
            resp = client.post("/api/catalog/sections", json={
                "source_url": "https://www.jiosaavn.com/featured/supabase-fail-test/fail123456__",
                "display_title": "Should Not Persist",
                "display_group": "Top Charts",
                "is_enabled": True
            })
            assert resp.status_code == 502
            data = resp.get_json()
            assert "Failed to persist catalogue section to Supabase" in data["error"]

            # Confirm nothing was saved in local sections
            list_resp = client.get("/api/catalog/sections?include_disabled=1")
            sections = list_resp.get_json()["sections"]
            assert not any(s.get("display_title") == "Should Not Persist" for s in sections)

    def test_4_create_retry_does_not_create_duplicate_keys(self, client):
        """Phase B/C: Create retry generates distinct unique keys and sequential positions."""
        url = "https://www.jiosaavn.com/featured/retry-duplicate-test/dup123456__"
        resp1 = client.post("/api/catalog/sections", json={
            "source_url": url,
            "display_title": "Duplicate Shelf 1",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert resp1.status_code == 201
        key1 = resp1.get_json()["key"]

        resp2 = client.post("/api/catalog/sections", json={
            "source_url": url,
            "display_title": "Duplicate Shelf 2",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert resp2.status_code == 201
        key2 = resp2.get_json()["key"]

        try:
            assert key1 != key2, "Repeated create must disambiguate key to avoid duplicate collision"
        finally:
            client.delete(f"/api/catalog/sections/{key1}")
            client.delete(f"/api/catalog/sections/{key2}")

    def test_5_update_omitted_fields_preserve_values(self, client):
        """Phase C1: Update with omitted fields preserves existing metadata."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/preserve-test/pres123456__",
            "display_title": "Original Title",
            "display_group": "Top Charts",
            "subtitle": "Original Subtitle",
            "custom_artwork_url": "https://example.com/art.png",
            "language": "punjabi",
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            # Update only title
            up_resp = client.put(f"/api/catalog/sections/{key}", json={
                "display_title": "New Updated Title"
            })
            assert up_resp.status_code == 200
            updated = up_resp.get_json()
            assert updated["display_title"] == "New Updated Title"
            assert updated["subtitle"] == "Original Subtitle"
            assert updated["custom_artwork_url"] == "https://example.com/art.png"
            assert updated["language"] == "punjabi"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_6_explicit_null_clears_nullable_fields(self, client):
        """Phase C1: Explicit null clears nullable fields."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/clear-null-test/null123456__",
            "display_title": "Clear Test",
            "display_group": "Top Charts",
            "subtitle": "Will Clear Subtitle",
            "custom_artwork_url": "https://example.com/clear_art.png",
            "campaign_start": 1700000000,
            "campaign_end": 1800000000,
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            up_resp = client.put(f"/api/catalog/sections/{key}", json={
                "subtitle": None,
                "custom_artwork_url": None,
                "campaign_start": None,
                "campaign_end": None
            })
            assert up_resp.status_code == 200
            updated = up_resp.get_json()
            assert updated["subtitle"] is None
            assert updated["custom_artwork_url"] is None
            assert updated["campaign_start"] is None
            assert updated["campaign_end"] is None
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_7_metadata_only_edit_does_not_fetch_jiosaavn(self, client):
        """Phase C1: Display-only edits must not call JioSaavn."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/meta-only-test/meta123456__",
            "display_title": "Meta Only Shelf",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            with patch.object(server, "resolve_catalog_items") as mock_resolve:
                mock_resolve.side_effect = AssertionError("resolve_catalog_items should NOT be called for display-only edit")
                up_resp = client.put(f"/api/catalog/sections/{key}", json={
                    "display_title": "Renamed Display Title",
                    "display_group": "Personalized Mixes"
                })
                assert up_resp.status_code == 200
                data = up_resp.get_json()
                assert data["display_title"] == "Renamed Display Title"
                assert data["display_group"] == "Personalized Mixes"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_8_metadata_only_edit_does_not_change_last_refresh(self, client):
        """Phase C1: Metadata-only edits must not stamp last_refresh."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/meta-timestamp-test/time123456__",
            "display_title": "Timestamp Test",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            # Manually set last_refresh to an older fixed timestamp
            sections = load_catalog_sections()
            sec = next(s for s in sections if s["key"] == key)
            sec["last_refresh"] = 1700000000
            save_catalog_sections(sections, sync_db=False)

            # Metadata edit
            up_resp = client.put(f"/api/catalog/sections/{key}", json={
                "display_title": "New Timestamp Test Title"
            })
            assert up_resp.status_code == 200
            updated = up_resp.get_json()
            assert updated["last_refresh"] == 1700000000, "last_refresh must NOT change on metadata-only edits"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_9_url_change_does_not_block_indefinitely(self, client):
        """Phase C1: URL change does not block indefinitely when Jio resolver is slow."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/url-change-test/url123456__",
            "display_title": "URL Change Test",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            with patch.object(server, "resolve_catalog_items") as mock_resolve:
                def slow_resolve(*args, **kwargs):
                    time.sleep(12.0)
                    return [], False, "ok", None, None
                mock_resolve.side_effect = slow_resolve

                t0 = time.time()
                up_resp = client.put(f"/api/catalog/sections/{key}", json={
                    "source_url": "https://www.jiosaavn.com/featured/new-url-target/new987654__"
                })
                duration = time.time() - t0
                assert up_resp.status_code == 200
                assert duration < 8.0, f"URL update blocked for {duration:.2f}s, expected < 8s"
                data = up_resp.get_json()
                assert data["source_url"] == "https://www.jiosaavn.com/featured/new-url-target/new987654__"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_10_update_failure_does_not_leave_local_and_supabase_inconsistent(self, client):
        """Phase C1: Supabase update failure rolls back local state to prevent divergence."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/rollback-test/roll123456__",
            "display_title": "Initial Title Before Fail",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        assert create_resp.status_code == 201
        key = create_resp.get_json()["key"]

        try:
            with patch.object(server, "upsert_single_catalog_section_to_supabase", return_value=(False, "Simulated Supabase 500")):
                up_resp = client.put(f"/api/catalog/sections/{key}", json={
                    "display_title": "Should Be Rolled Back"
                })
                assert up_resp.status_code == 502
                # Verify local state kept the original title
                sec = server.find_catalog_section(key)
                assert sec is not None
                assert sec["display_title"] == "Initial Title Before Fail"
        finally:
            client.delete(f"/api/catalog/sections/{key}")

    def test_11_delete_removes_only_intended_row_and_not_shared_source(self, client):
        """Phase C2: Delete removes only the intended row even when sharing source URLs."""
        shared_url = "https://www.jiosaavn.com/featured/shared-url-shelf/shared123456__"
        resp_a = client.post("/api/catalog/sections", json={
            "source_url": shared_url,
            "display_title": "Shelf A (Shared Source)",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        resp_b = client.post("/api/catalog/sections", json={
            "source_url": shared_url,
            "display_title": "Shelf B (Shared Source)",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        key_a = resp_a.get_json()["key"]
        key_b = resp_b.get_json()["key"]

        try:
            del_resp = client.delete(f"/api/catalog/sections/{key_a}")
            assert del_resp.status_code == 200

            # Shelf B must still exist!
            sec_b = server.find_catalog_section(key_b)
            assert sec_b is not None
            assert sec_b["key"] == key_b

            # Shelf A must be gone
            sec_a = server.find_catalog_section(key_a)
            assert sec_a is None
        finally:
            client.delete(f"/api/catalog/sections/{key_b}")

    def test_12_delete_cannot_resurrect_after_reconciliation(self, client):
        """Phase C2: Deleted section cannot be resurrected by reconciliation."""
        create_resp = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/ghost-resurrect-test/ghost123456__",
            "display_title": "Ghost Test Shelf",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        key = create_resp.get_json()["key"]

        del_resp = client.delete(f"/api/catalog/sections/{key}")
        assert del_resp.status_code == 200

        # Trigger Supabase reconcile
        server._reconcile_catalog_with_supabase(force=True, bypass_authority=True)

        # Confirm ghost row did not resurrect
        sec = server.find_catalog_section(key)
        assert sec is None, "Deleted section must stay gone after reconcile"

    def test_13_reorder_persists_correctly(self, client):
        """Phase C3: Reorder assigns sequential unique positions and persists."""
        resp1 = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/reorder-1/r1__",
            "display_title": "Reorder Shelf 1",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        resp2 = client.post("/api/catalog/sections", json={
            "source_url": "https://www.jiosaavn.com/featured/reorder-2/r2__",
            "display_title": "Reorder Shelf 2",
            "display_group": "Top Charts",
            "is_enabled": True
        })
        k1 = resp1.get_json()["key"]
        k2 = resp2.get_json()["key"]

        try:
            reorder_resp = client.post("/api/catalog/sections/reorder", json={
                "order": [k2, k1]
            })
            assert reorder_resp.status_code == 200
            sections = reorder_resp.get_json()["sections"]
            s2 = next(s for s in sections if s["key"] == k2)
            s1 = next(s for s in sections if s["key"] == k1)
            assert s2["position"] < s1["position"], "k2 must be ordered before k1"
        finally:
            client.delete(f"/api/catalog/sections/{k1}")
            client.delete(f"/api/catalog/sections/{k2}")
