import json
import sys
import server

def run_e2e_verification():
    app = server.app
    client = app.test_client()

    print("=" * 60)
    print("KALPKRUT BEATS - LOCAL CATALOGUE VERIFICATION")
    print("=" * 60)

    # 1. Health check
    res = client.get('/health')
    assert res.status_code == 200, f"Health check failed: {res.status_code}"
    print("[PASS] 1. /health returns 200 OK")

    # 2. Get sections
    res = client.get('/api/catalog/sections')
    assert res.status_code == 200
    data = res.get_json()
    assert 'sections' in data
    print(f"[PASS] 2. /api/catalog/sections returns {len(data['sections'])} enabled sections")

    # 3. Test Preview for all 5 URL types
    urls = [
        ("artist", "https://www.jiosaavn.com/artist/salman-khan-songs/uuAKJcbNOKg_", "uuAKJcbNOKg_"),
        ("playlist", "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__", "zlJfJYVuyjpxWb5,FqsjKg__"),
        ("new_releases", "https://www.jiosaavn.com/new-releases", "new-releases"),
        ("charts", "https://www.jiosaavn.com/charts", "charts"),
        ("top_artists", "https://www.jiosaavn.com/top-artists", "top-artists"),
    ]

    for expected_type, url, expected_id in urls:
        res = client.post('/api/catalog/preview', json={"url": url})
        assert res.status_code == 200, f"Preview failed for {url}: {res.data}"
        p = res.get_json()
        assert p["valid"] is True
        assert p["source_type"] == expected_type, f"Expected {expected_type}, got {p['source_type']}"
        assert p["source_id"] == expected_id, f"Expected {expected_id}, got {p['source_id']}"
        assert p["is_mock"] is True, "Mock flag must be True"
        preview_tracks = p.get("items") or p.get("preview_items") or []
        assert len(preview_tracks) > 0, f"Must return preview items, keys: {p.keys()}"
        for item in preview_tracks:
            assert "[MOCK]" in item["title"], f"Item title must contain [MOCK]: {item['title']}"
        print(f"[PASS] 3. Preview URL recognized correctly: {expected_type} -> ID: {expected_id} ({len(preview_tracks)} items tagged [MOCK])")

    # 4. Meaningful errors for invalid URLs
    res = client.post('/api/catalog/preview', json={"url": "https://attacker.com/malicious"})
    assert res.status_code == 400
    err = res.get_json()
    assert "Invalid hostname" in err["error"] or "jiosaavn.com" in err["error"]
    print(f"[PASS] 4a. Hostname validation rejects foreign domain: {err['error']}")

    res = client.post('/api/catalog/preview', json={"url": "https://www.jiosaavn.com/unsupported/random/path"})
    assert res.status_code == 400
    err = res.get_json()
    assert "Unsupported path" in err["error"]
    print(f"[PASS] 4b. Path validation rejects unsupported path: {err['error']}")

    # 5. Create section with decoupled source_type & display_group
    new_sec_payload = {
        "source_url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
        "display_title": "Hindi Superhits Test Carousel",
        "display_group": "Top Charts",
        "language": "hindi",
        "position": 99,
        "is_enabled": True
    }
    res = client.post('/api/catalog/sections', json=new_sec_payload)
    assert res.status_code == 201
    created = res.get_json()
    sec_key = created["key"]
    assert created["source_type"] == "playlist"
    assert created["display_group"] == "Top Charts"
    print(f"[PASS] 5. Created section: key={sec_key}, source_type={created['source_type']}, display_group={created['display_group']}")

    # 6. Update section (title, group, position, disabled)
    update_payload = {
        "display_title": "Updated Hindi Superhits Title",
        "display_group": "Spotlight",
        "position": 2,
        "is_enabled": False
    }
    res = client.put(f'/api/catalog/sections/{sec_key}', json=update_payload)
    assert res.status_code == 200
    updated = res.get_json()
    assert updated["display_title"] == "Updated Hindi Superhits Title"
    assert updated["display_group"] == "Spotlight"
    assert updated["is_enabled"] is False
    print(f"[PASS] 6. Updated section: title='{updated['display_title']}', enabled={updated['is_enabled']}")

    # 7. Toggle enabled state
    res = client.post(f'/api/catalog/sections/{sec_key}/toggle')
    assert res.status_code == 200
    toggled = res.get_json()
    assert toggled["is_enabled"] is True
    print(f"[PASS] 7. Toggled enabled state: enabled={toggled['is_enabled']}")

    # 8. Reorder sections
    res = client.get('/api/catalog/sections?include_disabled=true')
    all_secs = res.get_json()["sections"]
    keys = [s["key"] for s in all_secs]
    keys.reverse()
    res = client.post('/api/catalog/sections/reorder', json={"order": keys})
    assert res.status_code == 200
    print(f"[PASS] 8. Reordered {len(keys)} sections sequentially")

    # 9. Verify /api/home includes catalog sections
    res = client.get('/api/home')
    assert res.status_code == 200
    home_data = res.get_json()
    catalog_in_home = [s for s in home_data["sections"] if s.get("is_mock") or s.get("source") == "catalog_admin"]
    assert len(catalog_in_home) > 0, f"Expected catalog sections in /api/home, found: {[s.get('key') for s in home_data['sections']]}"
    print(f"[PASS] 9. /api/home returns {len(catalog_in_home)} admin catalogue sections prepended")

    # 10. Clean up test section
    res = client.delete(f'/api/catalog/sections/{sec_key}')
    assert res.status_code == 200
    print(f"[PASS] 10. Deleted test section {sec_key}")

    print("=" * 60)
    print("ALL 10 END-TO-END VERIFICATION CHECKS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == '__main__':
    run_e2e_verification()
