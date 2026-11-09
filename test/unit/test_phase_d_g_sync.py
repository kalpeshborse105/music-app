"""
Unit tests for Kalpkrut Beats Phase D-G Permanent Catalogue Sync Architecture:
- Security: No hardcoded Supabase service role key fallback in server.py
- Fingerprinting: Deterministic, order-sensitive, and change-detecting
- Durable Job Queue: Batch creation, lease recovery, and truthful metrics reporting
- Refresh All: Asynchronous queuing, idempotency, and status polling
- Metadata Preservation: Sync modifies track items & timestamps but NEVER overwrites Admin display fields
"""

import os
import json
import time
import pytest
from unittest.mock import patch
import server
from server import (
    app,
    compute_section_fingerprint,
    create_sync_batch,
    get_batch_status,
    process_sync_job,
    drain_sync_batch,
    persist_section_tracks_to_supabase,
    fetch_section_tracks_from_supabase,
    load_catalog_sections,
    save_catalog_sections,
    _SYNC_JOBS_FILE,
    _load_sync_jobs,
    _save_sync_jobs,
)


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


class TestPhaseDGSyncArchitecture:

    def test_security_no_hardcoded_service_role_key(self):
        """Verify that server.py does not contain any hardcoded Supabase service role JWT fallback."""
        server_py_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "server.py")
        with open(server_py_path, "r", encoding="utf-8") as f:
            content = f.read()

        # The known leaked secret token
        leaked_fragment = "8jO-42nSry7u0WSBW0sa4tuFJtENKS6o6MarM77EUWo"
        assert leaked_fragment not in content, "Hardcoded service role key must never exist in server.py"

        # Check definition pattern: must be read directly from os.environ without JWT literal fallback
        assert 'SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()' in content

    def test_fingerprint_deterministic_and_change_sensitive(self):
        """Fingerprint must be stable for identical content and change on song addition/reorder/edit."""
        tracks_a = [
            {"id": "t1", "title": "Song One", "artist": "Artist A", "artwork_url": "https://img.com/1.jpg", "duration_ms": 180000},
            {"id": "t2", "title": "Song Two", "artist": "Artist B", "artwork_url": "https://img.com/2.jpg", "duration_ms": 210000},
        ]
        # Same tracks with different dict key order or casing
        tracks_a_equiv = [
            {"title": "Song One", "id": "t1", "duration_ms": 180000, "artist": "Artist A", "artwork_url": "https://img.com/1.jpg"},
            {"artist": "Artist B", "title": "Song Two", "artwork_url": "https://img.com/2.jpg", "id": "t2", "duration_ms": 210000},
        ]
        fp_a = compute_section_fingerprint(tracks_a)
        fp_a_equiv = compute_section_fingerprint(tracks_a_equiv)
        assert fp_a == fp_a_equiv, "Fingerprint must be deterministic regardless of dictionary key ordering"
        assert len(fp_a) == 64, "Fingerprint must be a 64-character SHA-256 hexadecimal string"

        # Reordered tracks must change fingerprint
        tracks_reordered = [tracks_a[1], tracks_a[0]]
        fp_reordered = compute_section_fingerprint(tracks_reordered)
        assert fp_a != fp_reordered, "Track order change must produce a distinct fingerprint"

        # Changed title must change fingerprint
        tracks_edited = [
            {"id": "t1", "title": "Song One (Remix)", "artist": "Artist A", "artwork_url": "https://img.com/1.jpg", "duration_ms": 180000},
            tracks_a[1]
        ]
        fp_edited = compute_section_fingerprint(tracks_edited)
        assert fp_a != fp_edited, "Title edit must produce a distinct fingerprint"

    def test_sync_batch_queue_lifecycle(self):
        """Test durable sync job creation, status querying, and truthful counting."""
        sample_sections = [
            {"id": "sec-1", "key": "shelf_alpha", "display_title": "Alpha"},
            {"id": "sec-2", "key": "shelf_beta", "display_title": "Beta"},
            {"id": "sec-3", "key": "shelf_gamma", "display_title": "Gamma"},
        ]
        batch_id, jobs = create_sync_batch(sample_sections)
        assert batch_id.startswith("batch_")
        assert len(jobs) == 3

        status = get_batch_status(batch_id)
        assert status["batch_id"] == batch_id
        assert status["total"] == 3
        assert status["queued"] == 3
        assert status["running"] == 0
        assert status["completed"] == 0
        assert status["failed"] == 0
        assert status["is_finished"] is False
        assert status["percent"] == 0.0

        # Simulate job completion
        loaded = _load_sync_jobs()
        for j in loaded:
            if j.get("batch_id") == batch_id and j.get("section_key") == "shelf_alpha":
                j["status"] = "completed"
                j["changed"] = True
                j["tracks_found"] = 25
            elif j.get("batch_id") == batch_id and j.get("section_key") == "shelf_beta":
                j["status"] = "completed"
                j["changed"] = False
                j["tracks_found"] = 20
        _save_sync_jobs(loaded)

        updated_status = get_batch_status(batch_id)
        assert updated_status["completed"] == 2
        assert updated_status["changed"] == 1
        assert updated_status["unchanged"] == 1
        assert updated_status["queued"] == 1
        assert updated_status["is_finished"] is False
        assert updated_status["percent"] == 66.7

    def test_lease_expiration_and_recovery(self):
        """Stale running jobs whose lease expired must be safely reclaimed back to queued."""
        now = int(time.time())
        old_batch_id = f"batch_stale_{now}"
        jobs = _load_sync_jobs()
        stale_job = {
            "id": f"job_stale_{now}",
            "batch_id": old_batch_id,
            "section_id": "sec-stale",
            "section_key": "stale_shelf",
            "status": "running",
            "worker_id": "crashed_worker_pid",
            "lease_expires_at": now - 300, # expired 5 minutes ago
            "attempt_count": 1,
            "max_attempts": 3,
            "last_error": None,
            "tracks_found": 0,
            "changed": False,
            "created_at": now - 600,
            "updated_at": now - 300,
        }
        jobs.append(stale_job)
        _save_sync_jobs(jobs)

        # Trigger batch creation which triggers automatic lease recovery
        create_sync_batch([{"id": "sec-new", "key": "new_shelf"}])

        reloaded = _load_sync_jobs()
        reclaimed = next((j for j in reloaded if j.get("id") == stale_job["id"]), None)
        assert reclaimed is not None
        assert reclaimed["status"] == "queued", "Expired running job must be reclaimed to queued"
        assert reclaimed["attempt_count"] == 2, "Attempt count must increment on lease recovery"

    def test_refresh_all_api_endpoint_and_status_polling(self, client):
        """POST /api/catalog/sections/refresh-all must queue jobs and return truthful metrics."""
        with patch.object(server._CATALOG_SYNC_WORKER_POOL, "submit"):
            resp = client.post("/api/catalog/sections/refresh-all")
            assert resp.status_code == 200
            data = resp.get_json()
            assert data["success"] is True
            assert "batch_id" in data
            assert "total" in data
            assert "pending" in data
            assert "completed" in data
            assert "failed" in data
            batch_id = data["batch_id"]

            # Poll status endpoint
            status_resp = client.get(f"/api/catalog/sections/refresh-all/status?batch_id={batch_id}")
            assert status_resp.status_code == 200
            s_data = status_resp.get_json()
            assert s_data["success"] is True
            assert s_data["batch_id"] == batch_id
            assert s_data["total"] >= 1
            assert "is_finished" in s_data
            assert "percent" in s_data

    def test_sync_preserves_admin_display_metadata(self):
        """Track synchronization must update items/hash/version but never overwrite Admin display fields."""
        sections = load_catalog_sections()
        test_sec = {
            "id": "e30e61d8-3796-5be8-944e-111122223333",
            "key": "permanent_admin_test_shelf",
            "source_url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
            "source_type": "playlist",
            "display_title": "Admin Preserved Title",
            "display_group": "My Custom Curated Group",
            "subtitle": "Admin Custom Subtitle",
            "position": 42,
            "is_enabled": True,
            "custom_artwork_url": "https://img.com/custom_poster.jpg",
            "is_banner": True,
            "campaign_start": 1700000000,
            "campaign_end": 1800000000,
            "display_mode": "tracks",
            "excluded_track_ids": ["exc_1", "exc_2"],
            "custom_tracks": [],
            "content_hash": "old_hash_123",
            "content_version": 5,
            "last_refresh": 1000
        }
        # Insert test section
        sections = [s for s in sections if s.get("key") != test_sec["key"]]
        sections.append(test_sec)
        save_catalog_sections(sections, sync_db=False)
        saved_initial = next((s for s in load_catalog_sections() if s.get("key") == test_sec["key"]), None)
        assert saved_initial is not None
        assigned_pos = saved_initial["position"]

        try:
            mock_items = [
                {"id": "new_track_1", "title": "New Live Track 1", "artist": "Artist 1", "artwork_url": "https://img.com/1.jpg", "duration_ms": 200000},
                {"id": "new_track_2", "title": "New Live Track 2", "artist": "Artist 2", "artwork_url": "https://img.com/2.jpg", "duration_ms": 180000},
            ]
            with patch.object(server, "resolve_catalog_items", return_value=(mock_items, False, "ok", "Updated Live Title", None)), \
                 patch.object(server, "persist_section_tracks_to_supabase", return_value=(True, "ok")), \
                 patch.object(server, "upsert_single_catalog_section_to_supabase", return_value=(True, {})):
                batch_id, jobs = create_sync_batch([test_sec])
                target_job = jobs[0]
                process_sync_job(target_job["id"], "test_worker_1")

            updated_sections = load_catalog_sections()
            updated_sec = next((s for s in updated_sections if s.get("key") == test_sec["key"]), None)
            assert updated_sec is not None

            # 1. Admin display fields MUST remain strictly identical
            assert updated_sec["display_title"] == "Admin Preserved Title"
            assert updated_sec["display_group"] == "My Custom Curated Group"
            assert updated_sec["subtitle"] == "Admin Custom Subtitle"
            assert updated_sec["position"] == assigned_pos
            assert updated_sec["is_enabled"] is True
            assert updated_sec["custom_artwork_url"] == "https://img.com/custom_poster.jpg"
            assert updated_sec["is_banner"] is True
            assert updated_sec["campaign_start"] == 1700000000
            assert updated_sec["campaign_end"] == 1800000000
            assert updated_sec["display_mode"] == "tracks"
            assert updated_sec["excluded_track_ids"] == ["exc_1", "exc_2"]

            # 2. Sync metadata MUST update honestly
            assert updated_sec["last_refresh"] > 1000, "last_refresh must update after sync"
            assert updated_sec["content_hash"] != "old_hash_123", "content_hash must reflect newly resolved tracks"
            assert updated_sec["content_version"] >= 6, "content_version must increment when hash changes"
            assert updated_sec["provider_status"] == "ok"
        finally:
            cleaned = [s for s in load_catalog_sections() if s.get("key") != test_sec["key"]]
            save_catalog_sections(cleaned, sync_db=False)

